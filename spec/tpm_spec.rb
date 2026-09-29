# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'securerandom'
require 'open3'
require_relative '../lib/tpm'

RSpec.describe VaultCLI::TPM do
  let(:tpm_path_temp) { File.join(Dir.tmpdir, "tpm_test_#{SecureRandom.hex(8)}") }
  let(:handle_path) { File.join(tpm_path_temp, described_class::HANDLE_FILE) }
  let(:tpm_status) { double(success?: true) }

  before do
    FileUtils.mkdir_p(tpm_path_temp)
    allow_any_instance_of(described_class).to receive(:system).and_return(true)
  end

  after do
    FileUtils.rm_rf(tpm_path_temp)
  end

  describe '#initialize' do
    before do
      allow(Open3).to receive(:capture3)
        .with('tpm2_getcap', 'handles-persistent')
        .and_return(['', '', tpm_status])
      allow_any_instance_of(described_class).to receive(:run_tpm!) do |_instance, *_args|
        true
      end
    end

    it 'creates and stores a free persistent handle when none is recorded' do
      tpm = described_class.new(tpm_path: tpm_path_temp)

      expect(File.read(handle_path)).to eq('0x81000000')
      expect(tpm.instance_variable_get(:@rsa_handle)).to eq('0x81000000')
    end

    it 'skips handles already in use when choosing a free handle' do
      allow(Open3).to receive(:capture3)
        .with('tpm2_getcap', 'handles-persistent')
        .and_return(["- 0x81000000\n", '', tpm_status])

      described_class.new(tpm_path: tpm_path_temp)

      expect(File.read(handle_path)).to eq('0x81000001')
    end

    it 'loads and validates a stored handle without provisioning another key' do
      File.write(handle_path, '0x81000007')
      allow(Open3).to receive(:capture3)
        .with('tpm2_getcap', 'handles-persistent')
        .and_return(["- 0x81000007\n", '', tpm_status])
      expect_any_instance_of(described_class).not_to receive(:run_tpm!)

      tpm = described_class.new(tpm_path: tpm_path_temp)

      expect(tpm.instance_variable_get(:@rsa_handle)).to eq('0x81000007')
    end

    it 'raises rather than silently replacing a recorded handle missing from the TPM' do
      File.write(handle_path, '0x81000007')

      expect { described_class.new(tpm_path: tpm_path_temp) }
        .to raise_error(/refusing to create a replacement key/)
    end
  end

  describe 'binary encryption and decryption' do
    let(:tpm) do
      instance = described_class.allocate
      instance.instance_variable_set(:@tpm_path, tpm_path_temp)
      instance.instance_variable_set(:@rsa_handle, '0x81000000')
      instance
    end

    it 'passes the persistent handle and preserves binary data' do
      encrypted_bytes = "\x00\xFFcipher".b
      decrypted_bytes = "\x00\xFEplain".b
      commands = []
      allow(tpm).to receive(:run_tpm!) do |*args|
        commands << args
        output_path = args[args.index('-o') + 1]
        File.binwrite(output_path, args.first == 'tpm2_rsaencrypt' ? encrypted_bytes : decrypted_bytes)
        true
      end

      expect(tpm.encrypt('plain')).to eq(encrypted_bytes)
      expect(tpm.decrypt(encrypted_bytes)).to eq(decrypted_bytes)
      expect(commands.map { |args| args[2] }).to eq(['0x81000000', '0x81000000'])
      expect(File).not_to exist(File.join(tpm_path_temp, described_class::PLAINTEXT_FILE))
      expect(File).not_to exist(File.join(tpm_path_temp, described_class::CIPHERTEXT_FILE))
    end

    it 'cleans up temporary files when a TPM command fails' do
      allow(tpm).to receive(:run_tpm!).and_raise('TPM command failed')

      expect { tpm.encrypt('plain') }.to raise_error('TPM command failed')
      expect(File).not_to exist(File.join(tpm_path_temp, described_class::PLAINTEXT_FILE))
    end
  end
end
