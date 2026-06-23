# Secrets Model

Secrets are handled with SOPS and Age so encrypted files can live in git while private keys stay outside git.

## What Goes in Git

Commit encrypted SOPS files and SOPS configuration:

- `.sops.yaml`
- encrypted files under `secrets/`
- modules that declare where decrypted secrets should appear

Do not commit plaintext `.env` files, tokens, private keys, or decrypted secret outputs.

## What Stays Outside Git

The Age private key lives at:

```text
~/.config/sops/age/keys.txt
```

Back it up to an offline encrypted location or password manager. Dotfiles can rebuild the workstation, but they cannot recreate this key.

## How New Machines Work

A new machine can clone the encrypted files, but it cannot decrypt them until it has an Age key that matches a recipient in `.sops.yaml`.

Either restore the existing private key or update encrypted files to include the new machine's recipient from a machine that can already decrypt.
