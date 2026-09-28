# frozen_string_literal: true

require 'openssl'
require 'securerandom'
require 'json'
require_relative 'tpm'
require_relative 'entry'

module VaultCLI
  # Manages the collection of credential entries and handles encrypted
  # persistence to disk.
  #
  # Encryption scheme:
  #   - Software key: PBKDF2-HMAC-SHA256, 600_000 iterations, 32 bytes
  #   - TPM key: HKDF combines the password-derived key with a TPM-wrapped secret
  #   - Cipher: AES-256-GCM (authenticated encryption)
  #   - Software format: salt || iv || auth_tag || ciphertext
  #   - TPM format: magic || salt || iv || auth_tag || wrapped-secret-length ||
  #                 wrapped-secret || ciphertext
  #
  # No password or plaintext credential ever touches the filesystem.
  class Vault
    PBKDF2_ITERATIONS = 600_000
    KEY_LENGTH         = 32  # bytes (AES-256)
    SALT_LENGTH        = 32  # bytes
    IV_LENGTH          = 12  # bytes (GCM standard)
    TAG_LENGTH         = 16  # bytes (GCM auth tag)
    CIPHER_ALGO        = 'aes-256-gcm'
    TPM_ENVELOPE_MAGIC = 'VLT1'.b
    TPM_KDF_INFO       = 'VaultCLI TPM-backed encryption key'

    attr_reader :entries, :path

    # @param path [String] filesystem path for the encrypted vault file
    def initialize(path: File.join(Dir.home, '.vault_cli_store'), tpm: :auto)
      @path    = path
      @entries = []
      @tpm     = tpm == :auto ? detect_tpm : tpm
    end

    # Decrypt and load entries from disk using the given master password.
    #
    # @param master_password [String]
    # @return [Boolean] true if unlock succeeded
    # @raise [RuntimeError] if the file is corrupt or the password is wrong
    def unlock(master_password)
      raw = File.binread(@path)
      if raw.start_with?(TPM_ENVELOPE_MAGIC)
        salt, iv, auth_tag, wrapped_secret, ciphertext = parse_tpm_envelope(raw)
        raise 'This vault requires its TPM key, but TPM is unavailable' unless @tpm

        tpm_secret = @tpm.decrypt(wrapped_secret)
        key = derive_tpm_key(master_password, salt, tpm_secret)
      else
        salt       = raw.byteslice(0, SALT_LENGTH)
        iv         = raw.byteslice(SALT_LENGTH, IV_LENGTH)
        auth_tag   = raw.byteslice(SALT_LENGTH + IV_LENGTH, TAG_LENGTH)
        ciphertext = raw.byteslice(SALT_LENGTH + IV_LENGTH + TAG_LENGTH..)
        key = derive_key(master_password, salt)
      end

      decipher = OpenSSL::Cipher.new(CIPHER_ALGO)
      decipher.decrypt
      decipher.key      = key
      decipher.iv       = iv
      decipher.auth_tag = auth_tag

      plaintext = decipher.update(ciphertext) + decipher.final
      @entries = JSON.parse(plaintext).map { |h| Entry.from_h(h) }
      true
    rescue OpenSSL::Cipher::CipherError
      raise 'Wrong master password or corrupt vault file'
    end

    # Encrypt and persist entries to disk.
    #
    # @param master_password [String]
    def save(master_password)
      salt = SecureRandom.random_bytes(SALT_LENGTH)
      if @tpm
        tpm_secret = SecureRandom.random_bytes(KEY_LENGTH)
        wrapped_secret = @tpm.encrypt(tpm_secret)
        key = derive_tpm_key(master_password, salt, tpm_secret)
      else
        key = derive_key(master_password, salt)
      end

      cipher = OpenSSL::Cipher.new(CIPHER_ALGO)
      cipher.encrypt
      cipher.key = key
      iv = cipher.random_iv

      plaintext  = JSON.generate(@entries.map(&:to_h))
      ciphertext = cipher.update(plaintext) + cipher.final
      auth_tag   = cipher.auth_tag

      header = if @tpm
                 TPM_ENVELOPE_MAGIC + salt + iv + auth_tag +
                   [wrapped_secret.bytesize].pack('N') + wrapped_secret
               else
                 salt + iv + auth_tag
               end
      File.binwrite(@path, header + ciphertext)
    end

    # Returns true when a vault file already exists on disk.
    #
    # @return [Boolean]
    def persisted?
      File.exist?(@path)
    end

    # Add a new entry to the vault.
    #
    # @param entry [Entry]
    def add(entry)
      @entries << entry
    end

    # Remove the first entry whose site matches exactly (case-insensitive).
    #
    # @param site [String]
    # @return [Entry, nil] the removed entry, or nil if not found
    def delete(site)
      idx = @entries.index { |e| e.site.casecmp(site.strip).zero? }
      return nil unless idx

      @entries.delete_at(idx)
    end

    # Find entries whose site name contains the query (case-insensitive).
    #
    # @param query [String]
    # @return [Array<Entry>]
    def search(query)
      pattern = query.strip.downcase
      @entries.select { |e| e.site.downcase.include?(pattern) }
    end

    # Return entries filtered by category (case-insensitive).
    #
    # @param category [String]
    # @return [Array<Entry>]
    def filter_by_category(category)
      @entries.select { |e| e.category&.casecmp(category.strip)&.zero? }
    end

    private

    def detect_tpm
      TPM.new
    rescue TPM::UnavailableError
      nil
    end

    def parse_tpm_envelope(raw)
      offset = TPM_ENVELOPE_MAGIC.bytesize
      salt = raw.byteslice(offset, SALT_LENGTH)
      offset += SALT_LENGTH
      iv = raw.byteslice(offset, IV_LENGTH)
      offset += IV_LENGTH
      auth_tag = raw.byteslice(offset, TAG_LENGTH)
      offset += TAG_LENGTH
      length_bytes = raw.byteslice(offset, 4)
      raise 'Corrupt TPM vault file' unless length_bytes&.bytesize == 4

      wrapped_length = length_bytes.unpack1('N')
      offset += 4
      wrapped_secret = raw.byteslice(offset, wrapped_length)
      unless wrapped_length.positive? && wrapped_secret&.bytesize == wrapped_length
        raise 'Corrupt TPM vault file'
      end

      offset += wrapped_length
      ciphertext = raw.byteslice(offset..)
      [salt, iv, auth_tag, wrapped_secret, ciphertext]
    end

    def derive_tpm_key(password, salt, tpm_secret)
      password_key = derive_key(password, salt)
      OpenSSL::KDF.hkdf(
        password_key + tpm_secret,
        salt: salt,
        info: TPM_KDF_INFO,
        length: KEY_LENGTH,
        hash: 'sha256'
      )
    end

    # Derive a symmetric key from the master password and a random salt.
    #
    # @param password [String]
    # @param salt     [String] raw bytes
    # @return [String] raw key bytes
    def derive_key(password, salt)
      OpenSSL::KDF.pbkdf2_hmac(
        password,
        salt:       salt,
        iterations: PBKDF2_ITERATIONS,
        length:     KEY_LENGTH,
        hash:       'sha256'
      )
    end
  end
end
