# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'securerandom'
require_relative '../lib/tpm'

RSpec.describe VaultCLI::TPM do
  let(:tpm_path_temp) { File.join(Dir.tmpdir, "tpm_test_#{SecureRandom.hex(8)}") }

  before do
    FileUtils.mkdir_p(tpm_path_temp)
    FileUtils.rm_f([
                     File.join(tpm_path_temp, VaultCLI::TPM::PRIMARY_CTX),
                     File.join(tpm_path_temp, VaultCLI::TPM::RSA_CTX),
                     File.join(tpm_path_temp, VaultCLI::TPM::RSA_PUB),
                     File.join(tpm_path_temp, VaultCLI::TPM::RSA_PRIV),
                     File.join(tpm_path_temp, VaultCLI::TPM::PLAINTEXT_FILE),
                     File.join(tpm_path_temp, VaultCLI::TPM::CIPHERTEXT_FILE)
                   ])
  end

  after do
    FileUtils.rm_rf(tpm_path_temp)
  end

  describe '#initialize' do
    it 'raises an error when tpm2-tools in unavailable' do
      allow_any_instance_of(VaultCLI::TPM)
        .to receive(:system)
        .and_return(false)

      expect { described_class.new }
        .to raise_error('tpm2-tools not found. Please install tpm2-tools to use TPM functionality.')
    end

    it 'uses the supplied TPM directory' do
      allow_any_instance_of(VaultCLI::TPM)
        .to receive(:system)
        .and_return(true)

      tpm = described_class.new(tpm_path: tpm_path_temp)

      expect(tpm.instance_variable_get(:@tpm_path)).to eq(tpm_path_temp)
    end

    it 'creates a primary key when the primary context is missing' do
      allow_any_instance_of(VaultCLI::TPM)
        .to receive(:system)
        .and_return(true)

      expect_any_instance_of(VaultCLI::TPM)
        .to receive(:system)
        .with("tpm2_createprimary -C o -c #{File.join(tpm_path_temp,
                                                      described_class::PRIMARY_CTX)}")
        .and_return(true)

      expect(File).not_to exist(
        File.join(tpm_path_temp, described_class::PRIMARY_CTX)
      )

      described_class.new(tpm_path: tpm_path_temp)
    end

    it 'does not recreate an existing primary key' do
      FileUtils.mkdir_p(tpm_path_temp)
      primary_context = File.join(
        tpm_path_temp,
        described_class::PRIMARY_CTX
      )

      File.write(primary_context, 'existing key')

      allow_any_instance_of(VaultCLI::TPM)
        .to receive(:system)
        .and_return(true)

      expect_any_instance_of(VaultCLI::TPM)
        .not_to receive(:system)
        .with("tpm2_createprimary -C o -c #{primary_context}")

      described_class.new(tpm_path: tpm_path_temp)
    end

    it 'creates and loads an RSA key when the RSA context is missing' do
      primary_context = File.join(tpm_path_temp, described_class::PRIMARY_CTX)
      rsa_context = File.join(tpm_path_temp, described_class::RSA_CTX)
      rsa_public = File.join(tpm_path_temp, described_class::RSA_PUB)
      rsa_private = File.join(tpm_path_temp, described_class::RSA_PRIV)

      commands = []

      allow_any_instance_of(VaultCLI::TPM)
        .to receive(:system) do |command|
          commands << command

          File.write(rsa_context, 'generated RSA context') if command.start_with?('tpm2_load')

          true
        end

      described_class.new(tpm_path: tpm_path_temp)

      expect(commands).to include(
        "tpm2_create -G rsa -u #{rsa_public} -r #{rsa_private} -C #{primary_context}"
      )
      expect(commands).to include(
        "tpm2_load -C #{primary_context} -u #{rsa_public} -r #{rsa_private} -c #{rsa_context}"
      )
      expect(File).to exist(rsa_context)
    end

    it 'does not recreate an existing RSA key' do
      FileUtils.mkdir_p(tpm_path_temp)
      primary_context = File.join(
        tpm_path_temp,
        described_class::PRIMARY_CTX
      )

      rsa_context = File.join(
        tpm_path_temp,
        described_class::RSA_CTX
      )

      File.write(primary_context, 'existing key')
      File.write(rsa_context, 'existing rsa key')

      allow_any_instance_of(VaultCLI::TPM)
        .to receive(:system)
        .and_return(true)

      expect_any_instance_of(VaultCLI::TPM)
        .not_to receive(:system)
        .with(
          "tpm2_create -G rsa -u #{File.join(tpm_path_temp, described_class::RSA_PUB)} " \
          "-r #{File.join(tpm_path_temp, described_class::RSA_PRIV)} " \
          "-C #{primary_context}"
        )

      expect_any_instance_of(VaultCLI::TPM)
        .not_to receive(:system)
        .with(
          "tpm2_load -C #{primary_context} " \
          "-u #{File.join(tpm_path_temp, described_class::RSA_PUB)} " \
          "-r #{File.join(tpm_path_temp, described_class::RSA_PRIV)} " \
          "-c #{rsa_context}"
        )

      described_class.new(tpm_path: tpm_path_temp)
    end
  end

  describe '#encrypt' do
    it 'encrypts plaintext and returns the generated ciphertext' do
      tpm = described_class.allocate
      tpm.instance_variable_set(:@tpm_path, tpm_path_temp)

      expected_ciphertext = 'fake encrypted bytes'
      ciphertext_path = File.join(tpm_path_temp, described_class::CIPHERTEXT_FILE)

      allow(tpm).to receive(:system) do |command|
        File.binwrite(ciphertext_path, expected_ciphertext) if command.include?('tpm2_rsaencrypt')
        true
      end

      expect(tpm.encrypt('secret')).to eq(expected_ciphertext)
    end

    it 'removes temporary encryption files' do
      tpm = described_class.allocate
      tpm.instance_variable_set(:@tpm_path, tpm_path_temp)

      expected_ciphertext = 'fake encrypted bytes'
      ciphertext_path = File.join(tpm_path_temp, described_class::CIPHERTEXT_FILE)
      plaintext_path = File.join(tpm_path_temp, described_class::PLAINTEXT_FILE)
      rsa_context = File.join(tpm_path_temp, described_class::RSA_CTX)

      expect(File)
        .to receive(:write)
        .with(plaintext_path, 'secret')
        .and_call_original

      allow(tpm).to receive(:system) do |command|
        File.binwrite(ciphertext_path, expected_ciphertext) if command.include?('tpm2_rsaencrypt')
        true
      end

      tpm.encrypt('secret')

      expect(tpm).to have_received(:system).with(
        "tpm2_rsaencrypt -c #{rsa_context} -o #{ciphertext_path} #{plaintext_path}"
      )

      expect(File).not_to exist(
        File.join(tpm_path_temp, described_class::PLAINTEXT_FILE)
      )
      expect(File).not_to exist(
        File.join(tpm_path_temp, described_class::CIPHERTEXT_FILE)
      )
    end

    it 'fails when encryption does not produce ciphertext' do
      tpm = described_class.allocate
      tpm.instance_variable_set(:@tpm_path, tpm_path_temp)

      allow(tpm).to receive(:system) do |_command|
        false
      end

      expect { tpm.encrypt('secret') }
        .to raise_error(Errno::ENOENT)
    end
  end

  describe '#decrypt' do
    it 'decrypts ciphertext and returns the original plaintext' do
      tpm = described_class.allocate
      tpm.instance_variable_set(:@tpm_path, tpm_path_temp)

      expected_plaintext = 'secret'
      plaintext_path = File.join(tpm_path_temp, described_class::PLAINTEXT_FILE)

      allow(tpm).to receive(:system) do |command|
        File.binwrite(plaintext_path, expected_plaintext) if command.include?('tpm2_rsadecrypt')
        true
      end

      expect(tpm.decrypt('fake encrypted bytes')).to eq(expected_plaintext)
    end

    it 'removes temporary decryption files' do
      tpm = described_class.allocate
      tpm.instance_variable_set(:@tpm_path, tpm_path_temp)

      expected_plaintext = 'secret'
      plaintext_path = File.join(tpm_path_temp, described_class::PLAINTEXT_FILE)

      allow(tpm).to receive(:system) do |command|
        File.binwrite(plaintext_path, expected_plaintext) if command.include?('tpm2_rsadecrypt')
        true
      end

      tpm.decrypt('fake encrypted bytes')

      expect(File).not_to exist(
        File.join(tpm_path_temp, described_class::PLAINTEXT_FILE)
      )
      expect(File).not_to exist(
        File.join(tpm_path_temp, described_class::CIPHERTEXT_FILE)
      )
    end
  end
end
