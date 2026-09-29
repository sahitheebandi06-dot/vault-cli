# Sprint Planning — Final

## Sprint Goal
Extend vault with additional features, including clipboard copying, TPM support, password expiry notices, and password csv importing.

## Task Breakdown
- Sahithee: Password expiry notices, csv importing
- Jaelen: Clipboard copying, TPM support

## Decisions
- Integrate clipboard functionality using `Clipboard` gem
- Integrate TPM functionality using [tpm2-tools](https://tpm2-tools.readthedocs.io/en/latest/)

## Risks Identified
- TPM support will not always be guaranteed depending on user's environment, so integration must be kept optional
- Time pressure with other coursework. Mitigated by keeping scope tight — core features first, stretch features only if time allowed.
