# Sprint Planning — Mid-Project

## Sprint Goal
Deliver a working encrypted vault with all core CRUD operations and password generation.

## Task Breakdown
- Sahithee: Vault encryption engine, Entry model, CLI interface, tests
- Jaelen: User stories and acceptance criteria (BDD format), backlog grooming

## Decisions
- Ruby chosen since the course uses it and both teammates are learning it.
- AES-256-GCM for encryption after researching how KeePass and Bitwarden handle storage. Instructor warned plaintext = automatic fail.
- PBKDF2 over bcrypt because OpenSSL ships with Ruby stdlib — no extra gem needed.
- RSpec for testing since it's the standard in the Rails ecosystem Ritchey teaches.

## Risks Identified
- Neither of us had used Ruby's OpenSSL bindings before. Mitigated by reading the Ruby docs and writing a test that checks for plaintext leaks.
- Time pressure with other coursework. Mitigated by keeping scope tight — core features first, stretch features only if time allowed.
