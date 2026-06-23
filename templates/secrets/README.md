# Encrypted Secrets

Store only SOPS-encrypted files in this directory after copying the templates
to your private dotfiles repository.

Do not commit plaintext secrets. Create or edit encrypted files with:

```bash
sops secrets/workstation.yaml
```
