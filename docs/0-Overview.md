> **Development Workstation** · **Overview** · [Stack](1-Stack.md) · [Installation](2-Installation.md) · [Terminal](3-Terminal.md) · [Projects](4-Projects.md) · [Editors](5-Editors.md) · [Desktop](6-Desktop.md) · [Troubleshooting](7-Troubleshooting.md) · [Workflows](8-DevWorkflows.md)

---

# Development Workstation

This guide builds a complete, reproducible development environment on Ubuntu using Nix, Home Manager, tmux, Neovim, and Docker. By the end, your workstation is a version-controlled artifact: setting up a new machine is one command, changing a setting is editing one file, and rolling back a mistake is one command.

**What gets installed:**

| Tool | Role |
|---|---|
| Nix + Home Manager | Reproducible global packages and shell config |
| tmux + sessionizer | Persistent workspaces, one keypress per project |
| Neovim + LazyVim | Editor with LSP, formatting, debugging |
| Devenv + Direnv | Per-project isolated tool versions |
| Docker Compose | Databases and services (MariaDB, Redis) |
| VS Code | Parallel editor path |
| WezTerm | Terminal emulator |

**How long it takes:** 20–40 minutes for the automated bootstrap on a fresh machine, plus time reading each document as you configure tools to your preferences.

---

## Why This Approach

Traditional development environment setups break in predictable ways:

**Tool version conflicts between projects.** Project A needs Python 3.11. Project B needs Python 3.9. Without isolation, only one can be "the system Python," and the other requires a workaround that inevitably drifts.

**No rollback when an update breaks something.** When `brew upgrade` or `apt upgrade` changes a tool version, there is no record of what changed and no one-command path back to the previous state. The environment accumulates changes that nobody tracks.

**New machine setup takes a full day.** The process is "install these twelve things, configure each one, copy some dotfiles, debug the parts that didn't transfer." It takes all day and the result is never quite identical to the original.

Each of these problems maps directly to a solution in this stack:

| Problem | Solution |
|---|---|
| Version conflicts between projects | Devenv: per-project isolated tool versions |
| No rollback | Home Manager generations: every change is reversible |
| New machine setup takes a day | Bootstrap script: one command, 20–40 minutes, reproducible result |

> [!important] **The Goal** — By the end of this guide, your workstation is a version-controlled artifact. Setting up a new machine means cloning one repository and running one script. Changing a setting means editing one file and running one command. Breaking something means running one command to roll back.

---

## How the Stack Is Layered

The environment is built in six layers. Each layer owns a specific concern and explicitly does _not_ own everything else. This boundary is the most important thing to understand: when something breaks, the boundary tells you exactly where to look.

| Layer | Owns | Does not own |
|---|---|---|
| **Host OS** | Hardware, kernel, display server | Package management |
| **Nix** | Reproducible packages in `/nix/store` | User config, project tools |
| **Home Manager** | Shell, global CLIs, stable dotfiles | Project-specific tools, secrets |
| **Devenv** | Per-project runtimes, LSPs, formatters | Stateful services, personal aliases |
| **Docker Compose** | Databases, caches, queues | Application code, dev tools |
| **Direnv** | Automatic environment activation on `cd` | Project tools, shell config, secrets |

Document 1 (Stack) explains each layer in depth — what it is, why it exists, and what it does not touch. Reading it before or during installation prevents hours of debugging later.

---

## The Two-Repository Model

Before running anything, you need two GitHub repositories. Understanding why there are two — and why they have different visibility — is the first thing this guide asks you to understand.

**Why two repositories?**

The setup scripts (`scripts/bootstrap.sh`, `scripts/setup-desktop.sh`) must be fetchable with a single `curl` command on a brand-new machine that has no SSH key, no git configuration, and possibly no clipboard. `curl` fetches files over HTTPS anonymously — it cannot access a private repository. So the scripts must live in a **public** repository.

Your personal configuration — `home.nix`, `flake.nix`, `wezterm.lua`, `tmux.conf`, your shell aliases, your git identity — is private. It should not be publicly visible on the internet. So your dotfiles must live in a **private** repository.

| Repository | Visibility | Purpose | Contents |
|---|---|---|---|
| `workstation-scripts` | **Public** | Scripts fetchable by any new machine via `curl`; Nix config templates | `scripts/bootstrap.sh`, `scripts/setup-desktop.sh`, `templates/` |
| `dotfiles` | **Private** | Your personal environment declaration | `flake.nix`, `home.nix`, `wezterm.lua`, `tmux.conf`, `sessionizer`, and all personal config |

**How they work together:**

```
Step 1 — On a new machine, with nothing installed:
  ssh-keygen generates a key locally
  you register the public key on GitHub
  ssh -T git@github.com verifies the key works

Step 2 — SSH key registered:
  wget → workstation-scripts/scripts/bootstrap.sh   (runs the full bootstrap, fully unattended)
  bootstrap installs its own prerequisites (git, curl, zsh, build-essential…)
  bootstrap verifies SSH key → exits with instructions if missing
  bootstrap clones your PRIVATE dotfiles repo via SSH
  hms builds your environment
```

`wget` only ever touches the public repository — it never needs credentials. The private dotfiles repository is only reached after the SSH key is registered, so it stays private throughout.

> [!note] **This guide is a reference implementation.** The scripts and configuration files are complete, working examples that you copy into your own repositories. You do not fork or clone this guide — you create your own `workstation-scripts` and `dotfiles` repositories and populate them from the reference material here. Document 2 (Installation) walks through the exact steps to create both repositories from scratch.

---

## The One Workflow You Will Always Use

Every change to this environment — adding a tool, changing a setting, fixing a broken config — follows the same four-step cycle:

```
1. Edit    → modify the relevant file in ~/dotfiles/
2. Apply   → run the activation command (hms, SUPER+SHIFT+R, prefix r…)
3. Verify  → confirm the change works
4. Commit  → git add, commit, push — make it part of the record
```

Step 4 is never optional. A change that is not committed exists only on this machine. If you set up a second machine, or need to recover from a failure, the uncommitted change is gone.

Document 2 (Installation) covers this workflow in detail with concrete examples after the bootstrap. Document 1 (Stack) explains the distinction between `hms`-managed and user-managed files that determines which "Apply" command to use in each situation.

---

## What Each Document Covers

| Document | What it covers | Read when |
|---|---|---|
| **0 — Overview** (this file) | What you're building and why | Before anything else |
| **1 — Stack** | Why the tools exist, how they fit together | During the bootstrap (20–40 min) |
| **2 — Installation** | From zero to working workstation | Following along step-by-step |
| **3 — Terminal** | WezTerm, tmux, sessionizer, fonts, shell | After bootstrap succeeds |
| **4 — Projects** | Devenv, Docker, git tooling | When starting a new project |
| **5 — Editors** | Neovim + LazyVim, VS Code | Configuring your editor |
| **6 — Desktop** | XFCE4 + XRDP (optional) | Adding a graphical desktop |
| **7 — Troubleshooting** | Per-tool problem/fix | When something breaks |
| **Workflows** | Day-to-day git, PR, and AI-assisted dev workflows | Once the environment is stable |

> [!note] **Part numbering across documents:** Documents 3–5 each contain multiple internal "Parts" that continue sequentially across files. `3-Terminal.md` contains Parts 3–7; `4-Projects.md` contains Parts 8–9; `5-Editors.md` contains Parts 10–11. Cross-references like §8.4 therefore resolve to `4-Projects.md`, not to `8-DevWorkflows.md`.

---

## How to Read This Guide

Different readers need different things. Use this table to calibrate how much of Document 1 to read before starting the bootstrap.

| If you… | Do this |
|---|---|
| Are new to Nix and declarative environments | Read all of Document 1 (Stack) before or during the bootstrap. The 20–40 minute bootstrap window fits it neatly. |
| Use NixOS or Home Manager already | Skim §1.5 (dotfile boundary) and §1.9 (evolution reference table) in Document 1. The rest is review. |
| Are re-installing a second machine from an existing dotfiles repo | Go straight to Document 2 (Installation). Return to Documents 3–5 only if you want to tune the configuration. |
| Are an experienced Linux dev, new to Nix | Read §1.1–1.5 in Document 1 for the mental model, skim §1.6–1.10, then start the bootstrap. |

> [!tip] **When to read each document during the bootstrap**
> Steps 1–2 of Installation take under 5 minutes — use that time to read §1.1–1.3 of Document 1 (Stack). The bootstrap itself (Step 3) takes most of the 20–40 minutes; that window is the right time to read §1.4–1.9 in depth.

---

> [!note] **Where to start**
> Begin with **[Document 1 — Stack](1-Stack.md)**. Read it before or during installation — it explains the "why" behind every decision in Document 2. Then follow **[Document 2 — Installation](2-Installation.md)** step by step.

---
**Next:** [1-Stack.md — Understanding the Stack](1-Stack.md)
