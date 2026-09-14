# frozen_string_literal: true

require_relative '../lib/entry'

RSpec.describe VaultCLI::Entry do
  describe '#initialize' do
    it 'creates an entry with valid fields' do
      entry = described_class.new(site: 'github.com', username: 'sahithee', password: 's3cret')
      expect(entry.site).to eq('github.com')
      expect(entry.username).to eq('sahithee')
      expect(entry.password).to eq('s3cret')
      expect(entry.category).to be_nil
    end

    it 'strips whitespace from site and username' do
      entry = described_class.new(site: '  github.com  ', username: ' user ', password: 'pw')
      expect(entry.site).to eq('github.com')
      expect(entry.username).to eq('user')
    end

    it 'normalizes valid categories to title case' do
      entry = described_class.new(site: 'x.com', username: 'u', password: 'p', category: 'work')
      expect(entry.category).to eq('Work')
    end

    it 'preserves unrecognized category strings' do
      entry = described_class.new(site: 'x.com', username: 'u', password: 'p', category: 'Gaming')
      expect(entry.category).to eq('Gaming')
    end

    it 'raises ArgumentError when site is blank' do
      expect {
        described_class.new(site: '', username: 'u', password: 'p')
      }.to raise_error(ArgumentError, /site cannot be blank/)
    end

    it 'raises ArgumentError when username is blank' do
      expect {
        described_class.new(site: 's', username: '   ', password: 'p')
      }.to raise_error(ArgumentError, /username cannot be blank/)
    end

    it 'raises ArgumentError when password is nil' do
      expect {
        described_class.new(site: 's', username: 'u', password: nil)
      }.to raise_error(ArgumentError, /password cannot be blank/)
    end
  end

  describe '#to_h and .from_h' do
    it 'round-trips through hash serialization' do
      original = described_class.new(site: 'github.com', username: 'sahithee',
                                     password: 'hunter2', category: 'Work')
      restored = described_class.from_h(original.to_h)

      expect(restored.site).to eq(original.site)
      expect(restored.username).to eq(original.username)
      expect(restored.password).to eq(original.password)
      expect(restored.category).to eq(original.category)
    end
  end

  describe '#to_s' do
    it 'formats without category when none set' do
      entry = described_class.new(site: 'github.com', username: 'sahithee', password: 'x')
      expect(entry.to_s).to eq('github.com — sahithee')
    end

    it 'includes category tag when set' do
      entry = described_class.new(site: 'github.com', username: 'sahithee',
                                  password: 'x', category: 'Work')
      expect(entry.to_s).to eq('github.com — sahithee [Work]')
    end
  end
end
