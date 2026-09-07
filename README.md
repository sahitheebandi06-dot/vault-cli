# VaultCLI

A terminal-based password manager built in Ruby. Store, search, and manage credentials behind a master password. All data is encrypted at rest using AES-256-GCM — no plaintext ever touches the filesystem.

## Team

- Sahithee Bandi
- Jaelen Dixon

## Features

### Core
- **Master password authentication** — Set on first use, required to unlock on every subsequent session. Wrong password = denied.
- **Add credentials** — Store a site name, username, and password.
- **Search / retrieve** — Find saved entries by typing part of the site name.
- **Password generator** — Generate cryptographically random passwords with configurable length and character classes.
- **Delete credentials** — Remove a saved entry by site name.

### Stretch
- **Password strength rating** — Entropy-based strength assessment (weak → excellent) shown when adding or generating passwords.
- **Categories** — Tag entries as Social, Work, Finance, etc. and filter by tag.
- **CSV export** — Export all entries to a CSV file with a confirmation prompt.

## Architecture

```
VaultCLI/
├── bin/
│   └── vault_cli          # Executable entry point
├── lib/
│   ├── cli.rb             # Interactive menu loop and user I/O
│   ├── entry.rb           # Single credential record
│   ├── password_generator.rb  # Random password generation + strength rating
│   └── vault.rb           # Encrypted storage engine
├── spec/
│   ├── entry_spec.rb
│   ├── password_generator_spec.rb
│   └── vault_spec.rb
├── Gemfile
└── README.md
```

### Class Responsibilities

| Class | Responsibility |
|---|---|
| `Vault` | Holds all entries. Encrypts/decrypts the data file. Provides add, delete, search, and filter operations. |
| `Entry` | One credential record (site, username, password, optional category). Serializes to/from hashes. |
| `PasswordGenerator` | Builds random passwords from configurable character pools. Rates password strength by entropy. |
| `CLI` | Runs the menu loop, reads user input (with echo suppression for passwords), delegates to the other classes. |

## Encryption Design

We follow the approach used by production password managers:

1. **Key derivation**: The master password is never stored. Instead, it is run through **PBKDF2-HMAC-SHA256** with **600,000 iterations** and a random 32-byte salt to produce a 256-bit symmetric key. This makes brute-force attacks on the master password computationally expensive.

2. **Authenticated encryption**: The derived key encrypts the vault data using **AES-256-GCM**, which provides both confidentiality and integrity. Any tampering with the ciphertext is detected on decryption.

3. **File format**: The vault file is a binary blob: `salt (32 B) || IV (12 B) || auth_tag (16 B) || ciphertext`. A fresh random salt and IV are generated on every save, so the same plaintext produces different ciphertext each time.

4. **Verification**: The test suite explicitly asserts that no plaintext credential or site name appears in the raw vault file.

## Setup

```bash
# Requires Ruby >= 3.0
gem install bundler
bundle install
```

## Usage

```bash
ruby bin/vault_cli
```

On first run, you will be prompted to create a master password. On subsequent runs, enter your master password to unlock the vault.

## Testing

```bash
bundle exec rspec
```

## Development Practices

- **Pair programming**: All core features developed in driver/navigator pairs.
- **Test-driven development**: Tests written alongside implementation (see `spec/`).
- **Meaningful commits**: Each commit addresses a single user story or fix.
- **Code quality**: `frozen_string_literal` pragmas, YARD-style documentation, consistent style.
