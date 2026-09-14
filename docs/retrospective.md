# Retrospective — Mid-Project

## What went well
- Encryption works correctly — tests confirm no plaintext hits the disk.
- All core features from the proposal are implemented and tested.
- Clean separation between Vault (storage), Entry (data), PasswordGenerator (utility), and CLI (I/O) made it easy to test each piece independently.

## What didn't go well
- Started later than we should have. Most coding happened in the last few days.
- Didn't set up CI — tests run locally but there's no automated pipeline yet.
- Pair programming was mostly asynchronous rather than live sessions.

## What we'll change for the final deliverable
- Start earlier and commit more frequently.
- Set up a GitHub Actions CI workflow so tests run on every push.
- Do at least two live pair programming sessions per week instead of async.
- Tackle the "update password" feature first since Jaelen already drafted the user story for it.
