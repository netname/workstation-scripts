# Stack Architecture

The workstation is built in layers. Each layer owns a different kind of state.

| Layer | Owns | Does not own |
|---|---|---|
| Ubuntu | kernel, hardware, system services | project tool versions |
| Nix | reproducible packages | personal config by itself |
| Home Manager | user packages, shell, git, generated config | project-specific runtimes |
| User-managed dotfiles | live app configs such as tmux and WezTerm | package resolution |
| Devenv | project-local tools and language runtimes | databases and durable service state |
| Docker Compose | local stateful services | editor and shell configuration |
| Direnv | environment activation on directory entry | package declarations |
| SOPS + Age | encrypted secrets and decryption keys | tool installation |

The main design goal is replaceability. A machine can be rebuilt because the durable choices live in git, while private keys are backed up deliberately outside the repo.

The main operational rule is: edit, apply, verify, commit. A change that is not committed is not part of the workstation.

## Why This Layering Matters

When something breaks, the owning layer tells you where to look. If Docker cannot connect, inspect Docker Compose and service state. If an LSP is missing, inspect the project environment before changing global packages. If a shell alias is missing everywhere, inspect Home Manager.

The layering also keeps rebuilds boring. The public repo provides machinery, the private dotfiles repo records personal choices, and private keys are backed up outside git.
