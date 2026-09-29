# frozen_string_literal: true

require_relative '../lib/cli'

RSpec.describe VaultCLI::CLI do
  let(:entry_one) do
    VaultCLI::Entry.new(site: 'github.com', username: 'alice', password: 'first-password')
  end
  let(:entry_two) do
    VaultCLI::Entry.new(site: 'gitlab.com', username: 'bob', password: 'second-password')
  end
  let(:vault) { double(search: [entry_one, entry_two]) }
  let(:cli) do
    described_class.new.tap do |instance|
      instance.instance_variable_set(:@vault, vault)
    end
  end

  before do
    allow(cli).to receive(:prompt).with('Search term').and_return('git')
  end

  describe '#search_credentials' do
    it 'copies the password for the selected result' do
      allow($stdin).to receive(:gets).and_return("2\n")
      allow(cli).to receive(:copy_to_clipboard).with('second-password').and_return(true)

      expect { cli.send(:search_credentials) }
        .to output(/Enter entry number to copy password.*Password copied to clipboard/m).to_stdout
    end

    it 'skips copying when the user presses Enter' do
      allow($stdin).to receive(:gets).and_return("\n")
      expect(cli).not_to receive(:copy_to_clipboard)

      expect { cli.send(:search_credentials) }
        .to output(/Enter entry number to copy password/).to_stdout
    end

    it 're-prompts for an invalid selection' do
      allow($stdin).to receive(:gets).and_return("3\n", "1\n")
      allow(cli).to receive(:copy_to_clipboard).with('first-password').and_return(true)

      expect { cli.send(:search_credentials) }
        .to output(/Invalid selection.*Password copied to clipboard/m).to_stdout
    end

    it 'does not prompt when there are no matching results' do
      allow(vault).to receive(:search).with('git').and_return([])
      expect(cli).not_to receive(:copy_to_clipboard)

      expect { cli.send(:search_credentials) }.to output(/No matching credentials found/).to_stdout
    end
  end
end
