# frozen_string_literal: true

require 'io/console'
require_relative 'vault'
require_relative 'entry'
require_relative 'password_generator'

module VaultCLI
  # Interactive terminal interface for the password vault.
  #
  # Drives the main menu loop, handles user input, and delegates to Vault,
  # Entry, and PasswordGenerator. All password prompts suppress terminal echo
  # via IO#getpass so credentials never appear on screen.
  class CLI
    MENU_OPTIONS = <<~MENU
      ╔════════════════════════════════════╗
      ║          VaultCLI — Menu           ║
      ╠════════════════════════════════════╣
      ║  1. Add credential                ║
      ║  2. Search credentials            ║
      ║  3. List all credentials          ║
      ║  4. Delete credential             ║
      ║  5. Generate password             ║
      ║  6. Filter by category            ║
      ║  7. Export to CSV                  ║
      ║  8. Change master password         ║
      ║  9. Quit                          ║
      ╚════════════════════════════════════╝
    MENU

    def initialize(vault_path: nil)
      args = vault_path ? { path: vault_path } : {}
      @vault = Vault.new(**args)
      @master_password = nil
    end

    # Entry point — handles first-run setup or unlock, then runs the menu loop.
    def run
      puts 'Welcome to VaultCLI — your terminal password manager.'
      puts

      if @vault.persisted?
        authenticate
      else
        first_run_setup
      end

      menu_loop
    end

    private

    # ── Authentication ──────────────────────────────────────────────────────

    # Prompt for the master password and unlock an existing vault file.
    def authenticate
      puts 'Vault found. Enter your master password to unlock.'
      3.times do |attempt|
        pw = prompt_secret('Master password')
        begin
          @vault.unlock(pw)
          @master_password = pw
          puts "Vault unlocked. #{@vault.entries.size} credential(s) loaded."
          return
        rescue RuntimeError
          remaining = 2 - attempt
          if remaining.positive?
            puts "Wrong password. #{remaining} attempt(s) remaining."
          else
            abort 'Too many failed attempts. Exiting.'
          end
        end
      end
    end

    # On first launch, prompt to create a master password.
    def first_run_setup
      puts 'No vault found. Let\'s create one.'
      loop do
        pw  = prompt_secret('Choose a master password')
        pw2 = prompt_secret('Confirm master password')

        if pw != pw2
          puts 'Passwords do not match. Try again.'
          next
        end

        if pw.length < 8
          puts 'Master password must be at least 8 characters.'
          next
        end

        @master_password = pw
        @vault.save(@master_password)
        puts 'Vault created and saved.'
        return
      end
    end

    # ── Menu loop ───────────────────────────────────────────────────────────

    def menu_loop
      loop do
        puts
        puts MENU_OPTIONS
        print 'Choose an option: '
        choice = $stdin.gets&.strip

        case choice
        when '1' then add_credential
        when '2' then search_credentials
        when '3' then list_all
        when '4' then delete_credential
        when '5' then generate_password
        when '6' then filter_by_category
        when '7' then export_csv
        when '8' then change_master_password
        when '9' then quit
        else
          puts 'Invalid option. Enter a number 1–9.'
        end
      end
    end

    # ── Menu actions ────────────────────────────────────────────────────────

    def add_credential
      site     = prompt('Site')
      username = prompt('Username')

      puts 'Enter a password or press Enter to generate one.'
      password = prompt_secret('Password (hidden)')

      if password.empty?
        password = PasswordGenerator.generate(length: 20)
        puts "Generated password: #{password}"
      end

      strength = PasswordGenerator.strength(password)
      puts "Password strength: #{strength}"

      puts "Category (#{Entry::VALID_CATEGORIES.join(', ')}) or blank to skip:"
      category = $stdin.gets&.strip
      category = nil if category&.empty?

      entry = Entry.new(site: site, username: username,
                        password: password, category: category)
      @vault.add(entry)
      @vault.save(@master_password)
      puts "Credential for #{site} saved."
    rescue ArgumentError => e
      puts "Error: #{e.message}"
    end

    def search_credentials
      query   = prompt('Search term')
      results = @vault.search(query)

      if results.empty?
        puts 'No matching credentials found.'
      else
        puts "Found #{results.size} result(s):"
        results.each_with_index do |entry, i|
          puts "  #{i + 1}. #{entry}"
          puts "     Password: #{entry.password}"
        end
      end
    end

    def list_all
      if @vault.entries.empty?
        puts 'Vault is empty.'
        return
      end

      puts "All credentials (#{@vault.entries.size}):"
      @vault.entries.each_with_index do |entry, i|
        puts "  #{i + 1}. #{entry}"
      end
    end

    def delete_credential
      site = prompt('Site to delete')
      removed = @vault.delete(site)

      if removed
        @vault.save(@master_password)
        puts "Deleted credential for #{removed.site}."
      else
        puts "No credential found for \"#{site}\"."
      end
    end

    def generate_password
      length = prompt('Password length').to_i
      if length < 1
        puts 'Length must be at least 1.'
        return
      end

      puts 'Include uppercase? (y/n, default y)'
      uppercase = $stdin.gets&.strip&.downcase != 'n'
      puts 'Include lowercase? (y/n, default y)'
      lowercase = $stdin.gets&.strip&.downcase != 'n'
      puts 'Include digits? (y/n, default y)'
      digits = $stdin.gets&.strip&.downcase != 'n'
      puts 'Include symbols? (y/n, default y)'
      symbols = $stdin.gets&.strip&.downcase != 'n'

      pw = PasswordGenerator.generate(length: length, uppercase: uppercase,
                                      lowercase: lowercase, digits: digits,
                                      symbols: symbols)
      strength = PasswordGenerator.strength(pw)
      puts "Generated: #{pw}"
      puts "Strength:  #{strength}"
    rescue ArgumentError => e
      puts "Error: #{e.message}"
    end

    def filter_by_category
      puts "Available categories: #{Entry::VALID_CATEGORIES.join(', ')}"
      cat     = prompt('Category')
      results = @vault.filter_by_category(cat)

      if results.empty?
        puts "No credentials in category \"#{cat}\"."
      else
        puts "Credentials in #{cat} (#{results.size}):"
        results.each_with_index do |entry, i|
          puts "  #{i + 1}. #{entry}"
        end
      end
    end

    def export_csv
      if @vault.entries.empty?
        puts 'Vault is empty. Nothing to export.'
        return
      end

      puts 'WARNING: This will write credentials to an UNENCRYPTED CSV file.'
      print 'Are you sure? (yes to confirm): '
      return unless $stdin.gets&.strip&.downcase == 'yes'

      filename = "vault_export_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv"
      File.write(filename, csv_content)
      puts "Exported #{@vault.entries.size} credential(s) to #{filename}."
    end

    def change_master_password
      current = prompt_secret('Current master password')
      unless current == @master_password
        puts 'Incorrect current password.'
        return
      end

      new_pw  = prompt_secret('New master password')
      confirm = prompt_secret('Confirm new master password')

      if new_pw != confirm
        puts 'Passwords do not match.'
        return
      end

      if new_pw.length < 8
        puts 'New password must be at least 8 characters.'
        return
      end

      @master_password = new_pw
      @vault.save(@master_password)
      puts 'Master password changed and vault re-encrypted.'
    end

    def quit
      puts 'Vault locked. Goodbye.'
      exit 0
    end

    # ── Helpers ──────────────────────────────────────────────────────────────

    def prompt(label)
      print "#{label}: "
      $stdin.gets&.strip || ''
    end

    # Read a line without echoing to the terminal.
    def prompt_secret(label)
      if $stdin.respond_to?(:getpass)
        $stdin.getpass("#{label}: ")
      else
        print "#{label}: "
        $stdin.gets&.strip || ''
      end
    end

    def csv_content
      lines = ["site,username,password,category"]
      @vault.entries.each do |e|
        lines << [e.site, e.username, e.password, e.category].map { |f| csv_escape(f) }.join(',')
      end
      lines.join("\n") + "\n"
    end

    def csv_escape(field)
      return '' if field.nil?

      if field.match?(/[,"\n]/)
        "\"#{field.gsub('"', '""')}\""
      else
        field
      end
    end
  end
end
