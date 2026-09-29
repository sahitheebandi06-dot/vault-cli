# Retrospective — Final

## What went well
- Encryption works correctly — tests confirm no plaintext hits the disk.
- All core features from the proposal are implemented and tested.
- Clean separation between Vault (storage), Entry (data), PasswordGenerator (utility), and CLI (I/O) made it easy to test each piece independently.

## What didn't go well
- Started later than we should have.
- Didn't set up CI — tests run locally but there's no automated pipeline yet.
- Pair programming was not able to occur due to conflicting schedules, outside obligations, and other unforeseen circumstances.
- TPM functionality wasn't fully tested since our test environment is WSL, which is not natively able to access the underlying Window machine's TPM.
- Some sprint goals (csv imports, password expiry notices) were not able to be met in time.

## Lessons Learned
- Start earlier and commit more frequently.
- Set up a GitHub Actions CI workflow so tests run on every push.
- Confirm availability for pair programming sooner.
- Confirm test environment will be able to properly test new functionality sooner, preferably before implementation.
