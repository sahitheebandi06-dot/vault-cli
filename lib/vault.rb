# frozen_string_literal: true

require 'openssl'
require 'securerandom'
require 'json'
require_relative 'entry'

module VaultCLI
  # Manages the collection of credential entries and handles encrypted
  # persistence to disk.
  #
  # Encryption scheme:
  #   - Key derivation: PBKDF2-HMAC-SHA256, 600_000 iterations, 32-byte key
  #   - Cipher: AES-256-GCM (authenticated encryption)
  #   - File format: salt (32 B) || iv (12 B) || auth_tag (16 B) || ciphertext
  #
  # No password or plaintext credential ever touches the filesystem.
  class Vault
    PBKDF2_ITERATIONS = 600_000
    KEY_LENGTH         = 32  # bytes (AES-256)
    SALT_LENGTH        = 32  # bytes
    IV_LENGTH          = 12  # bytes (GCM standard)
    TAG_LENGTH         = 16  # bytes (GCM auth tag)
    CIPHER_ALGO        = 'aes-256-gcm'

    attr_reader :entries, :path

    # @param path [String] filesystem path for the encrypted vault file
    def initialize(path: File.join(Dir.home, '.vault_cli_store'))
      @path    = path
      @entries = []
    end

    # Decrypt and load entries from disk using the given master password.
    #
    # @param master_password [String]
    # @return [Boolean] true if unlock succeeded
    # @raise [RuntimeError] if the file is corrupt or the password is wrong
    def unlock(master_password)
      raw = File.binread(@path)
      salt       = raw.byteslice(0, SALT_LENGTH)
      iv         = raw.byteslice(SALT_LENGTH, IV_LENGTH)
      auth_tag   = raw.byteslice(SALT_LENGTH + IV_LENGTH, TAG_LENGTH)
      ciphertext = raw.byteslice(SALT_LENGTH + IV_LENGTH + TAG_LENGTH..)

      key = derive_key(master_password, salt)

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
      key  = derive_key(master_password, salt)

      cipher = OpenSSL::Cipher.new(CIPHER_ALGO)
      cipher.encrypt
      cipher.key = key
      iv = cipher.random_iv

      plaintext  = JSON.generate(@entries.map(&:to_h))
      ciphertext = cipher.update(plaintext) + cipher.final
      auth_tag   = cipher.auth_tag

      File.binwrite(@path, salt + iv + auth_tag + ciphertext)
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
