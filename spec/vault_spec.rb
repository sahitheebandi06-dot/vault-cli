# frozen_string_literal: true

require 'tmpdir'
require_relative '../lib/vault'

RSpec.describe VaultCLI::Vault do
  let(:vault_path) { File.join(Dir.tmpdir, "vault_test_#{SecureRandom.hex(8)}") }
  let(:master_password) { 'correct-horse-battery-staple' }

  after { FileUtils.rm_f(vault_path) }

  describe '#save and #unlock' do
    it 'round-trips entries through encryption' do
      vault = described_class.new(path: vault_path)
      vault.add(VaultCLI::Entry.new(site: 'github.com', username: 'sahithee', password: 'hunter2'))
      vault.add(VaultCLI::Entry.new(site: 'google.com', username: 'sahithee', password: 'p@ssw0rd'))
      vault.save(master_password)

      loaded = described_class.new(path: vault_path)
      loaded.unlock(master_password)

      expect(loaded.entries.size).to eq(2)
      expect(loaded.entries[0].site).to eq('github.com')
      expect(loaded.entries[1].password).to eq('p@ssw0rd')
    end

    it 'rejects the wrong master password' do
      vault = described_class.new(path: vault_path)
      vault.add(VaultCLI::Entry.new(site: 'x.com', username: 'u', password: 'p'))
      vault.save(master_password)

      loaded = described_class.new(path: vault_path)
      expect { loaded.unlock('wrong-password') }.to raise_error(RuntimeError, /Wrong master password/)
    end

    it 'never writes plaintext to the vault file' do
      vault = described_class.new(path: vault_path)
      secret = 'SuperS3cretP@ssword!'
      vault.add(VaultCLI::Entry.new(site: 'bank.com', username: 'admin', password: secret))
      vault.save(master_password)

      raw = File.binread(vault_path)
      expect(raw).not_to include(secret)
      expect(raw).not_to include('bank.com')
      expect(raw).not_to include('admin')
    end
  end

  describe '#persisted?' do
    it 'returns false when no file exists' do
      vault = described_class.new(path: vault_path)
      expect(vault.persisted?).to be false
    end

    it 'returns true after saving' do
      vault = described_class.new(path: vault_path)
      vault.save(master_password)
      expect(vault.persisted?).to be true
    end
  end

  describe '#add' do
    it 'appends entries to the collection' do
      vault = described_class.new(path: vault_path)
      vault.add(VaultCLI::Entry.new(site: 'a.com', username: 'u', password: 'p'))
      vault.add(VaultCLI::Entry.new(site: 'b.com', username: 'u', password: 'p'))
      expect(vault.entries.size).to eq(2)
    end
  end

  describe '#delete' do
    it 'removes an entry by exact site name (case-insensitive)' do
      vault = described_class.new(path: vault_path)
      vault.add(VaultCLI::Entry.new(site: 'Twitter.com', username: 'u', password: 'p'))
      removed = vault.delete('twitter.com')

      expect(removed.site).to eq('Twitter.com')
      expect(vault.entries).to be_empty
    end

    it 'returns nil when the site is not found' do
      vault = described_class.new(path: vault_path)
      expect(vault.delete('nonexistent.com')).to be_nil
    end
  end

  describe '#search' do
    let(:vault) do
      v = described_class.new(path: vault_path)
      v.add(VaultCLI::Entry.new(site: 'github.com', username: 'sahithee', password: 'p1'))
      v.add(VaultCLI::Entry.new(site: 'google.com', username: 'sahithee', password: 'p2'))
      v.add(VaultCLI::Entry.new(site: 'gitlab.com', username: 'sahithee', password: 'p3'))
      v
    end

    it 'finds entries matching a partial site name' do
      results = vault.search('git')
      expect(results.map(&:site)).to contain_exactly('github.com', 'gitlab.com')
    end

    it 'returns an empty array when nothing matches' do
      expect(vault.search('xyz')).to be_empty
    end

    it 'is case-insensitive' do
      expect(vault.search('GOOGLE').size).to eq(1)
    end
  end

  describe '#filter_by_category' do
    it 'returns only entries in the given category' do
      vault = described_class.new(path: vault_path)
      vault.add(VaultCLI::Entry.new(site: 'a.com', username: 'u', password: 'p', category: 'Work'))
      vault.add(VaultCLI::Entry.new(site: 'b.com', username: 'u', password: 'p', category: 'Social'))
      vault.add(VaultCLI::Entry.new(site: 'c.com', username: 'u', password: 'p', category: 'Work'))

      results = vault.filter_by_category('work')
      expect(results.size).to eq(2)
      expect(results.map(&:site)).to contain_exactly('a.com', 'c.com')
    end
  end
end
