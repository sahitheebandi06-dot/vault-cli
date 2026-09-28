# frozen_string_literal: true

require 'open3'
require 'fileutils'

module VaultCLI
  class TPM
    class UnavailableError < StandardError; end

    PRIMARY_CTX = 'tpm_primary.ctx'
    RSA_PUB = 'tpm_rsa.pub'
    RSA_PRIV = 'tpm_rsa.priv'
    RSA_CTX = 'tpm_rsa.ctx'
    HANDLE_FILE = 'tpm_rsa.handle'
    PLAINTEXT_FILE = 'tpm_plain.txt'
    CIPHERTEXT_FILE = 'tpm_cipher.txt'
    PERSISTENT_HANDLE_START = 0x81000000
    PERSISTENT_HANDLE_END = 0x81FFFFFF

    def initialize(tpm_path: File.join(Dir.home, '.local', 'share', 'vault-cli', 'tpm'))
      unless system('which', 'tpm2_createprimary', out: File::NULL, err: File::NULL)
        raise UnavailableError, 'tpm2-tools not found. Please install tpm2-tools to use TPM functionality.'
      end
      unless system('tpm2_getcap', 'properties-fixed', out: File::NULL, err: File::NULL)
        raise UnavailableError, 'TPM device is unavailable'
      end

      @tpm_path = tpm_path
      FileUtils.mkdir_p(@tpm_path, mode: 0o700)

      with_provisioning_lock { load_or_create_persistent_key }
    end

    def encrypt(plaintext)
      plaintext_path = File.join(@tpm_path, PLAINTEXT_FILE)
      ciphertext_path = File.join(@tpm_path, CIPHERTEXT_FILE)

      File.binwrite(plaintext_path, plaintext)
      run_tpm!('tpm2_rsaencrypt', '-c', @rsa_handle, '-o', ciphertext_path, plaintext_path)
      File.binread(ciphertext_path)
    ensure
      FileUtils.rm_f(plaintext_path) if plaintext_path
      FileUtils.rm_f(ciphertext_path) if ciphertext_path
    end

    def decrypt(ciphertext)
      ciphertext_path = File.join(@tpm_path, CIPHERTEXT_FILE)
      plaintext_path = File.join(@tpm_path, PLAINTEXT_FILE)

      File.binwrite(ciphertext_path, ciphertext)
      run_tpm!('tpm2_rsadecrypt', '-c', @rsa_handle, '-o', plaintext_path, ciphertext_path)
      File.binread(plaintext_path)
    ensure
      FileUtils.rm_f(plaintext_path) if plaintext_path
      FileUtils.rm_f(ciphertext_path) if ciphertext_path
    end

    private

    def with_provisioning_lock
      lock_path = File.join(@tpm_path, '.provision.lock')
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      end
    end

    def load_or_create_persistent_key
      handle_path = File.join(@tpm_path, HANDLE_FILE)
      if File.file?(handle_path)
        @rsa_handle = validate_stored_handle(File.read(handle_path).strip)
        return
      end

      used_handles = persistent_handles
      @rsa_handle = free_persistent_handle(used_handles)
      provision_rsa_key
      File.open(handle_path, 'wb', 0o600) { |file| file.write(@rsa_handle) }
    end

    def validate_stored_handle(handle)
      match = /\A0x([0-9a-f]{8})\z/i.match(handle)
      value = match && match[1].to_i(16)
      unless value&.between?(PERSISTENT_HANDLE_START, PERSISTENT_HANDLE_END)
        raise "Invalid stored TPM handle in #{HANDLE_FILE}"
      end

      unless persistent_handles.include?(value)
        raise "Stored TPM handle #{handle} is not present; refusing to create a replacement key"
      end

      format('0x%08X', value)
    end

    def provision_rsa_key
      primary_context_path = File.join(@tpm_path, PRIMARY_CTX)
      rsa_public_path = File.join(@tpm_path, RSA_PUB)
      rsa_private_path = File.join(@tpm_path, RSA_PRIV)
      rsa_context_path = File.join(@tpm_path, RSA_CTX)

      begin
        run_tpm!('tpm2_createprimary', '-C', 'o', '-c', primary_context_path)
        run_tpm!(
          'tpm2_create', '-G', 'rsa', '-u', rsa_public_path,
          '-r', rsa_private_path, '-C', primary_context_path
        )
        run_tpm!(
          'tpm2_load', '-C', primary_context_path, '-u', rsa_public_path,
          '-r', rsa_private_path, '-c', rsa_context_path
        )
        run_tpm!(
          'tpm2_evictcontrol', '-C', 'o', '-c', rsa_context_path, @rsa_handle
        )
      ensure
        FileUtils.rm_f([primary_context_path, rsa_context_path])
      end
    end

    def run_tpm!(*args)
      return true if system(*args)

      raise "TPM command failed: #{args.first}"
    end

    def persistent_handles
      output, _error, status = Open3.capture3(
        'tpm2_getcap', 'handles-persistent'
      )
      raise UnavailableError, 'Could not list persistent TPM handles' unless status.success?

      output.scan(/0x[0-9a-fA-F]+/).map { |handle| handle.to_i(16) }
    end

    def free_persistent_handle(used_handles)
      handle = (PERSISTENT_HANDLE_START..PERSISTENT_HANDLE_END).find do |value|
        !used_handles.include?(value)
      end
      raise 'No free persistent TPM handles' unless handle

      format('0x%08X', handle)
    end
  end
end
