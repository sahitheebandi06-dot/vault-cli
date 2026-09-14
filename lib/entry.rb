# frozen_string_literal: true

module VaultCLI
  # Represents a single stored credential.
  #
  # Each entry holds a site name, username, password, and an optional category
  # tag (e.g. "Social", "Work", "Finance"). Entries serialize to and from plain
  # Ruby hashes so the Vault can persist them as JSON before encryption.
  class Entry
    VALID_CATEGORIES = %w[Social Work Finance Personal Other].freeze

    attr_accessor :site, :username, :password, :category

    # @param site     [String] domain or service name, e.g. "github.com"
    # @param username [String] login identifier
    # @param password [String] the credential (stored encrypted on disk)
    # @param category [String, nil] optional tag from VALID_CATEGORIES
    # @raise [ArgumentError] if any required field is blank
    def initialize(site:, username:, password:, category: nil)
      validate_presence!(site: site, username: username, password: password)
      @site     = site.strip
      @username = username.strip
      @password = password
      @category = normalize_category(category)
    end

    # Serialize to a plain hash for JSON encoding.
    #
    # @return [Hash]
    def to_h
      {
        'site'     => @site,
        'username' => @username,
        'password' => @password,
        'category' => @category
      }
    end

    # Build an Entry from a deserialized hash.
    #
    # @param hash [Hash] with string keys matching #to_h output
    # @return [Entry]
    def self.from_h(hash)
      new(
        site:     hash['site'],
        username: hash['username'],
        password: hash['password'],
        category: hash['category']
      )
    end

    # Human-readable one-liner used in search results and listings.
    #
    # @return [String]
    def to_s
      tag = @category ? " [#{@category}]" : ''
      "#{@site} — #{@username}#{tag}"
    end

    private

    # Raise if any required field is nil or whitespace-only.
    def validate_presence!(fields)
      fields.each do |name, value|
        if value.nil? || value.to_s.strip.empty?
          raise ArgumentError, "#{name} cannot be blank"
        end
      end
    end

    # Accept any casing of a valid category; default to nil if unrecognized.
    def normalize_category(raw)
      return nil if raw.nil? || raw.strip.empty?

      match = VALID_CATEGORIES.find { |c| c.casecmp(raw.strip).zero? }
      match || raw.strip
    end
  end
end
