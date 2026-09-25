# frozen_string_literal: true

module VaultCLI
  class TPM
    PRIMARY_CTX = 'tpm_primary.ctx'
    RSA_PUB = 'tpm_rsa.pub'
    RSA_PRIV = 'tpm_rsa.priv'
    RSA_CTX = 'tpm_rsa.ctx'
    PLAINTEXT_FILE = 'tpm_plain.txt'
    CIPHERTEXT_FILE = 'tpm_cipher.txt'

    def initialize(path: Dir.tmpdir)
      # Ensure TPM tools are available
      unless system('which tpm2_createprimary > /dev/null 2>&1')
        raise 'tpm2-tools not found. Please install tpm2-tools to use TPM functionality.'
      end

      @path = path

      # Initialize TPM primary key if it doesn't exist
      create_primary_key unless File.exist?(File.join(@path, PRIMARY_CTX))

      # Initialize RSA key if it doesn't exist
      return if File.exist?(File.join(@path, RSA_CTX))

      system("tpm2_create -G rsa -u #{File.join(@path,
                                                RSA_PUB)} -r #{File.join(@path,
                                                                         RSA_PRIV)} -C #{File.join(
                                                                           @path, PRIMARY_CTX
                                                                         )}")
      system("tpm2_load -C #{File.join(@path,
                                       PRIMARY_CTX)} -u #{File.join(@path,
                                                                    RSA_PUB)} -r #{File.join(
                                                                      @path, RSA_PRIV
                                                                    )} -c #{File.join(@path,
                                                                                      RSA_CTX)}")
    end
  end

  def create_primary_key
    system("tpm2_createprimary -C o -c #{File.join(@path, PRIMARY_CTX)}")
  end

  def encrypt(plaintext)
    File.write(File.join(@path, PLAINTEXT_FILE), plaintext)
    system("tpm2_rsaencrypt -c #{File.join(@path,
                                           RSA_CTX)} -o #{File.join(@path,
                                                                    CIPHERTEXT_FILE)} #{File.join(
                                                                      @path, PLAINTEXT_FILE
                                                                    )}")
    ciphertext = File.binread(File.join(@path, CIPHERTEXT_FILE))
    FileUtils.rm_f(File.join(@path, PLAINTEXT_FILE))
    FileUtils.rm_f(File.join(@path, CIPHERTEXT_FILE))
    ciphertext
  end

  def decrypt(ciphertext)
    File.write(File.join(@path, CIPHERTEXT_FILE), ciphertext)
    system("tpm2_rsadecrypt -c #{File.join(@path,
                                           RSA_CTX)} -o #{File.join(@path,
                                                                    PLAINTEXT_FILE)} #{File.join(
                                                                      @path, CIPHERTEXT_FILE
                                                                    )}")
    plaintext = File.read(File.join(@path, PLAINTEXT_FILE))
    FileUtils.rm_f(File.join(@path, PLAINTEXT_FILE))
    FileUtils.rm_f(File.join(@path, CIPHERTEXT_FILE))
    plaintext
  end

  private_class_method :create_primary_key
end
