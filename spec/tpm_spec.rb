# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require_relative '../lib/tpm'

RSpec.describe VaultCLI::TPM do
  let(:tpm_path_temp) { File.join(Dir.tmpdir, "tpm_test_#{SecureRandom.hex(8)}") }

  before do
    unless example.metadata(:skip_before)
    FileUtils.mkdir_p(tpm_path_temp)
    FileUtils.rm_f(
      File.join(tpm_path_temp, VaultCLI::PRIMARY_CTX)
    )
  end
  
  after do
    FileUtils.rm_rf(tpm_path_temp)
  end

  it 'raises an error when tpm2-tools in unavailable' do
    allow_any_instance_of(VaultCLI::TPM)
      .to receive(:system)
      .and_return(false)
    
    expect {described_class.new}
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
      .with(/tpm2_createprimary/)
    
      described_class.new(tpm_path: tpm_path_temp)
  end

  it 'creates and loads an RSA key when the RSA context is missing' do
    allow_any_instance_of(VaultCLI::TPM)
      .to receive(:system)
      .and_return(true)

    expect(File).not_to exist(
      File.join(tpm_path_temp, described_class::RSA_CTX)
    )

    described_class.new(tpm_path: tpm_path_temp)
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
      .with(/tpm2_createprimary/)
    
    expect_any_instance_of(VaultCLI::TPM)
      .not_to receive(:system)
      .with(/tpm2_create/)
    
      described_class.new(tpm_path: tpm_path_temp)
  end

  it 'encrypts plaintext and returns the generated ciphertext' do

  end

  it 'removes temporary encryption files' do

  end

  it 'decrypts ciphertext and returns the original plaintext' do

  end

  it 'removes temporary decryption files' do

  end

  it 'propagates TPM command failures' do

  end
end