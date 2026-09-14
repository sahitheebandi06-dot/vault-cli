# frozen_string_literal: true

require_relative '../lib/password_generator'

RSpec.describe VaultCLI::PasswordGenerator do
  describe '.generate' do
    it 'produces a password of the requested length' do
      pw = described_class.generate(length: 16)
      expect(pw.length).to eq(16)
    end

    it 'includes all character classes by default' do
      # With length 20, probability of missing a class is negligible.
      pw = described_class.generate(length: 20)
      expect(pw).to match(/[a-z]/)
      expect(pw).to match(/[A-Z]/)
      expect(pw).to match(/\d/)
      expect(pw).to match(/[^a-zA-Z0-9]/)
    end

    it 'respects disabled character classes' do
      pw = described_class.generate(length: 20, uppercase: false, symbols: false)
      expect(pw).not_to match(/[A-Z]/)
      expect(pw).not_to match(/[^a-z0-9]/)
    end

    it 'generates only digits when other classes are disabled' do
      pw = described_class.generate(length: 10, uppercase: false,
                                    lowercase: false, symbols: false)
      expect(pw).to match(/\A\d{10}\z/)
    end

    it 'raises ArgumentError for length < 1' do
      expect {
        described_class.generate(length: 0)
      }.to raise_error(ArgumentError, /at least 1/)
    end

    it 'raises ArgumentError when no character classes are enabled' do
      expect {
        described_class.generate(length: 10, uppercase: false, lowercase: false,
                                 digits: false, symbols: false)
      }.to raise_error(ArgumentError, /character class/)
    end

    it 'raises ArgumentError when length is too short for all selected classes' do
      expect {
        described_class.generate(length: 2, uppercase: true, lowercase: true,
                                 digits: true, symbols: true)
      }.to raise_error(ArgumentError, /too short/)
    end

    it 'generates unique passwords on successive calls' do
      passwords = Array.new(5) { described_class.generate(length: 20) }
      expect(passwords.uniq.size).to eq(5)
    end
  end

  describe '.strength' do
    it 'rates a short lowercase password as weak' do
      expect(described_class.strength('abc')).to eq(:weak)
    end

    it 'rates a medium mixed-case password as fair or better' do
      result = described_class.strength('Abcdef1')
      expect(%i[fair good]).to include(result)
    end

    it 'rates a long mixed password as strong or excellent' do
      pw = described_class.generate(length: 24)
      result = described_class.strength(pw)
      expect(%i[strong excellent]).to include(result)
    end

    it 'returns :weak for an empty string' do
      expect(described_class.strength('')).to eq(:weak)
    end
  end

  describe '.entropy_bits' do
    it 'returns 0.0 for nil' do
      expect(described_class.entropy_bits(nil)).to eq(0.0)
    end

    it 'returns 0.0 for an empty string' do
      expect(described_class.entropy_bits('')).to eq(0.0)
    end

    it 'calculates entropy proportional to length' do
      short_bits = described_class.entropy_bits('abcd')
      long_bits  = described_class.entropy_bits('abcdefgh')
      expect(long_bits).to be > short_bits
    end
  end
end
