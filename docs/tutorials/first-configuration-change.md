# First Configuration Change

This tutorial walks through the lifecycle every workstation change should follow: edit, apply, verify, commit.

## Success Criteria

You are done when one small dotfiles change has been applied locally, verified, committed, and pushed.

## What This Tutorial Does Not Do

This tutorial does not redesign your module layout or migrate multiple machines. It teaches the change lifecycle on one workstation.

## 1. Pick a Small Change

Choose a low-risk package or shell setting in your private `dotfiles` repo. For example, add a global CLI package to the Home Manager package list in `modules/cli-tools.nix`.

```bash
cd ~/dotfiles
nvim modules/cli-tools.nix
```

Make one intentional change only. Small changes are easier to verify and recover.

## 2. Apply the Change

For Home Manager-managed files, run:

```bash
hms
```

For user-managed files, reload the owning tool instead:

- WezTerm: press `SUPER+SHIFT+R`
- tmux: press `prefix r`
- sessionizer: run it again
- Neovim config: restart Neovim or reload plugins as appropriate

The boundary is explained in [Nix and Home Manager Boundary](../explanation/nix-home-manager-boundary.md).

## 3. Verify the Result

Run the smallest check that proves the change worked.

```bash
which your-new-tool
your-new-tool --version
```

For visual changes, verify in the application that reads the file.

## 4. Commit and Push

```bash
git status --short
git add modules/cli-tools.nix
git commit -m "feat: add your-new-tool"
git push
```

The commit is part of the workstation. A local-only change will not exist on the next machine.

For task-focused variants, see [Update Workstation Config](../how-to/update-workstation-config.md).
