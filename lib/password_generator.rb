# frozen_string_literal: true

require 'securerandom'

module VaultCLI
  # Generates cryptographically random passwords with configurable character
  # classes and provides a simple strength rating.
  #
  # Uses SecureRandom as the entropy source so generated passwords are suitable
  # for real credential storage.
  class PasswordGenerator
    LOWERCASE = ('a'..'z').to_a.freeze
    UPPERCASE = ('A'..'Z').to_a.freeze
    DIGITS    = ('0'..'9').to_a.freeze
    SYMBOLS   = %w[! @ # $ % ^ & * ( ) _ + - = [ ] { } | ; : ' , . < > ? /].freeze

    # Strength thresholds (based on estimated entropy bits).
    STRENGTH_THRESHOLDS = {
      weak:       0,
      fair:      28,
      good:      50,
      strong:    70,
      excellent: 90
    }.freeze

    # Generate a random password.
    #
    # @param length    [Integer] desired length (must be >= 1)
    # @param uppercase [Boolean] include uppercase letters (default: true)
    # @param lowercase [Boolean] include lowercase letters (default: true)
    # @param digits    [Boolean] include digits (default: true)
    # @param symbols   [Boolean] include symbols (default: true)
    # @return [String] the generated password
    # @raise [ArgumentError] if length < 1 or no character classes selected
    def self.generate(length:, uppercase: true, lowercase: true, digits: true, symbols: true)
      raise ArgumentError, 'Password length must be at least 1' if length < 1

      pool = build_pool(uppercase: uppercase, lowercase: lowercase,
                        digits: digits, symbols: symbols)
      raise ArgumentError, 'At least one character class must be enabled' if pool.empty?

      # Generate and ensure at least one character from each selected class.
      required = required_chars(uppercase: uppercase, lowercase: lowercase,
                                digits: digits, symbols: symbols)

      if length < required.size
        raise ArgumentError,
              "Length #{length} is too short to include all selected character classes"
      end

      remaining = length - required.size
      chars = required + Array.new(remaining) { pool.sample(random: SecureRandom) }
      chars.shuffle(random: SecureRandom).join
    end

    # Rate the strength of an arbitrary password.
    #
    # Returns a symbol: :weak, :fair, :good, :strong, or :excellent.
    #
    # @param password [String]
    # @return [Symbol]
    def self.strength(password)
      bits = entropy_bits(password)
      STRENGTH_THRESHOLDS.to_a.reverse.each do |label, threshold|
        return label if bits >= threshold
      end
      :weak
    end

    # Estimated entropy in bits based on pool size and length.
    #
    # @param password [String]
    # @return [Float]
    def self.entropy_bits(password)
      return 0.0 if password.nil? || password.empty?

      pool_size = 0
      pool_size += 26 if password.match?(/[a-z]/)
      pool_size += 26 if password.match?(/[A-Z]/)
      pool_size += 10 if password.match?(/\d/)
      pool_size += SYMBOLS.size if password.match?(/[^a-zA-Z0-9]/)
      pool_size = [pool_size, 1].max

      password.length * Math.log2(pool_size)
    end

    class << self
      private

      # Build the full character pool from selected classes.
      def build_pool(uppercase:, lowercase:, digits:, symbols:)
        pool = []
        pool.concat(UPPERCASE) if uppercase
        pool.concat(LOWERCASE) if lowercase
        pool.concat(DIGITS)    if digits
        pool.concat(SYMBOLS)   if symbols
        pool
      end

      # One random character from each enabled class to guarantee coverage.
      def required_chars(uppercase:, lowercase:, digits:, symbols:)
        chars = []
        chars << UPPERCASE.sample(random: SecureRandom) if uppercase
        chars << LOWERCASE.sample(random: SecureRandom) if lowercase
        chars << DIGITS.sample(random: SecureRandom)    if digits
        chars << SYMBOLS.sample(random: SecureRandom)   if symbols
        chars
      end
    end
  end
end
