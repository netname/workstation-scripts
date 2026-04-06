---

## Development Workflows

This guide covers the complete day-to-day development workflow: tmux workspace management, Git fundamentals, the branch/PR/merge loop, keeping branches current, history and recovery operations, releases, and AI-assisted development with Conductor. It is a companion to the **Dev Environment** guide, which covers installation, configuration, and tool setup.

**How to use this guide.** Parts 1–9 are the reference you read to learn. Part 10 contains shell function definitions to add to your shell. Part 11 is a command quick-reference to consult mid-task. Appendix A is the troubleshooting index. Start at Part 3 (Orientation) if you are already comfortable with the tools and want the workflow.

---

### Part 1: The Tmux Workspace Model

tmux is the layer between WezTerm and everything else. One terminal window, unlimited persistent workspaces. This part covers the three-level session/window/pane model, the declarative workspace principle, the standard layouts, and all keybindings you need day to day.

---

#### 1.1 Sessions, Windows, and Panes

Before learning any keybinding, understand the three-level hierarchy tmux uses to organize your work. Every confusion about tmux traces back to not having this model internalized.

```
tmux
├── Session        ← one per project you have open simultaneously
│   ├── Window     ← one per role within that project
│   │   ├── Pane   ← subdivisions of a window for closely related work
│   │   └── Pane
│   └── Window
│       └── Pane
└── Session
    └── Window
        └── Pane
```

**The concrete analogy:**

|Level|Analogy|Example|
|---|---|---|
|Session|A project on your desk|`autoint2`, `mipapelera`, `dotfiles`|
|Window|A role within that project|editor, services, git|
|Pane|A subdivided view for related work|terminal + test output side by side|

**Why this matters.** You can have five projects open simultaneously and switch between them in under two seconds, with the correct tools already running in each one. Nothing is closed. Nothing is lost. You are not managing terminal tabs — you are managing workspaces.

> [!tip] A common beginner mistake is opening multiple WezTerm windows instead of multiple tmux sessions. One WezTerm window is enough. Everything else happens inside tmux.

---

#### 1.2 The Declarative Principle: Recreate, Never Save

tmux-resurrect and tmux-continuum — plugins that save and restore session state — are intentionally excluded from this setup.

**Why.** Saved state goes stale. A session saved two days ago has the wrong working directory, the wrong running processes, and possibly the wrong branch. You spend more time cleaning up the restored state than you saved by not recreating it.

**The alternative principle:** a session is a recipe, not a snapshot. Your sessionizer script (Dev Environment §6.3) defines exactly what a workspace looks like for each project. Running it always produces the same clean result. You recreate workspaces from the sessionizer; you never save them.

> [!important] This is why tmux-resurrect and tmux-continuum are excluded. The sessionizer replaces them with something more reliable: a deterministic script that produces the same workspace every time.

**Practical consequence:** when you close WezTerm, sessions persist in the background (tmux server keeps running). When you reopen WezTerm, you re-attach. If you reboot, sessions are gone — but `Ctrl-f` recreates any of them in under three seconds.

---

#### 1.3 The Three Standard Layouts

The sessionizer creates one of three layouts depending on the project type. These are defined in your sessionizer script (Dev Environment §6.3). The layouts are reproduced here as a reference for reading your workspace.

**Layout A — Development (default for most projects)**

```
┌─────────────────────────────────────────────────────────┐
│ Window 1: editor                                        │
│                                                         │
│  ┌──────────────────────────────┬──────────────────┐    │
│  │                              │                  │    │
│  │   Neovim (main pane)         │  shell / REPL    │    │
│  │                              │                  │    │
│  │                              │                  │    │
│  └──────────────────────────────┴──────────────────┘    │
├─────────────────────────────────────────────────────────┤
│ Window 2: services                                      │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  docker compose logs / devenv up / server output │   │
│  └──────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│ Window 3: git                                           │
│                                                         │
│  ┌──────────────────────────────┬──────────────────┐    │
│  │                              │                  │    │
│  │   lazygit                    │  Gemini CLI      │    │
│  │                              │                  │    │
│  └──────────────────────────────┴──────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

_When to use:_ any project with a running service component (ERPNext, FastAPI, Docker Compose).

**Layout B — Documentation / Writing**

```
┌─────────────────────────────────────────────────────────┐
│ Window 1: write                                         │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │   Neovim (full width)                            │   │
│  └──────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│ Window 2: git                                           │
│                                                         │
│  ┌──────────────────────────────┬──────────────────┐    │
│  │   lazygit                    │  Gemini CLI      │    │
│  └──────────────────────────────┴──────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

_When to use:_ documentation repos, note-taking, any project without a running service.

**Layout C — Exploration / Scratch**

```
┌─────────────────────────────────────────────────────────┐
│ Window 1: scratch                                       │
│                                                         │
│  ┌──────────────────────────────┬──────────────────┐    │
│  │                              │                  │    │
│  │   shell (left)               │  shell (right)   │    │
│  │                              │                  │    │
│  └──────────────────────────────┴──────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

_When to use:_ ad-hoc investigation, one-off scripts, trying something without a project context.

> [!tip] You are not required to use exactly these layouts. The sessionizer script is a user-managed dotfile (Dev Environment §6.1) — edit it to match how you actually work. These layouts are the starting defaults.

---

#### 1.4 Starting and Ending a Day

**Starting:**

1. Open WezTerm. It auto-attaches to the `main` session (configured in `wezterm.lua` — Dev Environment §4.2).
2. Press `Ctrl-f`. The sessionizer picker appears.
3. Fuzzy-type the project name (e.g., `mipap` for `mipapelera`).
4. Press `Enter`. The workspace is created if it does not exist, or re-attached if it is already running.

You are now inside the correct workspace with the correct windows and panes already laid out.

**Ending:**

- `prefix d` — detach from the session. The session keeps running in the background. WezTerm can be closed.
- Or simply close WezTerm. Sessions persist in the tmux server until you reboot.

> [!important] **Never use `prefix &` (kill window) or `exit` to "end your day."** This destroys the session state. Detach instead. The sessions cost essentially no resources while idle.

**What "sessions persist" means in practice:**

```
# Check what is running right now
tmux ls
```

Expected output (example: three projects open):

```
autoint2: 3 windows (created Mon Mar 17 09:14:22 2025)
dotfiles: 2 windows (created Mon Mar 17 08:50:01 2025)
mipapelera: 3 windows (created Mon Mar 17 09:01:55 2025)
```

All three are alive. You switch between them with `Ctrl-f`, never closing any of them.

---

#### 1.5 Switching Between Projects

**Switch to any session:**

```
Ctrl-f
```

The sessionizer picker opens. Fuzzy-type the project name. `Enter` switches to it (or creates it).

**List running sessions without leaving the current one:**

```bash
tmux ls
```

**Kill a session you no longer need:**

```bash
tmux kill-session -t session-name
```

```bash
# Example
tmux kill-session -t dotfiles
```

> [!tip] You rarely need to kill sessions manually. They are lightweight. Kill one only if `tmux ls` is getting cluttered enough to make the sessionizer picker noisy.

**Switch to the previous session (no picker):**

The default binding is `prefix L`. Useful for rapid back-and-forth between exactly two projects.

**Switch between windows inside the current session:**

|Action|Binding|
|---|---|
|Next window|`prefix n`|
|Previous window|`prefix p`|
|Go to window N|`prefix N` (where N is 1–9)|
|Pick from window list|`prefix w`|

---

#### 1.6 Neovim Integration Points

Two integration points connect Neovim and tmux into a single coherent environment. Both are configured in your dotfiles (Dev Environment §5.6 and §6.7) and require no action here — this section explains what they do and what to do when they break.

**vim-tmux-navigator**

`Ctrl-h`, `Ctrl-j`, `Ctrl-k`, `Ctrl-l` move focus between tmux panes and Neovim windows using the same keys regardless of what is currently in focus.

```
# You are in the Neovim pane (left):
Ctrl-l  → moves focus to the shell pane (right)

# You are in the shell pane (right):
Ctrl-h  → moves focus back to Neovim (left)

# You are in Neovim with a vertical split open:
Ctrl-l  → moves between Neovim splits first, then exits to the tmux pane
```

The rule: `Ctrl-h/j/k/l` always mean "move left/down/up/right" — you never need to think about whether you are in Neovim or tmux.

> [!warning] **Symptom:** `Ctrl-h/j/k/l` move within Neovim but not out to tmux panes (or vice versa). **Cause:** vim-tmux-navigator keybindings in `tmux.conf` and in Neovim's config must both be present and matching. One side got out of sync. **Resolution:** Check Dev Environment §5.6 (Neovim side) and Dev Environment §5.9 (tmux side). Reload both configs: `prefix r` for tmux, `:Lazy sync` for Neovim.

**The Gemini pane and `<leader>g`**

The git window (Window 3) has a dedicated Gemini CLI pane. `<leader>g` in Neovim sends the current visual selection to that pane — selected code, error output, or a question typed inline.

> [!warning] **Symptom:** `<leader>g` produces no output, or Neovim reports "pane not found." **Cause:** The Gemini pane was accidentally closed (e.g., `exit` was typed inside it), breaking the pane numbering the keybinding targets. **Resolution:** Kill the session and recreate it via the sessionizer. The sessionizer always rebuilds the layout with the correct pane assignments.
> 
> ```bash
> tmux kill-session -t current-project-name
> # Then press Ctrl-f and select the project again
> ```

---

#### 1.7 Tmux Keybinding Quick Reference

Your prefix key is `C-Space` (configured in `tmux.conf` — Dev Environment §5.9).

**Sessions**

|Action|Binding|
|---|---|
|Open sessionizer picker|`Ctrl-f`|
|Detach from current session|`prefix d`|
|Switch to previous session|`prefix L`|
|List sessions|`prefix s`|
|Kill current session|`prefix X`|

**Windows**

|Action|Binding|
|---|---|
|New window|`prefix c`|
|Next window|`prefix n`|
|Previous window|`prefix p`|
|Go to window N|`prefix 1` … `prefix 9`|
|Rename window|`prefix ,`|
|Close window|`prefix &` (confirm with `y`)|
|List windows (picker)|`prefix w`|

**Panes**

|Action|Binding|
|---|---|
|Split horizontal (pane below)|`prefix -`|
|Split vertical (pane right)|`prefix \|`|
|Move focus (vim-tmux-navigator)|`Ctrl-h/j/k/l`|
|Resize pane|`prefix H/J/K/L` (hold for repeat)|
|Zoom pane (toggle fullscreen)|`prefix z`|
|Close pane|`prefix x` (confirm with `y`)|
|Show pane numbers|`prefix q`|

**Copy mode**

|Action|Binding|
|---|---|
|Enter copy mode|`prefix [`|
|Start selection (visual)|`v`|
|Copy selection|`y`|
|Exit copy mode|`q` or `Escape`|
|Paste|`prefix ]`|

**Reload config**

|Action|Binding|
|---|---|
|Reload `tmux.conf` without restart|`prefix r`|

> [!tip] `prefix z` (zoom) is one of the most useful bindings to internalize. When you need to read output carefully, zoom the relevant pane to full screen. Press `prefix z` again to restore the layout. Nothing is moved or destroyed — the pane simply fills the window temporarily.

> [!important] **tmux is a user-managed dotfile** (Dev Environment §3.4). Changes to keybindings go in `~/.config/tmux/tmux.conf` directly — not in Home Manager. After editing, reload with `prefix r`. There is no need to restart tmux or rebuild a Home Manager generation for tmux config changes.

---

### Part 2: Core Git Concepts

The commands in Parts 3–8 make sense only if the underlying model is clear. This part covers the five concepts every git operation is built from, the standard work loop, and the one non-negotiable rule. Read this once; return to it when something unexpected happens and you need to reason from first principles.

---

#### 2.1 The Local / Remote Model

Every repository exists in two places simultaneously. Understanding this is the prerequisite for understanding every git command.

```
Your machine                        GitHub
─────────────────────               ─────────────────────
Working directory                   Remote repository
      │                                     │
      │  git add                            │
      ▼                                     │
Staging area (index)                        │
      │                                     │
      │  git commit                         │
      ▼                                     │
Local repository  ──── git push ──────────▶ origin/main
      │                                     │
      │  ◀──────── git fetch ───────────────┘
      │            (downloads, does not apply)
      │
      │  git pull = git fetch + git merge (or rebase)
      │  (downloads and applies)
      ▼
Local branch updated
```

**The critical distinction: `fetch` vs. `pull`**

|Command|What it does|When to use it|
|---|---|---|
|`git fetch origin`|Downloads remote changes into `origin/*` refs. Does not touch your working directory or local branches.|Any time you want to see what changed upstream before deciding what to do. Always safe.|
|`git pull`|Fetch + merge (or rebase) in one step. Modifies your current branch.|When you are confident you want to apply upstream changes immediately.|

The habit to build: **fetch first, inspect, then decide.** `git fetch` can never break anything. `git pull` can produce conflicts if you have local commits the remote does not have.

```bash
# Safe pattern: fetch and inspect before applying
git fetch origin
git log HEAD..origin/main --oneline   # what is on remote that I do not have
git log origin/main..HEAD --oneline   # what I have that remote does not
```

---

#### 2.2 The Five Building Blocks

Every git workflow is built from five concepts. Everything else — rebasing, cherry-picking, pull requests — is a combination of these.

**Commit**

A snapshot of the entire repository at a point in time. Not a diff — a snapshot. Each commit has:

- A unique SHA (the ID — e.g., `a3f9c2b`)
- A pointer to its parent commit (forming the chain of history)
- A commit message
- The author and timestamp

```bash
git show a3f9c2b        # inspect any commit by its SHA
git show HEAD           # inspect the most recent commit on the current branch
git show HEAD~1         # inspect the commit before that
```

**Branch**

A movable pointer to a commit. When you make a new commit on a branch, the pointer advances to the new commit. That is all a branch is — a named pointer.

```
main    ──▶ [C1] ──▶ [C2] ──▶ [C3]
                               ▲
                             HEAD
```

After creating `feat/42-add-orders` from `main` and making two commits:

```
main:    [C1] ──▶ [C2] ──▶ [C3]
                              \
feat/42:                       [C4] ──▶ [C5]
                                           ▲
                                         HEAD
```

`main` has not moved. `feat/42` branched off at C3 and has two new commits `main` does not have. The earlier commits (C1–C3) are shared — a branch is a pointer, not a copy.

**Issue**

A numbered work record on GitHub. Issues track what needs to be done and why. The number (`#42`) becomes the link between the work (branch name, commit message, PR) and the reason the work exists. Every branch you create should trace to an issue or a deliberate decision not to create one.

**Pull Request**

A formal proposal to merge one branch into another. Despite the name, you are not pulling anything — you are requesting that the target branch pull your changes. A PR is:

- A diff (what changes)
- A conversation thread (why those changes, review feedback)
- A CI gate (does the code pass automated checks)
- The merge trigger (approval + passing checks → merge)

The `Closes #N` convention in the PR body auto-closes the linked issue when the PR merges. Use it on every PR.

**HEAD**

A pointer to where you are right now. Normally HEAD points to a branch, and the branch points to a commit:

```
HEAD → feat/42-add-orders → [C5]
```

**Detached HEAD state** occurs when HEAD points directly to a commit instead of to a branch. This happens when you run `git checkout <SHA>` or `git checkout <tag>`.

```
HEAD → [C3]      ← detached: no branch pointer
```

> [!warning] **Symptom:** git outputs `You are in 'detached HEAD' state.` **Cause:** You checked out a commit SHA or tag directly rather than a branch. **Resolution:** Any commits you make in this state are not on a branch and will be garbage-collected eventually. If you made no commits: `git switch -` returns to the previous branch. If you made commits you want to keep: `git switch -c new-branch-name` creates a branch at the current position before leaving.

---

#### 2.3 The Standard Loop

Every piece of work follows the same loop. Knowing where you are in the loop at any moment tells you what the next step is.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   1. Create Issue                                               │
│      gh issue create                                            │
│             │                                                   │
│             ▼                                                   │
│   2. Create Branch                                              │
│      git co feat/N-short-description                            │
│             │                                                   │
│             ▼                                                   │
│   3. Make Commits                              ◀─── loop here   │
│      git add / git commit                           until done  │
│             │                                                   │
│             ▼                                                   │
│   4. Open Pull Request                                          │
│      gh pr create --body "Closes #N"                            │
│             │                                                   │
│             ▼                                                   │
│   5. Review + CI                                                │
│      gh run watch / gh pr review                                │
│             │                                                   │
│             ▼                                                   │
│   6. Merge                                                      │
│      gh pr merge --squash                                       │
│             │                                                   │
│             ▼                                                   │
│   7. Issue auto-closed (via "Closes #N")                        │
│      Branch deleted                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**The loop in git graph form:**

```
main:    [C1]──[C2]──────────────────────────[C7: squash of C3–C6]
                  \                          /
feat/42:           [C3]──[C4]──[C5]──[C6]──/
```

After a squash merge:

```
main:    [C1]──[C2]──[C7: feat: add order service (#42)]
```

All of C3–C6 are squashed into one clean commit on `main`. The branch is deleted. Issue #42 is closed.

> [!tip] When you feel disoriented mid-task — "what was I doing, where am I?" — map yourself onto this loop. You are always in one of these seven steps. Identifying which one immediately clarifies what the next action is.

---

#### 2.4 The One Rule

> **Never commit directly to `main`.**

This is the only rule in this guide that has no exceptions.

**Why `main` must stay clean:**

`main` represents the current working, deployable state of the project. If you commit directly to `main`:

- There is no review step. Bugs go straight to production.
- There is no CI gate. Broken code merges undetected.
- Reverting is destructive. You must either revert a commit on `main` (which creates noise in the history) or reset it (which rewrites history everyone else has pulled).
- The history becomes unreadable. There is no way to know which commits belong to which feature or why they were made.

**What the branch + PR model gives you instead:**

- Every change has a reason (the linked issue).
- Every change is reviewed before it touches `main`.
- Every change passes CI before it touches `main`.
- Reverting is clean: you revert or roll back one PR, not individual scattered commits.
- `main` history is always a readable sequence of completed features and fixes.

> [!important] If you accidentally commit to `main` and have **not yet pushed**:
> 
> ```bash
> git reset --soft HEAD~1    # undo the commit, keep changes staged
> git sw -c feat/N-fix-name  # create a branch
> git commit -m "..."        # commit on the branch instead
> ```
> 
> If you have already pushed to `main`, coordinate with your team before taking any action. Do not force-push `main` unilaterally.

**Protecting `main` on GitHub** (one-time repository setting, done in the browser):

Settings → Branches → Add branch protection rule → Branch name pattern: `main` → check:

- Require a pull request before merging
- Require status checks to pass before merging

This makes the rule enforceable at the repository level, not just a convention.

---

### Part 3: Orientation — Starting Every Session

Sixty seconds at the start of every session prevents the most common category of wasted work: commits on the wrong branch, features built on a stale base, duplicate issues for work already in progress. This part defines the four questions to answer and the commands that answer them.

---

#### 3.1 The Four Questions

Before writing a single line of code or running a single command, answer four questions. This takes 60 seconds. Skipping it is the most common source of wasted work: an hour of commits on the wrong branch, a feature built on top of stale `main`, a duplicate issue opened for work already in progress.

```
┌─────────────────────────────────────────────────────┐
│  The Four Questions                                 │
│                                                     │
│  1. Where am I?                                     │
│     Which branch? Which repo? Is it clean?          │
│                                                     │
│  2. What changed upstream?                          │
│     Did main move while I was away?                 │
│                                                     │
│  3. What is in progress?                            │
│     Do I have stashed work? An open PR?             │
│     A branch with commits not yet pushed?           │
│                                                     │
│  4. What is next?                                   │
│     Which issue am I working on today?              │
│     Is the issue already open, or do I create one?  │
└─────────────────────────────────────────────────────┘
```

The commands in §3.2 answer all four questions in one pass. Run them in order at the start of every session. After a few weeks, reading the output becomes instant.

---

#### 3.2 Reading the State

Run these commands in sequence. Each one answers a specific question and implies a specific action if the output is not what you expect.

---

**`repo-status` — the single-command summary**

`repo-status` is a custom shell function (complete definition in Part 10, §10.1) that consolidates five separate status commands into one. It shows: current branch, ahead/behind counts versus `origin/main`, staged file count, unstaged file count, stash count, and open PRs assigned to you.

```bash
repo-status
```

Example output:

```
branch   feat/42-add-orders
origin   ↑2 ↓0
staged   0 files
unstaged 1 file
stashes  1
prs      1 open (assigned to you)
```

How to read each field:

|Field|Value|Meaning|Action|
|---|---|---|---|
|`branch`|`feat/42-add-orders`|You are on a feature branch|Correct if this is the work you intend to do|
|`branch`|`main`|You are on main|Create or switch to a feature branch before working|
|`origin ↑2 ↓0`|2 ahead, 0 behind|You have 2 local commits not yet pushed|Push when ready, or open a PR|
|`origin ↑0 ↓3`|0 ahead, 3 behind|Remote has 3 commits you do not have|`git pull` before starting work|
|`origin ↑2 ↓3`|2 ahead, 3 behind|Diverged|Rebase before pushing (§5.3)|
|`staged`|`0 files`|Nothing staged|Normal start-of-session state|
|`staged`|`2 files`|Files staged but not committed|You left work mid-commit last session — finish the commit or unstage|
|`unstaged`|`1 file`|Modified file not staged|Inspect with `git diff`, decide whether to stage or stash|
|`stashes`|`1`|One stash entry waiting|Inspect with `git stash list` before starting new work|
|`prs`|`1 open`|A PR is waiting for action|Check CI status and review feedback before starting new work|

> [!tip] If `repo-status` shows anything other than a clean feature branch with no stashes and no staged/unstaged files, resolve the existing state before starting new work. Starting new work on top of unresolved state is how sessions compound into confusion.

---

**`git branch -vv` — branch tracking relationships**

```bash
git branch -vv
```

Example output:

```
* feat/42-add-orders  a3f9c2b [origin/feat/42-add-orders: ahead 2] feat: add order model
  main                d1e8a3f [origin/main] chore: update dependencies
```

How to read it:

- `*` marks the current branch.
- `[origin/feat/42-add-orders: ahead 2]` means your local branch is tracking a remote branch and is 2 commits ahead of it.
- A branch with no `[...]` annotation has no remote tracking branch set — it has never been pushed.
- `[origin/main: behind 3]` on your feature branch means `main` has moved and your branch needs rebasing before you open a PR.

> [!warning] **Symptom:** A branch shows no tracking annotation at all. **Cause:** The branch was created locally and never pushed. **Resolution:** `git push -u origin branch-name` sets the upstream and pushes in one step. After this, `git branch -vv` will show the tracking relationship.

---

**`git lg` — recent commit history**

`git lg` is an alias for a formatted log (configured in Dev Environment §7.2). It shows a compact, graph-decorated history.

```bash
git lg
```

Example output:

```
* a3f9c2b (HEAD -> feat/42-add-orders, origin/feat/42-add-orders) feat: add order model
* 7b2d1e4 feat: add orders table migration
* d1e8a3f (origin/main, main) chore: update dependencies
* 9c3f8a1 fix: correct invoice total calculation (#38)
* 4e7b2d9 feat: add supplier sync endpoint (#35)
```

What to look for:

- Where is `HEAD`? Where is `origin/main`? The distance between them is your divergence.
- Are there any `wip:` commits? Those are unfinished — do not open a PR until they are cleaned up or amended.
- Does the branch history look like what you expect, or did something unexpected land?

---

**`git st` — working tree status**

`git st` is an alias for `git status --short` (configured in Dev Environment §7.2). It shows staged and unstaged changes in a compact format.

```bash
git st
```

Example output (clean):

```
(no output)
```

Example output (work in progress):

```
M  app/services/orders.py     ← staged modification (green M)
 M app/models/invoice.py      ← unstaged modification (red M)
?? app/utils/temp_debug.py    ← untracked file
```

|Symbol|Position|Meaning|
|---|---|---|
|`M`|Left column (green)|Staged modification|
|`M`|Right column (red)|Unstaged modification|
|`A`|Left column|Staged new file|
|`D`|Either column|Deletion (staged or unstaged)|
|`??`|Both columns|Untracked file (git does not know about it)|

> [!tip] An untracked file (`??`) that appears repeatedly is a signal to add it to `.gitignore`. If it belongs in the repo, stage and commit it. If it is a tool artifact, ignore it. Do not leave `??` files sitting indefinitely — they create noise in every subsequent `git st` output.

---

**`git stash list` — parked work**

```bash
git stash list
```

Example output:

```
stash@{0}: On feat/42-add-orders: WIP order validation logic
stash@{1}: On main: temp debug patch
```

If this list is non-empty, you have parked work from a previous session. Before starting new work:

1. Identify which stash entries are still relevant.
2. Apply and complete any that are (`git stash apply stash@{0}`).
3. Drop any that are no longer needed (`git stash drop stash@{1}`).

A stash list that grows unchecked becomes a liability. Entries older than a few days are usually stale.

> [!warning] **Symptom:** `git stash pop` produces conflict markers in your files. **Cause:** The stash was made on a different base commit than your current state. The stash content and your current working tree have overlapping changes. **Resolution:** Resolve the conflict markers manually (same process as rebase conflicts — §5.5), then `git stash drop stash@{0}` to remove the now-applied entry. Do not run `git stash pop` again — the entry is already applied, just conflicted.

---

**`gh pr status` — pull request state**

```bash
gh pr status
```

Example output:

```
Relevant pull requests in owner/repo

Current branch
  #42  feat: add order service  [feat/42-add-orders]
    - Checks passing
    - Review required

Created by you
  #42  feat: add order service  [feat/42-add-orders]

Requesting a review from you
  (none)
```

What each section means:

|Section|What to do|
|---|---|
|**Current branch** shows a PR with failing checks|Fix the issue before writing new code — the PR is blocking|
|**Current branch** shows "Review required"|A reviewer has been assigned; you may continue other work while waiting|
|**Current branch** shows "Changes requested"|Address the feedback before any new feature work|
|**Requesting a review from you** is non-empty|Review that PR before starting your own new work — unreviewed PRs are a team bottleneck|
|No output at all|You are not inside a git repository, or the repo has no GitHub remote|

> [!warning] **Symptom:** `gh pr status` outputs `no pull requests match your search` or nothing at all. **Cause 1:** You are not inside a directory that is a git repository. Run `pwd` and confirm you are in the right project. **Cause 2:** The repository has no GitHub remote configured. Run `git remote -v` to confirm. **Cause 3:** Your `gh` authentication has expired. Run `gh auth status` to check; `gh auth login` to re-authenticate.

---

**The complete orientation sequence**

In practice, run all six commands in order at the start of every session:

```bash
repo-status       # overall summary
git branch -vv    # tracking relationships
git lg            # recent history
git st            # working tree cleanliness
git stash list    # parked work
gh pr status      # PR state
```

After a few sessions this takes under 30 seconds and answers all four questions from §3.1 before you write a single line of code.

---

### Part 4: Workflow — Starting New Work

Every piece of work follows the same sequence: issue → branch → commits → PR. This part covers each step in detail: what makes a good issue, how to branch correctly, how to write commits that reviewers can evaluate, how to stage selectively, and how pre-commit hooks fit into the loop.

---

#### 4.1 Creating an Issue First

Every piece of work starts with an issue. The issue is the reason the work exists. Without it, a branch is a change with no documented motivation, and six months later no one — including you — knows why a commit was made.

**When to create an issue:**

|Situation|Action|
|---|---|
|Work takes more than 30 minutes|Always create an issue|
|Other team members need visibility|Always create an issue|
|The change affects behavior others depend on|Always create an issue|
|Tiny fix, solo project, traceability not needed|Go straight to a branch — skip the issue|

**Creating an issue from the terminal:**

```bash
gh issue create --title "Add order validation service" --assignee @me --label bug
```

For features, use `--label enhancement`. For maintenance, use `--label chore`. Labels must already exist in the repository; create them in the browser under Issues → Labels if they do not.

Expected output:

```
Creating issue in owner/repo

https://github.com/owner/repo/issues/42
```

Note the issue number. It becomes part of every artifact that follows: the branch name, the commit messages, and the PR body.

**Creating an issue interactively** (when you want to write a longer description):

```bash
gh issue create
```

gh will prompt for title, body, assignees, and labels one at a time. The body opens in your `$EDITOR` (Neovim, configured in Dev Environment §7.3).

**Viewing open issues assigned to you:**

```bash
gh issue list --assignee @me
```

Example output:

```
Showing 2 of 2 issues in owner/repo that match your search

#42  Add order validation service    about 2 minutes ago
#38  Fix invoice total on credit notes   3 days ago
```

> [!tip] Before creating a new issue, run `gh issue list` to confirm the work does not already exist. Duplicate issues create duplicate branches and duplicate PRs — wasted effort that only becomes visible at merge time.

---

#### 4.2 Creating a Branch

A branch is always created from an up-to-date `main`. Never branch from a stale `main` — you will immediately be behind and will need to rebase before your PR can merge.

**The two-step branch creation:**

```bash
# Step 1: return to main and pull the latest
git sw main && git pull
```

Expected output:

```
Switched to branch 'main'
Your branch is up to date with 'origin/main'.
Already up to date.
```

Or, if `main` has new commits:

```
Switched to branch 'main'
Updating d1e8a3f..9c3f8a1
Fast-forward
 app/models/invoice.py | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)
```

```bash
# Step 2: create and switch to the feature branch
git co feat/42-add-order-validation
```

Expected output:

```
Switched to a new branch 'feat/42-add-order-validation'
```

> [!important] `git co` is an alias for `git switch -C` (configured in Dev Environment §7.2). It creates the branch and switches to it in one step. If the branch already exists, it resets it to the current HEAD — which is the correct behavior when branching from a freshly-pulled `main`. Use `git switch` (without `-C`) if you want to switch to an existing branch without resetting it.

**Branch naming convention:**

```
type/N-short-description
```

|Component|Rule|Example|
|---|---|---|
|`type`|Same types as Conventional Commits: `feat`, `fix`, `chore`, `docs`, `refactor`|`feat`|
|`N`|The issue number|`42`|
|`short-description`|Lowercase, hyphen-separated, 2–5 words|`add-order-validation`|

Full examples:

```
feat/42-add-order-validation
fix/38-invoice-total-credit-notes
chore/51-update-python-dependencies
docs/17-api-authentication-guide
refactor/29-extract-cfdi-parser
```

**Why the issue number in the branch name matters:**

- `git branch -vv` immediately tells you which issue each branch belongs to.
- `gh issue list` and branch names cross-reference without needing to open any PR or commit.
- When you come back to a branch after a week away, the number is the fastest path back to context: `gh issue view 42`.

> [!warning] **Symptom:** You created a branch but forgot to pull `main` first. `git branch -vv` shows your branch is already behind `origin/main`. **Cause:** `main` had commits you did not have when you branched. **Resolution:** Rebase immediately, before making any commits on the branch. The earlier you rebase, the cheaper it is.
> 
> ```bash
> git fetch origin
> git rebase origin/main
> ```

---

#### 4.3 Making Good Commits

A commit is a unit of reviewable work. The goal is that a reviewer — or your future self — can read a single commit and understand what changed, why it changed, and whether it is correct, without needing context from adjacent commits.

**Conventional Commits format:**

```
type(scope): description

optional body

optional footer
```

The first line is the subject. It must be under 72 characters. The body and footer are optional but valuable for non-obvious changes.

**The types:**

|Type|When to use it|Example subject|
|---|---|---|
|`feat`|New behavior visible to users or callers|`feat(orders): add validation service`|
|`fix`|Corrects a bug — something was broken and now it is not|`fix(invoices): correct total on credit notes`|
|`chore`|Maintenance with no behavior change|`chore(deps): update httpx to 0.27`|
|`docs`|Documentation only — no code change|`docs(api): document authentication endpoints`|
|`refactor`|Restructures code without changing behavior|`refactor(cfdi): extract parser into own module`|
|`test`|Adds or corrects tests, no production code change|`test(orders): add unit tests for validation edge cases`|

**Scope** is the module, component, or area affected. It is optional but recommended for larger projects where the subject line alone may not provide enough context. Use lowercase, consistent names: `orders`, `invoices`, `cfdi`, `auth`, `deps`.

**Writing a good commit subject:**

```
# Good — specific, imperative mood, under 72 chars
feat(orders): add validation service for CFDI line items

# Good — clear fix with scope
fix(invoices): correct subtotal when credit note has zero-rated items

# Bad — vague
fix: stuff

# Bad — past tense (git log reads as a changelog, imperative reads better)
feat(orders): added validation service

# Bad — describes what the code does, not what the commit accomplishes
refactor(cfdi): changed the way parsing works
```

**Writing a commit body** (when the subject is not enough):

```bash
git commit
```

This opens Neovim (configured as `$EDITOR` in Dev Environment §7.3). Write the subject on the first line, leave a blank line, then write the body.

```
feat(orders): add validation service for CFDI line items

Validates that each line item has a valid SAT product code and that
unit prices match the supplier catalog before allowing the order to
proceed to invoice generation.

Required by SAT CFDI 4.0 compliance rules effective January 2024.
Closes #42
```

The body answers: _why_ this change was made, and any context a reviewer needs that is not obvious from the diff.

**Commit granularity:**

One logical change per commit. "Logical" means: a reviewer can understand and evaluate the commit in isolation, without needing to read adjacent commits for context.

```
# Good granularity — three commits, each independently understandable
feat(orders): add Order model and migration
feat(orders): add order validation service
feat(orders): add POST /orders endpoint

# Bad granularity — one commit doing three things
feat(orders): add model, validation, and endpoint
```

```
# Also bad — too granular, noise in the history
feat(orders): add Order class
feat(orders): add id field to Order
feat(orders): add created_at field to Order
feat(orders): add status field to Order
```

The test: could you revert this commit alone and have the codebase still make sense? If yes, the granularity is about right.

> [!tip] If you find yourself writing "and" in a commit subject — `feat: add validation and update endpoint` — that is a signal the commit should be split into two. Use selective staging (§4.4) to split the changes.

**WIP commits:**

For longer interruptions where you need to save state but the work is not complete:

```bash
git commit -m "wip: order validation — service skeleton done, tests pending"
```

The `wip:` prefix is a signal to yourself and reviewers that this commit is not complete. Before opening a PR, clean up `wip:` commits by amending or squashing them:

```bash
# Squash the last 3 commits into one before opening the PR
git rebase -i HEAD~3
```

In the interactive rebase editor, change `pick` to `squash` (or `s`) on the commits you want to fold into the one above them.

---

#### 4.4 Selective Staging

Selective staging lets you commit part of your changes while leaving the rest unstaged. This is how you maintain good commit granularity even when you made several unrelated changes in one editing session.

**Two tools for selective staging. Use whichever fits the situation:**

|Tool|Best for|
|---|---|
|`git add --patch`|Quick staging of a single file with a few hunks|
|lazygit hunk/line staging|Complex selections across multiple files|

---

**`git add --patch` — command-line hunk staging**

```bash
git add --patch app/services/orders.py
```

git splits the file's changes into hunks and presents each one:

```diff
@@ -45,6 +45,12 @@ class OrderService:
     def validate(self, order: Order) -> bool:
+        if not order.line_items:
+            raise ValidationError("Order must have at least one line item")
+        for item in order.line_items:
+            if not item.sat_code:
+                raise ValidationError(f"Line item {item.id} missing SAT code")
+        return True

Stage this hunk [y,n,q,a,d,s,e,?]?
```

The prompt options:

|Key|Action|
|---|---|
|`y`|Stage this hunk|
|`n`|Skip this hunk (leave unstaged)|
|`s`|Split this hunk into smaller hunks (if git can split it further)|
|`e`|Edit the hunk manually — opens the diff in your editor for precise line-level control|
|`a`|Stage this hunk and all remaining hunks in the file|
|`d`|Skip this hunk and all remaining hunks in the file|
|`q`|Quit — stop staging, leave remaining hunks unstaged|
|`?`|Show help|

After staging your selected hunks, verify what is staged versus what is not:

```bash
git diff --staged    # shows what will be committed
git diff             # shows what is still unstaged
```

---

**lazygit — interactive hunk and line staging**

Open lazygit from the git window of your tmux workspace:

```bash
lazygit
```

**File-level staging:**

- Navigate to the Files panel (left side) with `h/l` or the number keys.
- `space` on a file toggles the entire file staged/unstaged.

**Hunk-level staging:**

- With a file highlighted, press `Enter` to open the diff view for that file.
- The diff is split into hunks separated by `@@` markers.
- Navigate between hunks with `]` and `[`.
- `space` on a hunk stages or unstages that hunk.

**Line-level staging:**

- Inside the diff view, press `v` to enter visual selection mode.
- Use `j/k` to extend the selection line by line.
- `space` stages the selected lines.

This is the most precise staging available — individual lines rather than whole hunks.

```
┌─────────────────────────────────────────────────────────┐
│ Files          │ Diff                                   │
│                │                                        │
│ M orders.py    │ @@ -45,6 +45,12 @@                    │
│ M invoices.py  │  def validate(self, order):            │
│                │ +    if not order.line_items:          │
│                │ +        raise ValidationError(...)    │  ← staged (green)
│                │ +    for item in order.line_items:     │
│                │ +        if not item.sat_code:         │  ← unstaged (red)
│                │ +            raise ValidationError()   │  ← unstaged (red)
│                │ +    return True                       │
└─────────────────────────────────────────────────────────┘
```

> [!tip] Use `git add --patch` when you have one file and a few obvious hunks to split. Switch to lazygit when you have multiple files with interleaved changes — the visual panel makes it much easier to track what is staged versus unstaged across the whole working tree simultaneously.

---

#### 4.5 Pre-commit Hooks

Pre-commit hooks run automatically every time you run `git commit`. They enforce code quality standards before the commit is recorded. Your project uses either `devenv.nix` git-hooks or `.pre-commit-config.yaml` — not both (Dev Environment §9.8).

**What runs on commit:**

Typical hooks for a Python/FastAPI project:

|Hook|What it does|
|---|---|
|`ruff-format`|Formats Python files in place|
|`ruff`|Lints Python files, reports errors|
|`trailing-whitespace`|Removes trailing whitespace|
|`end-of-file-fixer`|Ensures files end with a newline|
|`check-yaml`|Validates YAML syntax|
|`check-merge-conflict`|Blocks commits containing conflict markers|

**The critical behavioral difference: formatters vs. linters**

This surprises nearly every developer the first time it happens. Understanding it prevents frustration.

_Formatters_ (e.g., `ruff-format`) modify files in place and then abort the commit. The file is fixed on disk, but the commit did not happen — because the hook ran against the staged version, not the newly formatted version. You must stage the formatted file and commit again.

```bash
# First attempt
git commit -m "feat(orders): add validation service"
```

```
ruff-format..............................................................Failed
- hook id: ruff-format
- files were modified by this hook

app/services/orders.py reformatted
```

The commit was aborted. `orders.py` is now correctly formatted on disk, but the staged version is still the old unformatted version.

```bash
# Stage the formatted version
git add app/services/orders.py

# Second attempt — now succeeds
git commit -m "feat(orders): add validation service"
```

```
ruff-format..............................................................Passed
ruff.....................................................................Passed
trailing-whitespace......................................................Passed
[feat/42-add-order-validation a3f9c2b] feat(orders): add validation service
 1 file changed, 12 insertions(+)
```

_Linters_ (e.g., `ruff` in lint mode) report errors and abort without modifying any files. You must fix the reported errors yourself, stage the fixed file, then commit.

```bash
git commit -m "feat(orders): add validation service"
```

```
ruff.....................................................................Failed
- hook id: ruff
- exit code: 1

app/services/orders.py:52:5: F841 Local variable `result` is assigned to but never used
```

The commit was aborted. Nothing was changed on disk. Open the file, fix line 52, stage the fix, and commit again.

```bash
# Fix the error in Neovim, then:
git add app/services/orders.py
git commit -m "feat(orders): add validation service"
```

**Reading hook failure output:**

Every hook failure follows the same structure:

```
hook-name...............................................................Failed
- hook id: hook-name
- exit code: N          ← non-zero means failure
- files were modified by this hook   ← present for formatters only

[file path and error detail]
```

The file path and error detail tell you exactly what to fix. Read them before taking any action.

**The emergency escape hatch:**

```bash
git commit --no-verify -m "feat(orders): wip — bypassing hooks for emergency deploy"
```

`--no-verify` skips all hooks. This exists for genuine emergencies: a production incident requires an immediate hotfix and a hook is misbehaving.

> [!warning] Using `--no-verify` carries an obligation. The commit that bypasses the hooks must be followed immediately — in the next commit, not "later" — by a commit that fixes whatever the hook would have caught. If you use `--no-verify`, add a `# TODO: fix hook issue` comment in the code at the bypass site so the obligation is visible in review.

> [!important] **Pre-commit hooks must be installed before Conductor runs** (Part 9, §9.7). If `pre-commit install` was not run in the repository (or `just setup` was not run — which includes it), Conductor's autonomous commits bypass all quality hooks silently. Verify hooks are installed before starting any Conductor track:
> 
> ```bash
> cat .git/hooks/pre-commit   # should exist and be non-empty
> ```
> 
> If the file does not exist or is empty:
> 
> ```bash
> pre-commit install   # or: just setup
> ```

---

### Part 5: Workflow — Keeping a Branch Current

`main` keeps moving while you work. Other PRs merge, dependencies update, bug fixes land. This part covers when and how to bring those changes into your branch, the three scenarios that require different approaches, and how to resolve conflicts when they occur.

---

#### 5.1 Why Branches Diverge

While you work on your feature branch, `main` keeps moving. Other PRs merge. Dependencies update. Bug fixes land. Your branch was created from a specific commit on `main` — every commit that lands on `main` after that point is a commit your branch does not have.

```
Day 1: you create feat/42 from main

main:    [C1]──[C2]
                 \
feat/42:          [C3]──[C4]   ← your work


Day 3: two PRs merged to main while you worked

main:    [C1]──[C2]──[C5]──[C6]   ← main moved
                 \
feat/42:          [C3]──[C4]       ← your branch has not
```

This divergence is normal and expected. The problem is when you ignore it too long:

- Conflicts accumulate. Each day you wait, the probability of a conflict increases and the complexity of resolving it grows.
- CI runs against a stale base. A PR that passes CI on a branch diverged from `main` by two weeks may fail immediately after merging because the combined state was never tested.
- Reviews are harder. Reviewers cannot tell which changes are yours and which are artifacts of a stale merge base.

**The rule:** sync your branch before opening a PR, and any time `git branch -vv` or `repo-status` shows your branch is behind `origin/main`.

---

#### 5.2 Scenario A — Update Local Main

**When to use this:** at the start of every session (Part 3 orientation), or any time you need `main` to reflect the current remote state before branching or comparing.

This scenario does not touch your feature branch. It only updates your local `main` to match `origin/main`.

```bash
git sw main && git pull
```

Expected output when `main` has new commits:

```
Switched to branch 'main'
Your branch is behind 'origin/main' by 3 commits, and can be fast-forwarded.
Updating d1e8a3f..9c3f8a1
Fast-forward
 app/models/invoice.py     |  4 ++--
 app/services/cfdi.py      | 12 ++++++++++++
 requirements.txt          |  2 +-
 3 files changed, 14 insertions(+), 3 deletions(-)
```

Expected output when `main` is already current:

```
Switched to branch 'main'
Already up to date.
```

After updating `main`, switch back to your feature branch:

```bash
git sw feat/42-add-order-validation
```

> [!tip] This scenario alone — updating local `main` — does not sync your feature branch. Your branch still diverges from the updated `main`. To bring those new `main` commits into your feature branch, continue to Scenario B.

---

#### 5.3 Scenario B — Rebase Feature Branch onto Main (Unshared Branch)

**When to use this:** your feature branch has not been shared with anyone else (no teammate has pulled it, Conductor is not active on it), and you want to bring new `main` commits into your branch.

Rebasing replays your commits on top of the current `main`, producing a linear history as if you had branched from `main` today.

```
Before rebase:

main:    [C1]──[C2]──[C5]──[C6]
                 \
feat/42:          [C3]──[C4]


After rebase:

main:    [C1]──[C2]──[C5]──[C6]
                               \
feat/42:                        [C3']──[C4']
```

`C3'` and `C4'` are your original commits, replayed onto the new base. The content is the same; the parent pointer (and therefore the SHA) is different.

**Step-by-step:**

```bash
# Step 1: fetch the latest remote state without applying anything
git fetch origin
```

Expected output:

```
From https://github.com/owner/repo
   d1e8a3f..9c3f8a1  main -> origin/main
```

```bash
# Step 2: rebase your branch onto the updated origin/main
git rebase origin/main
```

Expected output (no conflicts):

```
Successfully rebased and updated refs/heads/feat/42-add-order-validation.
```

```bash
# Step 3: force-push the rebased branch to update the remote
git pushf
```

`git pushf` is an alias for `git push --force-with-lease --force-if-includes` (configured in Dev Environment §7.2).

Expected output:

```
Enumerating objects: 7, done.
Counting objects: 100% (7/7), done.
Delta compression using up to 8 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 512 bytes | 512.00 KiB/s, done.
Total 4 (delta 2), reused 0 (delta 0), pack-reused 0
To https://github.com/owner/repo
 + a3f9c2b...7d4e1f8 feat/42-add-order-validation -> feat/42-add-order-validation (forced update)
```

**Why `--force-with-lease` and not `--force`:**

`--force` overwrites the remote branch unconditionally. If a teammate pushed a commit to your branch since your last fetch — unlikely on a solo branch, but possible — `--force` silently destroys their commit.

`--force-with-lease` checks that the remote branch is in the state you last fetched. If someone else pushed since then, the lease fails and the push is rejected, giving you a chance to inspect before overwriting.

```
# What a failed lease looks like
error: failed to push some refs to 'https://github.com/owner/repo'
hint: Updates were rejected because the remote contains work that you do
hint: not have locally.
```

If this happens: `git fetch origin`, inspect what arrived with `git log origin/feat/42..HEAD`, then decide whether to rebase again or coordinate with whoever pushed.

**Why `--force-if-includes`:**

If you ran `git fetch` (which updates your remote-tracking refs) but did not incorporate those changes into your branch, `--force-with-lease` can be bypassed — the lease check passes because the remote ref is already in your reflog. `--force-if-includes` adds a second check: it verifies that the remote-tracking ref is actually reachable in your branch's history before allowing the force push.

The `git pushf` alias combines both flags so you never have to think about this distinction.

> [!warning] **Never force-push `main`.** `git pushf` is only for feature branches you own. If you accidentally run it on `main`, it will be rejected if branch protection is enabled (which it should be — Dev Environment §2.4). If branch protection is not enabled, a force-push to `main` rewrites shared history and requires every teammate to re-sync.

---

#### 5.4 Scenario C — Remote Branch Has New Commits (Shared Branch or Conductor Active)

**When to use this:** the remote copy of your feature branch has commits your local copy does not have. This happens when:

- A teammate pushed commits to your branch directly.
- Conductor made commits autonomously and pushed them.
- You pushed from a different machine.

In these cases, use `git pull --rebase` rather than a plain rebase, because the divergence is between your local branch and its own remote tracking branch — not between your branch and `main`.

```bash
git pull --rebase
```

Expected output (no conflicts):

```
Successfully rebased and updated refs/heads/feat/42-add-order-validation.
```

**Why merge instead of rebase when Conductor is active:**

Conductor attaches git notes to the commit SHAs it creates as checkpoint verification records. Rebasing rewrites SHAs. When the SHAs change, the git notes become orphaned — they still exist in the repository but are no longer attached to any commit in the branch history. The checkpoint trail becomes unreadable.

When Conductor is active on a branch, sync with `main` using merge:

```bash
git fetch origin
git merge origin/main
```

This preserves all existing SHAs and keeps Conductor's git notes attached to the correct commits.

> [!important] The rebase-vs-merge decision for keeping a branch current:
> 
> |Situation|Command|Why|
> |---|---|---|
> |Solo branch, not yet shared|`git rebase origin/main`|Clean linear history|
> |Shared branch, teammate pushed|`git pull --rebase`|Incorporate remote commits before pushing|
> |Conductor is active on the branch|`git merge origin/main`|Preserves commit SHAs that Conductor's git notes reference|

---

#### 5.5 Conflict Resolution

A conflict occurs when the same lines were changed in two places that are being merged — your commits and the commits being rebased onto. Git cannot decide which version is correct and marks the file for you to resolve manually.

**What a conflict looks like in the file:**

```python
def calculate_total(order):
<<<<<<< HEAD
    # origin/main version: added tax calculation
    return sum(item.price for item in order.line_items) * (1 + order.tax_rate)
=======
    # your version: added discount logic
    subtotal = sum(item.price * item.quantity for item in order.line_items)
    return subtotal - order.discount
>>>>>>> feat/42-add-order-validation
```

|Marker|Meaning|
|---|---|
|`<<<<<<< HEAD`|Start of the incoming change — during a rebase, this is the commit from `origin/main` being applied as the new base|
|`=======`|Separator between the two versions|
|`>>>>>>> branch-name`|Your original commit being replayed onto the new base|

> [!tip] Rebase conflict markers can feel counterintuitive: `HEAD` refers to the _incoming_ base commit (from `origin/main`), not your work. Your changes appear in the `>>>>>>> branch-name` section. If you remember "HEAD = what I'm rebasing onto, branch-name = my commit being replayed", the sections make sense.

**The resolution process:**

```bash
# Step 1: identify all conflicted files
git status
```

```
You are currently rebasing branch 'feat/42-add-order-validation' on '9c3f8a1'.
  (fix conflicts and then run "git rebase --continue")
  (use "git rebase --skip" to skip this patch)
  (use "git rebase --abort" to check out the original branch)

Unmerged paths:
  (use "git restore --staged <file>..." to unstage)
  (use "git add <file>..." to mark resolution)
        both modified:   app/services/orders.py
```

```bash
# Step 2: open the conflicted file and resolve it
# Edit the file to the desired final state — remove all three marker lines,
# keep whatever combination of both versions is correct
```

The resolved version of the example above:

```python
def calculate_total(order):
    # combined: quantity, discount, and tax
    subtotal = sum(item.price * item.quantity for item in order.line_items)
    discounted = subtotal - order.discount
    return discounted * (1 + order.tax_rate)
```

```bash
# Step 3: mark the file resolved
git add app/services/orders.py

# Step 4: continue the rebase
git rebase --continue
```

git opens your editor to confirm or edit the commit message for the replayed commit. Save and close to proceed. If there are more commits in the rebase with conflicts, the process repeats for each one.

Expected output after all conflicts resolved:

```
Successfully rebased and updated refs/heads/feat/42-add-order-validation.
```

**If you get stuck:**

```bash
git rebase --abort
```

This returns the branch to exactly its pre-rebase state, as if you never started the rebase. Nothing is lost. Use it freely whenever a rebase is producing unexpected results — abort, inspect the situation, and try again with better understanding.

> [!warning] **Never leave conflict markers in committed code.** The `check-merge-conflict` pre-commit hook (§4.5) blocks this, but if hooks are not installed, it is possible to commit a file containing `<<<<<<<` markers. If this happens:
> 
> ```bash
> git show HEAD | grep "<<<<<<<<"   # confirm the markers are in the commit
> git reset --soft HEAD~1           # undo the commit, keep changes staged
> # resolve the markers, then re-commit
> ```

**Using lazygit for conflict resolution:**

lazygit provides a visual conflict resolution interface that avoids manually editing marker lines.

1. Open lazygit: `lazygit`
2. Navigate to the Files panel. Conflicted files are marked with a `UU` indicator.
3. Press `Enter` on a conflicted file to open the conflict view.
4. lazygit shows the three versions side by side: base, incoming, and current.
5. Navigate to a conflict block and press:
    - `b` — keep the base version
    - `o` — keep the incoming (origin) version
    - `y` — keep your version
    - `e` — open the file in your editor for manual resolution
6. After all conflicts in the file are resolved, stage the file with `space` in the Files panel.
7. Press `r` to continue the rebase from within lazygit.

> [!tip] For conflicts involving logic changes — where the correct resolution is a combination of both versions rather than choosing one — use `e` to open the file in Neovim and resolve manually. lazygit's pick-one-side interface is fastest for simple conflicts where one version is clearly correct; it is not a substitute for judgment on complex merges.

---

### Part 6: Workflow — Pull Requests

A PR is more than a merge request — it is the review gate, the CI gate, and the historical record of why a change was made. This part covers the full PR lifecycle from both sides: as the author (self-review, opening, monitoring CI, responding to feedback, merging) and as a reviewer (checking out, leaving feedback, the defined set of actions that require the browser).

---

#### 6.1 Author: Self-Review First

Before anyone else sees your PR, you review it yourself. This is the single habit that most improves code review quality — not because you will catch every bug, but because you will catch the things you already know are wrong: the debug print statement you forgot to remove, the TODO you left mid-function, the commit that has nothing to do with the feature.

```bash
git diff main...HEAD
```

This shows the cumulative diff of everything your branch adds relative to `main` — exactly what a reviewer will see. Read it top to bottom as if you are the reviewer, not the author.

> [!important] The three dots in `main...HEAD` are intentional. `git diff main...HEAD` computes the diff from the **merge base** (the point where your branch diverged from `main`) to your current HEAD — your changes only, regardless of what has landed on `main` since you branched. Two dots (`main..HEAD`) computes the diff from the **current tip of `main`** to HEAD: if `main` has advanced since you branched and your branch is not yet rebased, the starting point is wrong and the diff may not represent what a reviewer will actually see. Use three dots for self-review.

**What to look for during self-review:**

|Category|What to check|
|---|---|
|Debug artifacts|`print()`, `console.log()`, `breakpoint()`, hardcoded credentials, temporary test data|
|Incomplete work|`TODO`, `FIXME`, `wip:` commits, commented-out code left in place|
|Scope creep|Changes unrelated to the issue — these belong in a separate PR|
|Commit quality|Are commit messages meaningful? Is there a `wip:` commit that should be squashed?|
|Test coverage|Does the diff include tests for the new behavior?|
|Documentation|If the change affects an API or public interface, is the documentation updated?|

Fix anything you find before opening the PR. A self-review that produces fixes is working correctly — it is not a sign that the code was bad, it is the process doing its job.

**Checking individual commits:**

```bash
git log main...HEAD --oneline
```

Example output:

```
a3f9c2b feat(orders): add POST /orders endpoint
7b2d1e4 feat(orders): add order validation service
d4c8f1e feat(orders): add Order model and migration
```

Inspect any commit individually:

```bash
git show 7b2d1e4
```

If you find a `wip:` commit or a commit that should be squashed before review:

```bash
# Interactive rebase to clean up the last 3 commits
git rebase -i HEAD~3
```

In the editor, change `pick` to `squash` (or `s`) on commits to fold into the one above, or `reword` (or `r`) to edit a commit message without changing the content.

---

#### 6.2 Author: Opening a PR

Once self-review is complete and the branch is pushed, open the PR.

```bash
gh pr create --title "feat(orders): add order validation service" --body "Closes #42" --reviewer teammate-username
```

Expected output:

```
Creating pull request for feat/42-add-order-validation into main in owner/repo

https://github.com/owner/repo/pull/47
```

Note the PR number. You will use it to monitor CI, respond to review, and merge.

**The `Closes #N` syntax:**

`Closes #42` in the PR body is a GitHub keyword that auto-closes issue #42 when the PR merges. It must appear in the PR body, not just a comment. Other accepted keywords: `Fixes #N`, `Resolves #N`. All three behave identically.

```bash
# For a more detailed PR body, omit --body and let gh open your editor
gh pr create --title "feat(orders): add order validation service" --reviewer teammate-username
```

gh opens Neovim with a template. Write the body there. A useful PR body structure:

```markdown
## What

Adds an order validation service that checks CFDI line items before
allowing the order to proceed to invoice generation.

## Why

Required for SAT CFDI 4.0 compliance. Line items without valid SAT
product codes were previously passing through to invoice generation
and causing rejection at the SAT submission step.

## How

- New `OrderValidationService` in `app/services/orders.py`
- Validates SAT product codes against the supplier catalog
- Validates unit prices match catalog within a 0.01 tolerance
- Called from `POST /orders` before persisting the order

Closes #42
```

**Draft PRs:**

Open a draft PR when you want CI to run but the code is not ready for human review:

```bash
gh pr create --draft --title "feat(orders): add order validation service" --body "Closes #42"
```

Draft PRs run CI but do not request reviewer attention. Reviewers can see them but are not notified. Promote to ready when the work is complete:

```bash
gh pr ready
```

> [!tip] Draft PRs are useful for two situations: long-running work where you want CI feedback across multiple days without pinging reviewers, and work that depends on another PR merging first (open as draft, promote when the dependency merges).

**Adding labels and the milestone:**

```bash
gh pr create --title "..." --body "Closes #42" --label enhancement --milestone "v1.1.0"
```

Labels and milestones must already exist in the repository. Create them in the browser under Issues → Labels and Issues → Milestones.

---

#### 6.3 Author: Monitoring CI

CI runs automatically when a PR is opened or updated. Do not wait passively for an email — monitor it actively from the terminal.

**Watch CI run in real time:**

```bash
gh run watch
```

gh presents a list of recent workflow runs on the current branch. Select the run to watch. Output streams live:

```
✓ Set up job
✓ Checkout code
✓ Set up Python 3.12
✓ Install dependencies
✗ Run tests
```

Press `Ctrl-C` to stop watching without cancelling the run.

**View only the failed output (more readable than the full log):**

```bash
gh run view --log-failed
```

Example output:

```
Run pytest app/tests/
FAILED app/tests/test_orders.py::test_validate_missing_sat_code - AssertionError
  Expected ValidationError to be raised for order with missing SAT code
  No exception was raised
```

This is the output to read when a run fails. The full log includes setup, dependency installation, and other noise. `--log-failed` shows only the jobs and steps that failed.

**Re-run only failed jobs after pushing a fix:**

```bash
# Push your fix first
git add app/services/orders.py
git commit -m "fix(orders): raise ValidationError when SAT code is missing"
git push

# Then re-run only the failed jobs from the previous run
gh run rerun --failed
```

Expected output:

```
✓ Requested rerun of all failed jobs in run 9876543210
```

> [!tip] `gh run rerun --failed` re-runs only the jobs that failed, not the entire workflow. On workflows with expensive setup jobs (Docker builds, dependency caching), this saves significant time when the failure was in a fast test job.

**List recent runs on the current branch:**

```bash
gh run list --limit 10
```

Example output:

```
STATUS  TITLE                                     WORKFLOW  BRANCH                        AGE
✓       feat(orders): add validation service      CI        feat/42-add-order-validation  2m
✗       feat(orders): add Order model             CI        feat/42-add-order-validation  1h
✓       fix: correct invoice total (#38)          CI        main                          3h
```

> [!warning] **Symptom:** `gh run view --log-failed` shows no output. **Cause:** There are no failed runs on the current branch — all runs passed, or there are no runs yet. **Resolution:** `gh run list --limit 10` to see the status of all recent runs and their run IDs. If a run shows as failed but `--log-failed` shows nothing, the failure may be in a matrix job: `gh run view <run-id> --log-failed` with the specific run ID.

---

#### 6.4 Author: Responding to Review

When a reviewer leaves feedback, your response depends on the nature of the change.

**For small corrections** — a renamed variable, a missing docstring, a minor logic fix — push fixup commits. The reviewer can see the delta between their last review and your update:

```bash
# Make the fix, then commit with a fixup message
git add app/services/orders.py
git commit -m "fixup: rename validate() to validate_line_items() per review"
git push
```

The `fixup:` prefix is a signal that this commit addresses review feedback rather than adding new functionality. Before the PR merges, squash these into the parent commit. Do this once the reviewer has approved — squashing before approval discards their ability to use GitHub's "changes since last review" filter to see only what changed.

> [!important] If you set auto-merge (§6.5), disable it before squashing fixup commits, then re-enable it after pushing the cleaned history. Auto-merge fires as soon as checks pass and reviews are approved — if you push a squash rebase at the same moment, the force-push and the merge can race.
> 
> ```bash
> gh pr merge --disable-auto    # pause auto-merge
> git rebase -i main            # squash fixups
> git pushf                     # push clean history
> gh pr merge --auto --squash   # re-enable auto-merge
> ```

**For significant rework** — the reviewer identified an architectural issue, a wrong approach, or a substantial logic error — amend and force-push, but only after coordinating:

```bash
# Tell the reviewer in a comment that you are doing a significant rework
# and they should re-review from scratch when you push

# Make the changes, then amend or rebase -i to integrate them
git add app/services/orders.py
git rebase -i HEAD~3     # restructure the commit history
git pushf
```

> [!warning] Force-pushing after review discards the reviewer's ability to see only what changed since their last review. GitHub's "changes since last review" filter relies on the original commit SHAs being present. Only force-push for significant rework where the commit history is genuinely misleading — and always communicate with the reviewer first.

**Leaving a response comment on the PR:**

```bash
gh pr comment 47 --body "Renamed to validate_line_items() in the latest commit. Also added a docstring covering the tolerance logic you asked about."
```

The PR number (`47`) is the number from `gh pr create` output or `gh pr status`.

**Checking what feedback is outstanding:**

```bash
gh pr view 47
```

This shows the PR description, current CI status, reviewer status, and the most recent comments. For the full threaded conversation, open in the browser:

```bash
gh pr view 47 --web
```

---

#### 6.5 Author: Auto-merge

Auto-merge queues a merge that executes automatically when all required checks pass and all required reviews are approved. Set it immediately after opening the PR, then switch to the next task without waiting.

```bash
gh pr merge --auto --squash
```

Expected output:

```
✓ Pull request #47 will be automatically merged as a squash commit when all requirements are met.
```

When the merge executes, GitHub:

1. Squashes all commits on the branch into one commit on `main`.
2. Closes issue #42 via the `Closes #42` in the PR body.
3. Deletes the branch (if auto-delete is enabled in repository settings).

**Merge strategies:**

|Flag|Behavior|When to use|
|---|---|---|
|`--squash`|All branch commits become one commit on `main`|Default for most work — clean `main` history|
|`--merge`|All branch commits preserved, plus a merge commit|When individual commit history has documentary value|
|`--rebase`|All branch commits replayed onto `main`, no merge commit|When you want linear history and individual commits preserved|

> [!tip] `--squash` is the recommended default. It keeps `main` history readable: one commit per feature or fix, each tracing to a PR and an issue. The full commit history of the branch remains visible in the closed PR for anyone who needs the detail.

**Cancel auto-merge if you need to make more changes:**

```bash
gh pr merge --disable-auto
```

Make your changes, push, then re-enable:

```bash
gh pr merge --auto --squash
```

---

#### 6.6 Reviewer: Checking Out

To review a PR locally — running the code, checking tests, reading the diff with full editor support — check out the branch.

**By PR number:**

```bash
gh pr checkout 47
```

Expected output:

```
remote: Enumerating objects: 12, done.
remote: Counting objects: 100% (12/12), done.
remote: Compressing objects: 100% (6/6), done.
Receiving objects: 100% (12/12), done.
From https://github.com/owner/repo
 * [new branch]      feat/42-add-order-validation -> origin/feat/42-add-order-validation
Switched to a new branch 'feat/42-add-order-validation'
Branch 'feat/42-add-order-validation' set up to track remote branch 'feat/42-add-order-validation' from 'origin'.
```

**Using `gpr` — fuzzy PR checkout:**

`gpr` is a custom shell function (complete definition in Part 10, §10.2) that presents all open PRs in a fuzzy picker with a preview pane showing the PR body. Useful when you have multiple PRs to choose from and do not want to look up PR numbers.

```bash
gpr
```

The picker shows PR number, title, author, and CI status. Fuzzy-type to filter. `Enter` checks out the selected PR's branch.

**Inspecting the PR before reviewing:**

```bash
# PR metadata: title, body, CI status, reviewer status
gh pr view 47

# The diff with delta syntax highlighting
gh pr diff 47
```

`gh pr diff` uses delta for highlighting (configured in Dev Environment §7.4 — `gh config set pager delta`).

> [!warning] **Symptom:** `gh pr diff` output is plain text with no syntax highlighting. **Cause:** The `gh` pager is not set to delta. This is a separate configuration from git's pager. **Resolution:**
> 
> ```bash
> gh config set pager delta
> ```
> 
> This setting persists across sessions. It is separate from the `core.pager = delta` git config and must be set independently.

---

#### 6.7 Reviewer: Leaving Feedback

**Approve:**

```bash
gh pr review 47 --approve
```

Expected output:

```
✓ Approved pull request #47
```

**Request changes:**

```bash
gh pr review 47 --request-changes --body "The validation logic does not handle the case where line_items is None rather than an empty list. See app/services/orders.py line 52. Also: the tolerance constant should be extracted to config rather than hardcoded."
```

**Comment without approving or blocking:**

```bash
gh pr review 47 --comment --body "Minor: the docstring on validate_line_items() could mention the 0.01 tolerance explicitly. Not blocking."
```

**Inline line-level comments must use the browser.** The `gh` CLI does not support line-level review comments. This is the defined point where the terminal workflow hands off:

```bash
gh pr view 47 --web
```

This opens the exact PR in your browser at the Files Changed tab. Leave inline comments there. Return to the terminal for everything else.

> [!tip] Reserve `--request-changes` for issues that genuinely block the merge: incorrect behavior, missing tests for critical paths, security issues, architectural problems that will be expensive to fix after merge. Use `--comment` for suggestions, style preferences, and non-blocking observations. Over-using `--request-changes` creates review fatigue and slows the team down.

---

#### 6.8 What Belongs in the Browser

The terminal handles the majority of the PR workflow. A defined set of actions requires the browser. Knowing this boundary prevents wasted time looking for a CLI equivalent that does not exist.

|Action|Why browser only|
|---|---|
|Inline line-level PR review comments|`gh` CLI does not support line-level commenting|
|"Files changed since last review" filter|GitHub UI feature with no CLI equivalent|
|Repository settings (branch protection, merge strategies, auto-delete)|Admin actions with no CLI equivalent|
|GitHub Actions workflow authoring and secrets management|YAML editor and secrets UI|
|Dependabot alerts and security advisories|Security tab, no CLI equivalent|
|Project boards and issue triage views|Project UI|
|Cross-repository code search|GitHub search UI|
|Resolving conversations (marking review threads as resolved)|PR conversation UI|

For all of these, `gh pr view --web`, `gh repo view --web`, or `gh issue view --web` opens the relevant page directly from the terminal without navigating manually.

---

#### 6.9 Merging

If you did not set auto-merge (§6.5), merge manually once all checks pass and reviews are approved.

**Squash merge (recommended default):**

```bash
gh pr merge 47 --squash
```

gh prompts for the squash commit title and body. The default title is the PR title; the default body includes all commit messages from the branch. Edit both to produce a clean entry in `main` history.

**Merge commit (preserves individual commits):**

```bash
gh pr merge 47 --merge
```

Use when the individual commits on the branch are meaningful enough to preserve in `main` history — for example, a large refactor where each commit represents a discrete, independently understandable step.

**Rebase merge (linear history, no merge commit):**

```bash
gh pr merge 47 --rebase
```

Use when you want `main` to have a perfectly linear history with no merge commits, and the individual commits are meaningful. Note: this replays each commit individually onto `main`, changing their SHAs — the same tradeoff as rebasing.

**After merging, clean up locally:**

```bash
# Switch back to main and pull the merged commit
git sw main && git pull

# Delete the local feature branch (it is now merged)
git branch -d feat/42-add-order-validation
```

Expected output:

```
Switched to branch 'main'
Updating d1e8a3f..a7c3f91
Fast-forward
 app/services/orders.py | 48 ++++++++++++++++++++++++++++++++++++++++++++++++
 app/tests/test_orders.py | 31 +++++++++++++++++++++++++++++++
 2 files changed, 79 insertions(+)
Deleted branch feat/42-add-order-validation (was a3f9c2b).
```

> [!tip] If multiple merged branches have accumulated locally, `gh-poi` (the shell function in Part 10, §10.3) deletes all of them in one command rather than running `git branch -d` on each one individually.

> [!warning] **Symptom:** `git branch -d feat/42-add-order-validation` is rejected with `error: The branch is not fully merged`. **Cause:** git checks whether the branch commits are reachable from `main`. After a squash merge, the original branch commits are not in `main`'s history — the squash produced a new commit. git therefore thinks the branch is unmerged. **Resolution:** This is safe to force-delete because the squash merge preserved the content. Use `-D` (uppercase) to force:
> 
> ```bash
> git branch -D feat/42-add-order-validation
> ```

---

### Part 7: Workflow — History and Recovery

Every git mistake is recoverable if you understand the model. This part covers the four recovery operations you will need in practice: stashing work in progress, undoing commits (both local and published), cherry-picking specific commits, and auditing history to answer "what changed and when."

---

#### 7.1 Stashing Work in Progress

A stash is a temporary shelf for changes you are not ready to commit. It takes your staged and unstaged modifications, saves them to a stack, and returns your working tree to a clean state — without creating a commit.

**When to stash vs. when to commit:**

|Situation|Action|Reason|
|---|---|---|
|Context switch under an hour — quick fix on another branch, answering a question|`git stash`|Too small and transient to deserve a commit|
|Interruption longer than an hour, or you might forget what you were doing|`git commit -m "wip: ..."`|A commit survives a reboot; a stash does not if the session is lost|
|You need to pull upstream changes but have unstaged work blocking the pull|`git stash`|Clean the tree, pull, re-apply|
|End of day, work is genuinely incomplete|`git commit -m "wip: ..."`|Stashes are not backed up to remote; commits can be pushed|

> [!important] Stashes live only in your local repository. They are not pushed to the remote. If you stash, close your machine, and the local repo is lost, the stash is gone. For anything you would not want to lose, commit — even with a `wip:` prefix.

**Creating a stash:**

Always give stashes a descriptive message. An undescribed stash is indistinguishable from every other undescribed stash after two days.

```bash
git stash push -m "order validation — service skeleton done, tests pending"
```

Expected output:

```
Saved working state and index state On feat/42-add-order-validation: order validation — service skeleton done, tests pending
```

Your working tree is now clean. `git st` produces no output.

**Stashing untracked files:**

By default, `git stash push` does not stash untracked files (new files git has never seen). To include them:

```bash
git stash push --include-untracked -m "order validation — including new test file"
```

**Listing stashes:**

```bash
git stash list
```

Example output:

```
stash@{0}: On feat/42-add-order-validation: order validation — service skeleton done, tests pending
stash@{1}: On main: temp debug patch for invoice discrepancy
```

The most recent stash is always `stash@{0}`. Older entries increment: `stash@{1}`, `stash@{2}`, and so on. The list is a stack — new entries push older ones down.

**Inspecting a stash before applying:**

```bash
# See what files are in the stash
git stash show stash@{0}
```

```
 app/services/orders.py  | 24 ++++++++++++++++++++++++
 app/tests/test_orders.py |  0
 2 files changed, 24 insertions(+)
```

```bash
# See the full diff
git stash show -p stash@{0}
```

**Applying a stash:**

```bash
# Apply the most recent stash (stash@{0}), keep the entry in the list
git stash apply stash@{0}
```

Expected output (no conflicts):

```
On branch feat/42-add-order-validation
Changes not staged for commit:
  modified:   app/services/orders.py

Untracked files:
  app/tests/test_orders.py
```

`apply` re-applies the stash but keeps the entry in `git stash list`. This is useful when you want to apply the same stash to multiple branches, or when you are not sure the apply will succeed cleanly and want the stash preserved as a fallback.

```bash
# Apply and immediately remove the entry from the list
git stash pop
```

> [!warning] **Symptom:** `git stash pop` or `git stash apply` produces conflict markers in your files. **Cause:** The stash was created on a different base commit than the current state of the branch. The stash content and the current working tree have overlapping changes that git cannot auto-merge. **Resolution:**
> 
> 1. Resolve the conflict markers manually — same process as rebase conflicts (§5.5).
> 2. Stage the resolved files: `git add <file>`.
> 3. Drop the stash entry manually — it is already applied (conflicted), so do not pop or apply again:
> 
> ```bash
> git stash drop stash@{0}
> ```
> 
> Do not run `git stash pop` a second time. The stash content is already in your working tree; running it again will produce a second conflicted application.

**Removing a stash entry:**

```bash
# Remove one specific entry
git stash drop stash@{0}

# Remove all stash entries at once
git stash clear
```

> [!warning] `git stash clear` is irreversible. There is no undo. Use `git stash drop stash@{N}` to remove entries one at a time unless you are certain none of the entries are needed.

**Applying a stash to a different branch:**

A stash is not tied to the branch it was created on. You can apply `stash@{1}` (created on `main`) to `feat/42` without any special syntax — just switch to the target branch first, then `git stash apply stash@{1}`.

---

#### 7.2 Undoing Mistakes

The right undo command depends on one question: **has the commit been pushed to a shared remote?**

```
Has the commit been pushed?
│
├── No (local only)
│   └── git reset --soft HEAD~1    ← undo commit, keep changes staged
│       git reset HEAD~1           ← undo commit, keep changes unstaged
│       git reset --hard HEAD~1    ← undo commit, discard changes entirely
│
└── Yes (on a shared remote)
    └── git revert <id>            ← create a new commit that undoes the effect
```

---

**`git reset --soft HEAD~1` — undo the last local commit, keep changes staged**

Use when: you committed too early, or the commit message is wrong and you want to recommit with better content.

```bash
git reset --soft HEAD~1
```

Expected output: none. Run `git st` to confirm:

```
Changes to be committed:
  modified:   app/services/orders.py
```

The commit is gone from history. The changes are staged, ready to recommit.

```bash
git commit -m "feat(orders): add order validation service"
```

**`git reset HEAD~1` — undo the last local commit, keep changes unstaged**

Use when: you want to re-examine and re-stage the changes before recommitting. The working tree is unchanged; the staging area is cleared.

```bash
git reset HEAD~1
```

Run `git st` to confirm:

```
Changes not staged for commit:
  modified:   app/services/orders.py
```

**`git reset --hard HEAD~1` — undo the last local commit, discard changes entirely**

Use when: the commit and the changes are both wrong and you want to start over from the previous commit.

```bash
git reset --hard HEAD~1
```

> [!warning] `git reset --hard` permanently discards uncommitted changes. There is no undo for the working tree modifications. Before running it, confirm you genuinely do not need the changes. If uncertain, stash first: `git stash push -m "backup before hard reset"`.

**Undoing multiple commits:**

`HEAD~N` refers to N commits before HEAD. To undo the last three local commits:

```bash
git reset --soft HEAD~3    # keep all three commits' changes staged
```

**`git revert <id>` — undo a published commit**

Use when: the commit has been pushed to a shared branch. Revert creates a new commit that applies the inverse of the target commit — it does not rewrite history, so no force-push is required and no one else's local repository is affected.

```bash
# Find the commit to revert
git lg
```

```
* a3f9c2b (HEAD -> main, origin/main) feat(orders): add order validation service
* 7b2d1e4 feat(orders): add Order model and migration
* d1e8a3f fix(invoices): correct total on credit notes (#38)
```

```bash
# Revert the most recent commit
git revert a3f9c2b
```

git opens your editor with a pre-filled commit message:

```
Revert "feat(orders): add order validation service"

This reverts commit a3f9c2ba1f4e8d3c2b9f7e6d5c4a3b2a1f0e9d8.
```

Add a brief explanation of why the revert was necessary, then save and close.

Expected output:

```
[main f8e7d6c] Revert "feat(orders): add order validation service"
 1 file changed, 48 deletions(-)
```

The result on `main`:

```
* f8e7d6c (HEAD -> main) Revert "feat(orders): add order validation service"
* a3f9c2b feat(orders): add order validation service
* 7b2d1e4 feat(orders): add Order model and migration
```

Both commits are visible in history. The net effect is as if the feature was never added, but the record that it was added and then removed is preserved.

> [!important] **Never rewrite pushed history on a shared branch without coordinating with everyone who has pulled it.** `git reset` followed by `git pushf` on `main` or any shared branch forces every teammate to re-sync their local repository. In the best case this is disruptive; in the worst case it causes teammates to unknowingly re-introduce the commits you removed. On a shared branch, always use `git revert`.

**Undoing a revert** (re-applying the reverted change):

```bash
# Revert the revert commit — this re-applies the original change
git revert f8e7d6c
```

**The reflog — the recovery tool of last resort**

The reflog is a local log of every position `HEAD` has been at, in order. It survives `git reset`, `git rebase`, and `git commit --amend` — operations that appear to destroy history. Almost any git mistake is recoverable from the reflog because git does not immediately garbage-collect commits that are no longer reachable from any branch.

```bash
git reflog
```

Example output:

```
a3f9c2b (HEAD -> feat/42-add-order-validation) HEAD@{0}: commit: feat(orders): add validation service
7b2d1e4 HEAD@{1}: commit: feat(orders): add Order model
d1e8a3f HEAD@{2}: checkout: moving from main to feat/42-add-order-validation
9c3f8a1 (origin/main, main) HEAD@{3}: pull: Fast-forward
```

Each line shows: the SHA at that position, where HEAD is now, the reflog index (`HEAD@{N}`), the operation that moved HEAD, and a description.

**Using the reflog to recover from a bad reset:**

```bash
# You ran git reset --hard HEAD~3 and lost three commits
git reflog
# Find the SHA from before the reset — e.g., HEAD@{1} or the commit SHA directly
git reset --hard a3f9c2b    # restore HEAD to where it was
```

**Using the reflog to recover a dropped stash:**

Stashes appear in the reflog as `stash@{N}` entries even after `git stash drop`. To recover a dropped stash:

```bash
git reflog show stash    # show stash-specific reflog
# Find the SHA of the dropped stash entry
git stash apply <SHA>    # re-apply it
```

> [!warning] The reflog is local only — it is not pushed to the remote. If the local repository is lost (disk failure, accidental `rm -rf`), the reflog is gone with it. Commits that exist only in the reflog (not on any branch or tag) are garbage-collected after 90 days by default. The reflog saves you from command mistakes; it does not protect against data loss.

---

#### 7.3 Cherry-picking

Cherry-picking applies a specific commit from one branch onto the current branch, without merging the entire source branch. The result is a new commit with the same changes but a different SHA (a different parent pointer).

**When to use it:**

|Situation|Action|
|---|---|
|A bug fix was committed to a feature branch and is urgently needed on `main`|Cherry-pick the fix commit onto `main`|
|You committed to the wrong branch|Cherry-pick onto the correct branch, then reset the wrong branch|
|A useful utility function was written in one feature branch and needed in another|Cherry-pick that commit|
|You want to preview the effect of one commit in isolation|Cherry-pick onto a scratch branch|

**When not to use it:**

Cherry-pick is the right tool for one or a few specific commits. If you need more than four or five commits from another branch, consider merging or rebasing instead. Cherry-picking many commits produces a sequence of duplicate commits in history that creates confusion at review time and complicates future merges.

**Cherry-picking a single commit:**

```bash
# First, find the SHA of the commit you want
git log feat/38-fix-invoices --oneline
```

```
9c3f8a1 fix(invoices): correct nil check on credit note line items
d1e8a3f fix(invoices): correct total on credit notes
4e7b2d9 feat(invoices): add credit note support
```

```bash
# Apply the specific commit to the current branch
git cherry-pick 9c3f8a1
```

Expected output (no conflicts):

```
[main 7f3a2b1] fix(invoices): correct nil check on credit note line items
 Date: Mon Mar 17 10:22:14 2025 -0600
 1 file changed, 3 insertions(+), 1 deletion(-)
```

The commit message is preserved. The SHA is different because the parent is different.

**Cherry-picking a range of commits:**

```bash
git cherry-pick d1e8a3f..9c3f8a1
```

The range is exclusive of the first SHA and inclusive of the last. `d1e8a3f` is not included; `9c3f8a1` is the last commit included. To include both endpoints:

```bash
git cherry-pick d1e8a3f^..9c3f8a1
```

The `^` means "start from the parent of `d1e8a3f`" — effectively including it.

> [!warning] **Symptom:** Cherry-pick produces unexpected conflicts even though the commit looked straightforward. **Cause:** The commit depends on changes introduced by an earlier commit that is not present on the target branch. git is trying to apply a diff whose context lines do not exist in the target. **Resolution:** Inspect the source branch commit sequence before cherry-picking:
> 
> ```bash
> git log --oneline feat/38-fix-invoices
> ```
> 
> Identify which earlier commits the target commit depends on. Either cherry-pick those first (in order), or cherry-pick the full range that establishes the correct context.

**Conflict resolution during cherry-pick:**

The process is identical to rebase conflict resolution (§5.5):

1. `git status` — identify conflicted files.
2. Edit each file to resolve the conflict markers.
3. `git add <file>` — mark resolved.
4. `git cherry-pick --continue` — proceed to the next commit in the range.

**Abort a cherry-pick:**

```bash
git cherry-pick --abort
```

Returns the branch to its exact pre-cherry-pick state. Use freely whenever the result is not what you expected.

**Cherry-picking without committing:**

```bash
git cherry-pick --no-commit 9c3f8a1
```

Applies the changes to your working tree and staging area without creating a commit. Useful when you want to cherry-pick the changes but combine them with other modifications before committing.

---

#### 7.4 History Auditing

These commands answer the question "what happened and when?" They do not modify anything — they are read-only investigations.

---

**`git blame` — who changed each line and when**

```bash
git blame app/services/orders.py
```

Example output:

```
a3f9c2b (Alberto   2025-03-15 10:22:14 -0600  45) def validate_line_items(self, order: Order) -> bool:
a3f9c2b (Alberto   2025-03-15 10:22:14 -0600  46)     if not order.line_items:
7b2d1e4 (teammate  2025-03-14 16:45:02 -0600  47)         raise ValidationError("Order must have at least one line item")
a3f9c2b (Alberto   2025-03-15 10:22:14 -0600  48)     for item in order.line_items:
```

Each line shows: the commit SHA, author, date, line number, and content. Use this to answer "who wrote this line and in what context?" — then `git show <SHA>` to see the full commit that introduced it.

**Blame a specific line range:**

```bash
git blame -L 45,60 app/services/orders.py
```

Only lines 45 through 60.

**Blame ignoring whitespace changes:**

```bash
git blame -w app/services/orders.py
```

Useful when a reformatting commit obscures the actual author of the logic.

> [!tip] Neovim with the gitsigns plugin (configured in Dev Environment §5.4) shows inline blame annotations as virtual text on the current line. For quick lookups while editing, this is faster than running `git blame` in the terminal. Use the terminal command for range queries and for piping into other tools.

---

**`git log -S` — the pickaxe search**

Finds commits that added or removed a specific string. Use this when you need to answer "when was this function introduced, and who introduced it?" or "when was this constant removed?"

```bash
git log -S "validate_line_items" --oneline
```

Example output:

```
a3f9c2b feat(orders): add order validation service
```

The string `validate_line_items` was added in this commit. If it also appeared in a later deletion, that commit would appear too.

**Search with a regex pattern:**

```bash
git log -G "def validate_.*items" --oneline
```

`-G` uses a regex and matches commits where the diff contains lines matching the pattern (added or removed). `-S` matches commits where the count of the string changed (a stricter definition of "this commit added or removed this string").

**Combine with file path:**

```bash
git log -S "validate_line_items" --oneline -- app/services/orders.py
```

The `--` separates the git log options from the file path argument.

**Combine with full diff output:**

```bash
git log -S "validate_line_items" -p
```

Shows the full diff of each matching commit. Useful when the commit message is not sufficient context and you need to see exactly what changed around the matched string.

---

**`git log --follow` — history across file renames**

Normal `git log <file>` stops at the point where a file was renamed. `--follow` continues the history through renames.

```bash
git log --follow --oneline app/services/orders.py
```

Example output:

```
a3f9c2b feat(orders): add order validation service
7b2d1e4 feat(orders): add Order model and migration
e3f1a2b refactor: rename order_svc.py to orders.py
9d4c2f1 feat: initial order service skeleton
```

Without `--follow`, the log would stop at `e3f1a2b` and not show the two earlier commits made when the file was named `order_svc.py`.

---

**`git log` for targeted investigations**

A small set of `git log` flags covers the majority of investigation needs:

```bash
# All commits by a specific author
git log --author="Alberto" --oneline

# All commits touching a specific file
git log --oneline -- app/services/orders.py

# All commits in a date range
git log --oneline --after="2025-03-01" --before="2025-03-15"

# All commits that modified a specific function (requires Git 2.34+)
git log -L :validate_line_items:app/services/orders.py
```

`git log -L :<function>:<file>` is particularly powerful — it shows the complete edit history of a single function, including every commit that touched it, as a sequence of diffs. This is the fastest way to understand why a function looks the way it does today.

```bash
# Example output structure for -L
* commit a3f9c2b
  diff showing the function at this commit

* commit 7b2d1e4
  diff showing the function at the prior commit
```

> [!tip] When debugging a regression — "this worked two weeks ago, what changed?" — the most efficient path is usually: `git log --oneline --after="two-weeks-ago" -- path/to/file` to find the candidate commits, then `git show <SHA>` on each one until you find the change that introduced the regression. For large commit ranges, use `git bisect` (see below).

---

**`git bisect` — binary search for the commit that introduced a regression**

`git bisect` performs a binary search through commit history to find the exact commit that introduced a bug. Given a known good commit and a known bad commit, it checks out the midpoint for you to test, halving the search space each time. For a range of 1,000 commits, bisect finds the culprit in at most 10 steps.

```bash
# Start the bisect session
git bisect start

# Mark the current state as bad (bug is present)
git bisect bad

# Mark a known good commit (bug was not present)
git bisect good v1.0.0          # or any SHA you know was clean
```

git checks out the midpoint commit. Test whether the bug is present, then report:

```bash
git bisect bad     # the bug exists at this commit — search earlier half
git bisect good    # the bug does not exist — search later half
```

Repeat until git identifies the first bad commit:

```
d4c8f1e is the first bad commit
commit d4c8f1e
Author: Alberto <alberto@example.com>
Date:   Mon Mar 17 10:22:14 2025

    feat(orders): add validation service
```

End the session and return to your original branch:

```bash
git bisect reset
```

**Automating bisect with a test script:**

If you have a script that exits 0 (pass) or non-zero (fail), bisect can run it automatically against every midpoint without requiring manual intervention:

```bash
git bisect start
git bisect bad HEAD
git bisect good v1.0.0
git bisect run pytest app/tests/test_orders.py::test_total_calculation
```

git bisect runs the script at each midpoint and advances automatically. The session ends when the first bad commit is identified.

```bash
git bisect reset    # always end the session when done
```

> [!warning] Leave bisect sessions open only as long as you need them. An open bisect session puts the repository in a detached HEAD state at each step. If you switch to another task mid-bisect without running `git bisect reset`, you will find yourself on an unexpected commit with no clear path back. Reset immediately when done or when interrupting.

---

### Part 8: Workflow — Releases

A release tag marks the exact commit that was deployed to production. For the ERPNext/Mi Papelera stack, this is the starting point for every production incident investigation: `gh release list` and `git log v1.0.1..v1.1.0 --oneline` immediately show what changed between the running version and the previous one. Tag consistently.

---

#### 8.1 Cutting a Release

A release marks a specific commit on `main` as a named, stable point in time. It produces a Git tag, a GitHub release page, and auto-generated release notes from the PR and commit history since the last tag. Anyone who needs to deploy, roll back, or audit what changed between two versions starts here.

**Before cutting a release, confirm `main` is in the state you want to release:**

```bash
git sw main && git pull
git lg
```

Verify the most recent commits are exactly what you expect. A release tag cannot be un-pushed without coordinating with everyone who may have pulled it.

---

**Creating a release:**

```bash
gh release create v1.0.0 --generate-notes
```

Expected output:

```
? Title (optional) v1.0.0
? Release notes  [Use arrows to move, type to filter]
> Write my own
  Write using generated notes as template
  Leave blank

https://github.com/owner/repo/releases/tag/v1.0.0
```

gh prompts interactively. Choose **Write using generated notes as template** — this populates the editor with the auto-generated notes, which you can then edit before publishing.

**To skip the interactive prompts entirely:**

```bash
gh release create v1.0.0 --generate-notes --notes ""
```

This creates the release immediately with auto-generated notes and no manual editing step. Use for internal projects where release notes are informational rather than customer-facing.

**What `--generate-notes` produces:**

GitHub assembles release notes from all PR titles and commit messages between the previous tag and the commit being tagged (your current `HEAD`). The output groups changes by label if you use labels consistently on PRs.

Example auto-generated notes:

```markdown
## What's Changed

### Features
* feat(orders): add order validation service by @alberto in #47
* feat(invoices): add CFDI 4.0 credit note support by @alberto in #44

### Bug Fixes
* fix(invoices): correct subtotal on zero-rated line items by @alberto in #45

### Maintenance
* chore(deps): update httpx to 0.27.0 by @alberto in #46

**Full Changelog**: https://github.com/owner/repo/compare/v0.9.0...v1.0.0
```

> [!tip] The quality of auto-generated notes is directly proportional to the quality of your PR titles and the consistency of your labels. A PR titled `feat(orders): add order validation service` with label `enhancement` produces a clean, readable entry. A PR titled `stuff` with no label produces noise. This is the downstream payoff of the commit and PR discipline established in Parts 4 and 6.

---

**Semantic versioning:**

Every release tag follows `vMAJOR.MINOR.PATCH`.

|Segment|When to increment|Example change|
|---|---|---|
|`MAJOR`|Breaking change — existing callers must update their code or integration|Removing an API endpoint, changing a required field, dropping Python version support|
|`MINOR`|New backward-compatible feature — existing callers are unaffected|New API endpoint, new optional field, new CLI flag|
|`PATCH`|Bug fix — behavior corrected, no interface change|Fixing an incorrect calculation, correcting an error response code|

```
v1.0.0   ← initial stable release
v1.0.1   ← patch: fix invoice subtotal calculation
v1.1.0   ← minor: add order validation service
v2.0.0   ← major: remove deprecated v1 invoice endpoint
```

**Pre-release versions:**

For release candidates and beta versions, append a pre-release identifier:

```bash
gh release create v1.1.0-rc.1 --generate-notes --prerelease
```

The `--prerelease` flag marks the release as a pre-release on GitHub — it appears in the releases list but is not marked as the "latest" release. Use this for staging deployments and internal testing before a final release.

```
v1.1.0-rc.1   ← release candidate 1
v1.1.0-rc.2   ← release candidate 2 (if rc.1 had issues)
v1.1.0        ← final release
```

---

**Listing existing releases and tags:**

```bash
# List releases
gh release list
```

Example output:

```
TITLE    TYPE    TAG NAME  PUBLISHED
v1.0.1   Latest  v1.0.1    about 2 days ago
v1.0.0           v1.0.0    about 3 weeks ago
v0.9.0           v0.9.0    about 2 months ago
```

```bash
# List tags (git-level, includes tags not yet published as GitHub releases)
git tag --sort=-version:refname
```

Example output:

```
v1.0.1
v1.0.0
v0.9.0
v0.8.2
```

`--sort=-version:refname` sorts by version number descending rather than alphabetically — without it, `v1.10.0` sorts before `v1.9.0` alphabetically, which is incorrect for semantic versions.

---

**Viewing a specific release:**

```bash
gh release view v1.0.0
```

Example output:

```
v1.0.0
owner/repo
2025-03-01

## What's Changed
...

Assets
  Source code (zip)
  Source code (tar.gz)
```

---

**Deleting a release (without deleting the tag):**

```bash
gh release delete v1.0.0
```

This removes the GitHub release page but leaves the git tag intact. The tag is still in the repository history and still marks the commit. Use when you published a release by mistake but do not want to remove the tag from history.

**Deleting both the release and the tag:**

```bash
gh release delete v1.0.0 --cleanup-tag
```

> [!warning] Deleting a tag that has been pushed and pulled by others rewrites shared history at the tag level. Anyone who deployed from that tag or has it in their local repository will have a dangling reference. Only delete published tags when you are certain no one else has pulled them — in practice, this means immediately after an accidental publish, before anyone else acts on it.

---

**When to cut a release vs. just merging to `main`:**

Not every merge to `main` is a release. The distinction depends on your deployment model and the audience of your releases.

|Situation|Action|
|---|---|
|Continuous deployment: every merge to `main` auto-deploys|No manual release needed — the deploy pipeline tags automatically, or tags are not used|
|Versioned API or library with external consumers|Cut a release for every change that consumers need to know about|
|Internal tool with a staging → production promotion step|Cut a release when promoting to production; the tag marks exactly what is in production|
|Hotfix to production|Cut a patch release immediately after the fix merges to `main`|
|Work in progress across multiple PRs|Do not release until all related PRs are merged and the feature is complete|

> [!important] For the ERPNext/Mi Papelera stack, use `gh release list` as the starting point for any production incident investigation. `git log v1.0.1..v1.1.0 --oneline` immediately shows what changed between the running version and the previous one. Tag every production deployment.

---

**Checking out a specific release locally:**

```bash
# Check out the exact state of the repository at v1.0.0
git checkout v1.0.0
```

This puts you in detached HEAD state (§2.2) — expected and correct when checking out a tag. You are reading a historical snapshot, not working on a branch.

```bash
# Return to main when done
git sw main
```

**Creating a hotfix branch from a release tag:**

If production is running `v1.0.0` and `main` has moved significantly since then, a hotfix must be based on the release tag, not on current `main`:

```bash
git checkout v1.0.0
git sw -c hotfix/1.0.1-fix-invoice-total
# make the fix
git commit -m "fix(invoices): correct subtotal on zero-rated line items"
gh pr create --title "fix(invoices): correct subtotal on zero-rated line items" --base main
# after merging to main, also cherry-pick to a release branch if you maintain one
gh release create v1.0.1 --generate-notes
```

> [!tip] For most small projects and internal tools, hotfixes go directly to `main` (via PR) and a patch release is cut from there — the gap between `main` and the last release tag is small enough that it does not matter. The tag-based hotfix branch pattern is for projects where `main` is always significantly ahead of the last release, such as when a release cycle is weekly or monthly and `main` moves daily.

---

### Part 9: AI-Assisted Development with Conductor

Conductor is a Gemini CLI extension for structured, multi-phase feature implementation. It operates from a persistent plan, makes commits autonomously, and records checkpoint verification reports as git notes. This part covers when to use it, how to set it up, and the four rules that prevent the specific failure modes it introduces.

---

#### 9.1 What Conductor Is

Conductor is a Gemini CLI extension for structured, agentic feature implementation. It operates from a persistent plan, makes commits autonomously, and tracks progress across a multi-phase implementation using git notes as checkpoint records.

**The distinction from ad-hoc AI chat:**

|Ad-hoc chat (Gemini pane, `<leader>g`)|Conductor|
|---|---|
|One question, one answer|A full implementation plan with verified phases|
|You write the code, AI advises|Conductor writes the code, makes commits, runs tests|
|No persistent state between prompts|Progress tracked in `conductor/` directory and git notes|
|Best for: explaining, reviewing, quick generation|Best for: features too large for a single prompt|
|Stateless — context resets each session|Stateful — resumes across sessions from last checkpoint|

**When Conductor is worth using:**

- A feature requires changes across more than five files.
- The implementation has a clear sequence of phases (schema → service → endpoint → tests) that you want verified before each phase proceeds.
- You want to delegate the implementation and context-switch to other work while it runs.
- You need consistency across many files — Conductor reads your standards files before every action.

**When Conductor is not worth using:**

- The task is a single commit.
- The task requires judgment calls that are not expressible in a spec — nuanced architectural decisions, non-obvious tradeoffs.
- You are exploring or prototyping — Conductor's commit-by-commit structure adds overhead when the direction is not yet clear.

---

#### 9.2 One-Time Project Setup

Run this once per project, from the project root, before defining any tracks:

```bash
/conductor:setup
```

Expected output:

```
✓ Created conductor/
✓ Created conductor/tech-stack.md
✓ Created conductor/product.md
✓ Created conductor/standards.md
```

This creates three context files. Conductor reads all three before every action it takes. Their quality directly determines the quality of Conductor's output — vague context files produce vague code.

---

**`conductor/tech-stack.md`**

Documents the technical environment. Detailed enough that a capable developer could understand the stack from this file alone.

What to include:

- Language versions (Python 3.12, Node 20, etc.)
- Framework choices and key dependencies with versions
- Architecture patterns in use
- Infrastructure components and how they connect
- Any non-obvious constraints (e.g., specific SQLAlchemy patterns, async vs. sync, ERPNext doctype conventions)

Example: (hypothetical — adjust to your actual stack)

```markdown
# Tech Stack

## Runtime
- Python 3.12
- FastAPI 0.115 (async, using lifespan context)
- SQLAlchemy 2.0 (async engine, mapped dataclasses)
- Alembic for migrations

## Infrastructure
- PostgreSQL 16 (primary database)
- Redis 7 (task queue, caching)
- Hatchet (workflow orchestration, replaces Celery)
- Docker Compose for local development
- Devenv + Nix for reproducible environment

## Patterns
- Repository/Service/Processor pattern (see existing services in app/services/)
- Pydantic v2 for request/response schemas
- Dependency injection via FastAPI Depends()
- All database access through repository classes — no raw queries in services
- Conventional Commits with scopes matching module names

## ERPNext Integration
- ERPNext v15 via frappe.client REST API
- CFDI 4.0 document generation through sat-cfdi library
- Supplier sync via DC Mayorista SOAP API wrapper in app/integrations/
```

---

**`conductor/product.md`**

Documents what the product does and who uses it. Conductor needs this to make sensible decisions about behavior, validation rules, and error handling.

What to include:

- What the product does in one paragraph
- Who uses it (internal team, external customers, automated systems)
- Key workflows in plain language
- Data model overview (the main entities and their relationships)
- Any domain-specific constraints (e.g., SAT compliance rules, MercadoLibre API limits)

Example: (hypothetical)

```markdown
# Product

## What It Does
Mi Papelera is a B2B dropshipping platform selling IT equipment and office
supplies in Mexico. Orders placed on MercadoLibre are fulfilled by routing
purchase orders to DC Mayorista, generating CFDI 4.0 invoices via SAT, and
tracking shipment status back to the marketplace.

## Users
- Internal operators: manage catalog, review exceptions, handle supplier issues
- MercadoLibre buyers: place orders (do not interact with this system directly)
- DC Mayorista API: receives purchase orders, returns shipping confirmations

## Key Workflows
1. Order sync: MercadoLibre webhook → validate → create ERPNext Sales Order
2. Fulfillment: Sales Order → Purchase Order → DC Mayorista API
3. Invoicing: confirmed shipment → CFDI 4.0 generation → SAT submission
4. Exception handling: failed submissions enter a retry queue via Hatchet

## Core Entities
- Product: catalog item with SAT code, supplier SKU, MercadoLibre listing ID
- Order: MercadoLibre order with line items, buyer address, payment status
- Invoice: CFDI 4.0 document linked to a fulfilled order
- Supplier PO: purchase order sent to DC Mayorista for a confirmed order
```

---

**`conductor/standards.md`**

Documents the conventions Conductor must follow when writing code and commits. This is the file that enforces consistency — without it, Conductor will make stylistic decisions independently and they will be inconsistent with the rest of the codebase.

What to include:

- Commit format (Conventional Commits, scope conventions)
- Branch naming
- Testing expectations (what must be tested, what framework, what coverage threshold)
- Code style conventions not enforced by the linter
- Anything that would come up in a code review

Example: (hypothetical)

```markdown
# Standards

## Commits
- Conventional Commits format: type(scope): description
- Scopes match module names: orders, invoices, cfdi, auth, deps, sync
- Subject line under 72 characters, imperative mood
- Body required for non-obvious changes

## Branches
- feat/N-short-description
- fix/N-short-description
- N is the GitHub issue number

## Testing
- pytest, located in app/tests/
- Every new service method requires a unit test
- Integration tests for every new API endpoint
- Test file mirrors source file: app/services/orders.py → app/tests/test_orders.py
- No test should require a running database — use fixtures and mocks

## Code Style
- Type annotations on all function signatures
- Docstrings on all public methods (Google style)
- No bare except clauses — catch specific exceptions
- Constants in UPPER_SNAKE_CASE in app/constants.py, not inline

## Pull Requests
- PR title matches the squash commit message format
- Body must include "Closes #N"
- Self-review before opening (git diff main...HEAD)
```

---

**How to keep the context files current:**

Run `/conductor:review` after every track (§9.5). If the track introduced a new pattern, dependency, or convention, update the relevant context file immediately. Stale context files are the primary cause of Conductor producing code that is technically correct but architecturally inconsistent.

```bash
# After a track that added Hatchet for workflow orchestration:
# Open conductor/tech-stack.md and add the Hatchet section
# Open conductor/standards.md and add any new conventions
```

> [!important] The context files are committed to the repository. Every team member who uses Conductor works from the same context. Treat updates to these files with the same care as updates to `standards.md` or a contributing guide — they affect every future Conductor track.

---

#### 9.3 Defining a Track

A track is one feature or significant change. Tracks map directly to issues: one issue, one track.

```bash
/conductor:newTrack
```

Conductor prompts for a track description. Write it in the prompt, or prepare it in advance and paste.

---

**How to write a good track description:**

A good track description has three parts: the goal, the acceptance criteria, and the constraints.

```
Goal:
Implement the order validation service that checks CFDI line items
before allowing an order to proceed to invoice generation.

Acceptance criteria:
- OrderValidationService class in app/services/orders.py
- Validates that each line item has a valid SAT product code (non-empty string)
- Validates that unit prices match the supplier catalog within 0.01 tolerance
- Raises ValidationError with a descriptive message for each failure mode
- Unit tests covering: valid order, missing SAT code, price out of tolerance,
  empty line items list
- POST /orders endpoint updated to call validation before persisting

Constraints:
- Use the existing Repository pattern — no direct database access in the service
- SAT codes validated against the ProductRepository, not a hardcoded list
- ValidationError is the existing class in app/exceptions.py — do not create a new one
- No changes to the Order model schema — this is a service-layer concern only
```

**What each part does:**

|Part|Why it matters|
|---|---|
|Goal|Orients Conductor to the intent — prevents technically-correct but wrong implementations|
|Acceptance criteria|Defines what "done" means — Conductor uses these as checkpoint targets|
|Constraints|Prevents Conductor from solving the problem in ways that are correct in isolation but wrong for the codebase|

> [!important] Review the generated plan before running implementation. Conductor breaks the track into phases and tasks based on your description and the context files. Misunderstandings are cheapest to correct here — a correction to the plan costs nothing; a correction after implementation costs rework and potentially a `/conductor:revert`.
> 
> ```bash
> # After /conductor:newTrack, Conductor shows the plan
> # Read every phase and task before proceeding
> # If a phase is wrong, edit the track description and regenerate
> ```

---

#### 9.4 Running Implementation

```bash
/conductor:implement
```

Conductor begins executing the plan autonomously. For each task it:

1. Reads the context files (`tech-stack.md`, `product.md`, `standards.md`).
2. Reads the current state of the relevant files.
3. Writes or modifies code.
4. Runs any configured test commands.
5. Makes a commit with a Conventional Commit message.
6. Attaches a git note to the commit with a checkpoint verification report.

**What you see while Conductor runs:**

```
[Conductor] Phase 1: Data layer
  ✓ Task 1.1: Add Order model — committed a3f9c2b
  ✓ Task 1.2: Add orders migration — committed 7b2d1e4
[Conductor] Phase 1 checkpoint verified ✓

[Conductor] Phase 2: Service layer
  ✓ Task 2.1: Add OrderValidationService — committed d4c8f1e
  ✗ Task 2.2: Add unit tests — tests failing
    AssertionError: Expected ValidationError for missing SAT code
```

If a task fails, Conductor stops and reports the failure. It does not proceed to the next task automatically. You intervene (§9.5), fix the issue, and resume.

**Viewing checkpoint reports after implementation:**

Conductor attaches verification reports to commits as git notes. Read them with:

```bash
git log --show-notes
```

Example output:

```
commit a3f9c2b
Author: Conductor <conductor@gemini>
Date:   Mon Mar 17 10:22:14 2025

    feat(orders): add Order model and migration

Notes:
    Checkpoint 1.1 verified:
    - Order model created at app/models/orders.py ✓
    - Migration file created at alembic/versions/xxx_add_orders_table.py ✓
    - Model fields match spec: id, status, line_items, created_at ✓
    - No direct database access in model class ✓
```

> [!warning] **Pre-commit hooks must be installed before running `/conductor:implement`.** If hooks are not installed, Conductor's commits bypass all quality checks silently. Conductor does not install hooks itself.
> 
> Verify before every Conductor track:
> 
> ```bash
> cat .git/hooks/pre-commit    # must exist and be non-empty
> ```
> 
> If it does not exist:
> 
> ```bash
> pre-commit install    # or: just setup
> ```
> 
> If you discover after the fact that hooks were not installed, review all Conductor commits manually:
> 
> ```bash
> git log --oneline main..HEAD    # list Conductor's commits
> git show <SHA>                   # inspect each one
> ```

---

#### 9.5 Monitoring and Reviewing

**Check current progress:**

```bash
/conductor:status
```

Example output:

```
Track: Add order validation service
Phase 1: Data layer          ✓ complete (2/2 tasks)
Phase 2: Service layer       ◐ in progress (1/2 tasks)
Phase 3: API layer           ○ not started
Phase 4: Tests               ○ not started

Last checkpoint: Task 2.1 — feat(orders): add OrderValidationService (d4c8f1e)
```

**Request an AI review of the implementation so far:**

```bash
/conductor:review
```

Conductor reads the track spec, the context files, and the commits made so far, then produces a review against the spec and standards. This is not a substitute for your own review — it is a first pass that catches obvious deviations before you spend time reading the code yourself.

Example review output:

```
Review: Track "Add order validation service" — Phase 2 complete

✓ OrderValidationService created in correct location
✓ ValidationError from app/exceptions.py used (not a new class)
✗ validate_line_items() accesses self.db directly — violates Repository pattern
  (standards.md: "No direct database access in services")
✗ Missing docstring on validate_line_items() — required by standards
⚠ Price tolerance hardcoded as 0.01 — consider extracting to constants.py
```

**Manual review process:**

Do not rely solely on `/conductor:review`. Read the commits yourself:

```bash
# See all commits Conductor made on this branch
git log --oneline main..HEAD
```

```
d4c8f1e feat(orders): add OrderValidationService
7b2d1e4 feat(orders): add orders migration
a3f9c2b feat(orders): add Order model
```

```bash
# Inspect each commit
git show d4c8f1e
```

Read the diff. Ask: does this match what I specified? Does it follow the patterns in the rest of the codebase? Does it do anything unexpected?

> [!important] You must review Conductor's implementation even when `/conductor:review` reports no issues. Conductor can satisfy spec requirements in ways that are technically correct but architecturally inconsistent — patterns that do not match the surrounding code, abstractions that will complicate future changes, test coverage that passes by construction rather than by genuine verification. These are not things a spec check catches. They require a human reading the diff.

---

#### 9.6 Reverting

If Conductor's implementation direction is wrong — the approach is incorrect, not just a small bug — revert rather than manually fixing:

```bash
/conductor:revert
```

Conductor prompts for scope:

|Scope|What is reverted|When to use|
|---|---|---|
|`task`|The single most recent task commit|A specific step went wrong but the rest of the phase is correct|
|`phase`|All commits in the current phase|The entire phase approach is wrong|
|`track`|All commits in the track|The implementation direction is fundamentally wrong|

Example:

```bash
/conductor:revert
? Scope: phase
? Revert Phase 2: Service layer? (2 commits) Yes

✓ Reverted to checkpoint after Phase 1 (commit 7b2d1e4)
```

After reverting, update the track description or context files to correct the misunderstanding, then run `/conductor:implement` again from the reverted checkpoint.

**When to revert vs. manually fix:**

|Situation|Action|
|---|---|
|Small bug — wrong variable name, missing null check, off-by-one|Fix manually, commit with `fixup:` prefix|
|Wrong pattern used — direct DB access instead of repository, wrong error type|Revert the task, correct the constraint in the track description, re-implement|
|Wrong approach for the whole phase — service structured incorrectly|Revert the phase, update context files, re-implement|
|The spec itself was wrong — Conductor did what you said but not what you meant|Revert the track, rewrite the track description, start over|

> [!tip] A revert is not a failure. It is cheaper than a review that catches the same problem after the track is complete and a PR is open. Revert early and re-implement with better context rather than accumulating fixup commits on top of a wrong foundation.

---

#### 9.7 Critical Rules

Each rule is stated with its consequence if violated. These are not guidelines — violations produce specific, reproducible problems.

---

**Rule 1: Pre-commit must be installed before Conductor runs.**

```bash
# Verify before every /conductor:implement
cat .git/hooks/pre-commit    # must exist and be non-empty
```

**Consequence if violated:** Conductor commits bypass all quality hooks silently. Ruff formatting, linting, YAML validation, and merge conflict checks do not run. The branch accumulates commits that would fail hooks if committed manually. When you later run `pre-commit run --all-files`, you may find many failures across many files — all requiring manual remediation before the PR can pass CI.

**Resolution after the fact:**

```bash
pre-commit install
pre-commit run --all-files    # find all violations
# fix each violation, then:
git add -A
git commit -m "chore: apply pre-commit fixes to Conductor commits"
```

---

**Rule 2: Conductor works on your feature branch, never on `main`.**

```bash
# Verify before every /conductor:implement
git branch    # confirm you are NOT on main
```

**Consequence if violated:** Conductor commits directly to `main`, bypassing PR review and CI gates. The commits cannot be cleanly reverted without rewriting shared history.

**Resolution after the fact:** if Conductor committed to `main` and the commits have not been pushed:

```bash
git log --oneline -10    # identify Conductor's commits
git reset --soft HEAD~N  # where N is the number of Conductor commits
git sw -c feat/N-track-name
git commit -m "..."      # recommit on the feature branch
```

If the commits have been pushed to `main`, coordinate with your team before taking any action.

---

**Rule 3: Use `git merge origin/main`, not rebase, when Conductor is active.**

```bash
# When main has moved and you need to sync your Conductor branch:
git fetch origin
git merge origin/main    # NOT: git rebase origin/main
```

**Consequence if violated:** Rebasing rewrites the SHAs of every commit Conductor made. Conductor's git notes are keyed to those SHAs. After a rebase, the notes still exist in the repository but are no longer attached to any commit in the branch history. `/conductor:status` shows no checkpoints. `/conductor:review` has no history to read. The checkpoint trail is permanently unreadable for that branch.

**How to tell if notes are intact:**

```bash
git log --show-notes main..HEAD    # notes should appear under each Conductor commit
```

If no notes appear and Conductor has been running, the rebase has already broken them.

---

**Rule 4: Keep `conductor/` files current after every track.**

```bash
# After every track completes:
/conductor:review    # read the review output
# update conductor/tech-stack.md, product.md, or standards.md as needed
git add conductor/
git commit -m "docs(conductor): update context after order validation track"
```

**Consequence if violated:** Each track starts from increasingly stale context. Conductor makes decisions based on the architecture as it was when the context files were last updated, not as it is now. After several tracks with stale context, Conductor will produce code that is inconsistent with the current codebase — using deprecated patterns, missing new conventions, ignoring infrastructure components that were added after the context was last written.

The compounding effect: stale context produces inconsistent code, which makes the context more stale relative to the actual codebase, which produces more inconsistent code on the next track.

---

### Part 10: Shell Utility Functions Reference

_This part contains the complete definitions for every custom shell function referenced throughout this guide. Add all of these to the `programs.zsh.initContent` block in `home.nix` unless noted otherwise._

---

#### How to Add a Function to Your Shell

All functions in this part belong in the `programs.zsh.initContent` block in `home.nix` (Dev Environment §8.3). After adding or editing any function:

```bash
# Rebuild and apply the Home Manager generation
home-manager switch

# Reload the shell in the current session without opening a new terminal
source ~/.zshrc
```

Verify the function is available:

```bash
# Should print the function definition
which repo-status
type repo-status
```

Expected output:

```
repo-status is a shell function
repo-status () {
  ...
}
```

If the function is not found after `source ~/.zshrc`, the most common cause is a syntax error in `home.nix`. Check with:

```bash
home-manager build 2>&1 | head -40
```

---

#### 10.1 `repo-status` — Consolidated Repository Summary

Referenced in: §3.2

`repo-status` replaces five separate status commands with a single output. It shows: current branch, ahead/behind counts versus `origin/main`, staged file count, unstaged file count, stash count, and open PRs assigned to you.

```zsh
repo-status() {
  # Abort immediately if not inside a git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "repo-status: not inside a git repository" >&2
    return 1
  fi

  local branch ahead behind staged unstaged stashes prs

  # Current branch name
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)

  # Commits ahead of and behind origin/main
  # Uses ".." range: left side is behind count, right side is ahead count
  local counts
  counts=$(git rev-list --left-right --count origin/main...HEAD 2>/dev/null)
  if [[ -n "$counts" ]]; then
    behind=$(echo "$counts" | awk '{print $1}')
    ahead=$(echo  "$counts" | awk '{print $2}')
  else
    behind="?"
    ahead="?"
  fi

  # Staged file count: files in the index that differ from HEAD
  staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')

  # Unstaged file count: tracked files in the working tree that differ from the index
  unstaged=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')

  # Stash entry count
  stashes=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

  # Open PRs assigned to you on this repository
  # Falls back gracefully if gh is not authenticated or repo has no remote
  if gh auth status &>/dev/null; then
    prs=$(gh pr list --assignee @me --state open --json number \
          --jq 'length' 2>/dev/null || echo "0")
  else
    prs="(gh not authenticated)"
  fi

  # Output — fixed-width labels for easy scanning
  printf "%-10s %s\n"  "branch"   "$branch"
  printf "%-10s ↑%s ↓%s\n" "origin"  "$ahead" "$behind"
  printf "%-10s %s files\n" "staged"   "$staged"
  printf "%-10s %s files\n" "unstaged" "$unstaged"
  printf "%-10s %s\n"  "stashes"  "$stashes"
  printf "%-10s %s open (assigned to you)\n" "prs" "$prs"
}
```

**Example output:**

```
branch     feat/42-add-order-validation
origin     ↑2 ↓0
staged     0 files
unstaged   1 files
stashes    1
prs        1 open (assigned to you)
```

**How each field is computed:**

|Field|Source|Notes|
|---|---|---|
|`branch`|`git symbolic-ref --short HEAD`|Falls back to short SHA in detached HEAD state|
|`origin ↑↓`|`git rev-list --left-right --count origin/main...HEAD`|Three-dot range: left is behind, right is ahead|
|`staged`|`git diff --cached --name-only`|Files in the index differing from HEAD|
|`unstaged`|`git diff --name-only`|Tracked files in working tree differing from index — does not count untracked files|
|`stashes`|`git stash list`|Line count of the stash stack|
|`prs`|`gh pr list --assignee @me`|Requires `gh` to be authenticated|

> [!warning] **Symptom:** `origin` shows `↑? ↓?` instead of numbers. **Cause:** The current branch has no remote tracking branch configured, or `origin/main` does not exist (e.g., the repository was never pushed, or the default branch is named differently). **Resolution:** Push the branch to set the upstream: `git push -u origin branch-name`. If the default branch is not named `main`, update the `origin/main` references in the function to match your default branch name.

> [!warning] **Symptom:** `prs` shows `(gh not authenticated)`. **Cause:** `gh auth status` is failing — the GitHub CLI token has expired or `gh auth login` was never run. **Resolution:** `gh auth login` and follow the prompts. This is one of the three post-bootstrap manual steps (Dev Environment §2.5).

---

#### 10.2 `gpr` — Fuzzy Pull Request Checkout

Referenced in: §6.6

`gpr` presents all open PRs on the current repository in a fuzzy picker with a preview pane showing PR metadata. Selecting a PR checks out its branch locally.

```zsh
gpr() {
  # Abort if not inside a git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "gpr: not inside a git repository" >&2
    return 1
  fi

  # Abort if gh is not authenticated
  if ! gh auth status &>/dev/null; then
    echo "gpr: gh is not authenticated — run: gh auth login" >&2
    return 1
  fi

  # Fetch open PRs as JSON: number, title, branch name, author, CI status
  local pr_list
  pr_list=$(gh pr list \
    --state open \
    --json number,title,headRefName,author,statusCheckRollup \
    --template '{{range .}}#{{.number}} {{.title}} [{{.headRefName}}] — {{.author.login}}{{"\n"}}{{end}}' \
    2>/dev/null)

  if [[ -z "$pr_list" ]]; then
    echo "gpr: no open pull requests found" >&2
    return 0
  fi

  # Pipe into fzf with a preview pane showing full PR details
  local selected
  selected=$(echo "$pr_list" | fzf \
    --prompt="checkout pr> " \
    --preview='
      pr_num=$(echo {} | grep -o "^#[0-9]*" | tr -d "#")
      gh pr view "$pr_num" 2>/dev/null
    ' \
    --preview-window=right:60%:wrap \
    --ansi)

  if [[ -z "$selected" ]]; then
    # User cancelled with Ctrl-C or Escape — exit cleanly
    return 0
  fi

  # Extract the PR number from the selected line
  local pr_number
  pr_number=$(echo "$selected" | grep -o "^#[0-9]*" | tr -d "#")

  if [[ -z "$pr_number" ]]; then
    echo "gpr: could not parse PR number from selection" >&2
    return 1
  fi

  # Check out the PR branch
  gh pr checkout "$pr_number"
}
```

**What you see when `gpr` runs:**

```
  #47 feat(orders): add order validation service [feat/42-add-order-validation] — alberto
  #44 feat(invoices): add CFDI 4.0 credit note support [feat/44-cfdi-credit-notes] — alberto
> #45 fix(invoices): correct subtotal on zero-rated items [fix/45-invoice-subtotal] — teammate
  3/3 ──────────────────────────────────────────────────────
  checkout pr>
```

The preview pane (right side, 60% width) shows the full `gh pr view` output for the highlighted PR — title, body, CI status, reviewer status, and recent comments.

**Keybindings inside the picker:**

|Key|Action|
|---|---|
|Type|Filter PRs by any field|
|`↑` / `↓` or `j` / `k`|Move selection|
|`Enter`|Check out selected PR's branch|
|`Ctrl-C` or `Escape`|Cancel without checking out|

> [!tip] After `gpr` checks out the branch, you are on the PR author's branch with the remote tracking configured. Run `repo-status` immediately to confirm the branch state before reviewing. The standard reviewer workflow then continues with `gh pr diff` (§6.6) and `gh pr view` (§6.7).

> [!warning] **Symptom:** The preview pane is empty or shows an error for every PR. **Cause:** `gh pr view "$pr_num"` is failing — either `gh` is not authenticated or the network is unavailable. **Resolution:** `gh auth status` to check authentication. If authenticated, `gh pr view 47` directly to confirm the CLI is working.

---

#### 10.3 `gh-poi` — Delete Merged Local Branches

Referenced in: §6.9

`gh-poi` (prune obsolete, integrated) deletes local branches whose work has been merged into `main`. Run it periodically — after a sprint, after a series of PR merges, or any time `git branch -a` has become cluttered.

```zsh
gh-poi() {
  # Abort if not inside a git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "gh-poi: not inside a git repository" >&2
    return 1
  fi

  # Ensure local main is up to date before checking merge status
  echo "Fetching origin to get current merge status..."
  git fetch origin --prune

  # List branches to be deleted (dry run first)
  local merged_branches
  merged_branches=$(git branch --merged main \
    | grep -v "^\*" \
    | grep -v "^\s*main$" \
    | grep -v "^\s*develop$" \
    | tr -d ' ')

  if [[ -z "$merged_branches" ]]; then
    echo "gh-poi: no merged branches to delete"
    return 0
  fi

  # Show what will be deleted and ask for confirmation
  echo ""
  echo "Branches merged into main that will be deleted:"
  echo "$merged_branches" | while read -r branch; do
    echo "  - $branch"
  done
  echo ""

  # Prompt for confirmation
  read -r "confirm?Delete these branches? [y/N] "
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "gh-poi: cancelled"
    return 0
  fi

  # Delete confirmed branches
  echo "$merged_branches" | while read -r branch; do
    git branch -d "$branch" && echo "  ✓ deleted $branch" \
      || echo "  ✗ could not delete $branch (may need -D for squash-merged branches)"
  done

  echo ""
  echo "gh-poi: done"
}

# Register as both 'gh-poi' and as a gh extension alias
alias ghpoi='gh-poi'
```

> [!important] `gh-poi` only deletes branches that are **fully merged** into `main` according to git's commit graph (`git branch --merged main`). After a **squash merge** (the recommended default in §6.9), the original branch commits are not in `main`'s history — the squash produced a new commit. git therefore considers the original branch unmerged, and `gh-poi` will not delete it automatically.
> 
> For squash-merged branches, delete manually:
> 
> ```bash
> git branch -D feat/42-add-order-validation
> ```
> 
> Or use the extended version below that also handles squash-merged branches.

**Extended version that handles squash merges:**

```zsh
gh-poi() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "gh-poi: not inside a git repository" >&2
    return 1
  fi

  echo "Fetching origin to get current merge status..."
  git fetch origin --prune

  local branches_to_delete=()

  # Pass 1: branches fully merged by commit graph (merge or rebase merges)
  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    branches_to_delete+=("$branch")
  done < <(git branch --merged main \
    | grep -v "^\*" \
    | grep -v "^\s*main$" \
    | grep -v "^\s*develop$" \
    | tr -d ' ')

  # Pass 2: branches squash-merged — no commits ahead of main,
  # and the branch tip is not reachable from main but the tree is identical
  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    # Skip branches already captured in pass 1
    [[ " ${branches_to_delete[*]} " == *" $branch "* ]] && continue

    # A squash-merged branch has no commits that are not in main
    # when checked via merge-base: the merge-base equals the branch tip
    local merge_base
    merge_base=$(git merge-base main "$branch" 2>/dev/null)
    local branch_tip
    branch_tip=$(git rev-parse "$branch" 2>/dev/null)

    # If merge-base equals branch tip, branch is already fully contained in main
    if [[ "$merge_base" == "$branch_tip" ]]; then
      branches_to_delete+=("$branch")
      continue
    fi

    # Check if all commits on the branch have an equivalent patch in main
    # git cherry returns lines starting with '-' for commits already applied
    local unapplied
    unapplied=$(git cherry main "$branch" 2>/dev/null | grep -c "^+")
    if [[ "$unapplied" -eq 0 ]]; then
      branches_to_delete+=("$branch")
    fi
  done < <(git branch | grep -v "^\*" | grep -v "main" | grep -v "develop" | tr -d ' ')

  if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
    echo "gh-poi: no merged or squash-merged branches to delete"
    return 0
  fi

  echo ""
  echo "Branches to delete (merged or squash-merged into main):"
  for branch in "${branches_to_delete[@]}"; do
    echo "  - $branch"
  done
  echo ""

  read -r "confirm?Delete these branches? [y/N] "
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "gh-poi: cancelled"
    return 0
  fi

  for branch in "${branches_to_delete[@]}"; do
    # Use -D (force) because squash-merged branches fail -d
    git branch -D "$branch" && echo "  ✓ deleted $branch" \
      || echo "  ✗ could not delete $branch"
  done

  echo ""
  echo "gh-poi: done"
}

alias ghpoi='gh-poi'
```

**Example output:**

```
Fetching origin to get current merge status...
From https://github.com/owner/repo
 - [deleted]         (none)     -> origin/feat/42-add-order-validation

Branches to delete (merged or squash-merged into main):
  - feat/42-add-order-validation
  - fix/38-invoice-total
  - chore/29-update-deps

Delete these branches? [y/N] y
  ✓ deleted feat/42-add-order-validation
  ✓ deleted fix/38-invoice-total
  ✓ deleted chore/29-update-deps

gh-poi: done
```

> [!tip] Run `gh-poi` after every sprint or after a day of merging PRs. A clean branch list makes `git branch -a`, `gpr`, and `git lg` all more readable. The accumulation of merged branches is invisible overhead that compounds over time — ten stale branches cost little individually but make every branch-related operation noisier.

> [!warning] **Symptom:** `gh-poi` reports no branches to delete even though you know several PRs have merged. **Cause 1:** The remote branches were deleted on GitHub (auto-delete is enabled) but the local remote-tracking refs were not pruned. The `git fetch origin --prune` at the start of the function handles this — if branches still appear after running `gh-poi`, they may have local commits not in `main`. **Cause 2:** The branches were squash-merged and the extended version of the function is not installed. **Resolution for Cause 2:** Replace the simple version with the extended version above.

> [!tip] **Limitation of `git cherry`-based squash detection:** `git cherry` compares patch content (the diff produced by each commit) rather than SHA identity. If a commit was amended or rebased before the squash merge — changing its diff slightly compared to what ended up in `main` — `git cherry` may still show it as unapplied (a `+` line). In that case, `gh-poi` will not auto-delete the branch and you will need to delete it manually with `git branch -D`.

---

#### 10.4 Adding the Functions to `home.nix`

The complete block to add to `programs.zsh.initContent` in `home.nix`:

```nix
programs.zsh = {
  enable = true;
  # ... your existing zsh configuration ...

  initContent = ''
    # ── Shell utility functions ────────────────────────────────────────

    # repo-status: consolidated repository state summary (Dev Workflows §3.2)
    repo-status() {
      if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "repo-status: not inside a git repository" >&2
        return 1
      fi
      local branch ahead behind staged unstaged stashes prs
      branch=$(git symbolic-ref --short HEAD 2>/dev/null \
               || git rev-parse --short HEAD)
      local counts
      counts=$(git rev-list --left-right --count origin/main...HEAD 2>/dev/null)
      if [[ -n "$counts" ]]; then
        behind=$(echo "$counts" | awk "{print \$1}")
        ahead=$(echo  "$counts" | awk "{print \$2}")
      else
        behind="?"
        ahead="?"
      fi
      staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d " ")
      unstaged=$(git diff --name-only 2>/dev/null | wc -l | tr -d " ")
      stashes=$(git stash list 2>/dev/null | wc -l | tr -d " ")
      if gh auth status &>/dev/null; then
        prs=$(gh pr list --assignee @me --state open --json number \
              --jq "length" 2>/dev/null || echo "0")
      else
        prs="(gh not authenticated)"
      fi
      printf "%-10s %s\n"          "branch"   "$branch"
      printf "%-10s ↑%s ↓%s\n"    "origin"   "$ahead" "$behind"
      printf "%-10s %s files\n"    "staged"   "$staged"
      printf "%-10s %s files\n"    "unstaged" "$unstaged"
      printf "%-10s %s\n"          "stashes"  "$stashes"
      printf "%-10s %s open (assigned to you)\n" "prs" "$prs"
    }

    # gpr: fuzzy pull request checkout (Dev Workflows §6.6)
    gpr() {
      if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "gpr: not inside a git repository" >&2
        return 1
      fi
      if ! gh auth status &>/dev/null; then
        echo "gpr: gh is not authenticated — run: gh auth login" >&2
        return 1
      fi
      local pr_list
      pr_list=$(gh pr list \
        --state open \
        --json number,title,headRefName,author,statusCheckRollup \
        --template \
        "{{range .}}#{{.number}} {{.title}} [{{.headRefName}}] — {{.author.login}}{{\"\\n\"}}{{end}}" \
        2>/dev/null)
      if [[ -z "\$pr_list" ]]; then
        echo "gpr: no open pull requests found" >&2
        return 0
      fi
      local selected
      selected=$(echo "\$pr_list" | fzf \
        --prompt="checkout pr> " \
        --preview="
          pr_num=\$(echo {} | grep -o \"^#[0-9]*\" | tr -d \"#\")
          gh pr view \"\$pr_num\" 2>/dev/null
        " \
        --preview-window=right:60%:wrap \
        --ansi)
      [[ -z "\$selected" ]] && return 0
      local pr_number
      pr_number=$(echo "\$selected" | grep -o "^#[0-9]*" | tr -d "#")
      if [[ -z "\$pr_number" ]]; then
        echo "gpr: could not parse PR number from selection" >&2
        return 1
      fi
      gh pr checkout "\$pr_number"
    }

    # gh-poi: delete merged and squash-merged local branches (Dev Workflows §6.9)
    gh-poi() {
      if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "gh-poi: not inside a git repository" >&2
        return 1
      fi
      echo "Fetching origin to get current merge status..."
      git fetch origin --prune
      local branches_to_delete=()
      while IFS= read -r branch; do
        [[ -z "\$branch" ]] && continue
        branches_to_delete+=("\$branch")
      done < <(git branch --merged main \
        | grep -v "^\*" \
        | grep -v "^\s*main\$" \
        | grep -v "^\s*develop\$" \
        | tr -d " ")
      while IFS= read -r branch; do
        [[ -z "\$branch" ]] && continue
        [[ " \${branches_to_delete[*]} " == *" \$branch "* ]] && continue
        local merge_base
        merge_base=\$(git merge-base main "\$branch" 2>/dev/null)
        local branch_tip
        branch_tip=\$(git rev-parse "\$branch" 2>/dev/null)
        if [[ "\$merge_base" == "\$branch_tip" ]]; then
          branches_to_delete+=("\$branch")
          continue
        fi
        local unapplied
        unapplied=\$(git cherry main "\$branch" 2>/dev/null | grep -c "^+")
        if [[ "\$unapplied" -eq 0 ]]; then
          branches_to_delete+=("\$branch")
        fi
      done < <(git branch \
        | grep -v "^\*" \
        | grep -v "main" \
        | grep -v "develop" \
        | tr -d " ")
      if [[ \${#branches_to_delete[@]} -eq 0 ]]; then
        echo "gh-poi: no merged or squash-merged branches to delete"
        return 0
      fi
      echo ""
      echo "Branches to delete (merged or squash-merged into main):"
      for branch in "\${branches_to_delete[@]}"; do
        echo "  - \$branch"
      done
      echo ""
      read -r "confirm?Delete these branches? [y/N] "
      if [[ "\$confirm" != "y" && "\$confirm" != "Y" ]]; then
        echo "gh-poi: cancelled"
        return 0
      fi
      for branch in "\${branches_to_delete[@]}"; do
        git branch -D "\$branch" && echo "  ✓ deleted \$branch" \
          || echo "  ✗ could not delete \$branch"
      done
      echo ""
      echo "gh-poi: done"
    }

    alias ghpoi="gh-poi"

    # ── End shell utility functions ────────────────────────────────────
  '';
};
```

> [!important] **Nix string escaping inside `initContent`:** the `initContent` value is a Nix string enclosed in `''` (double single-quotes). Inside this string, `$` must be escaped as `\$` wherever it refers to a shell variable — otherwise Nix interprets it as a Nix interpolation. The functions above are already escaped correctly for the Nix context. If you edit them, every `$variable` inside the block must remain `\$variable`.
> 
> The exception: `${...}` Nix interpolations (when you intentionally want Nix to substitute a value) are left unescaped. In these functions there are none — every `$` is a shell variable and must be escaped.

> [!tip] If you prefer to keep the functions in a separate file rather than inline in `home.nix`, source them from `initContent`:
> 
> ```nix
> initContent = ''
>   source ${./zsh/functions.zsh}
> '';
> ```
> 
> Where `zsh/functions.zsh` is a file in the same directory as your `home.nix`. This approach keeps `home.nix` shorter and lets you edit functions without touching the Nix configuration. Both approaches are correct — choose based on your preference for how much lives in `home.nix` directly.

---

### Part 11: Quick Reference

_Every command from Parts 1–10 in one place. No explanations — return to the relevant Part for context and gotchas. Cross-references are provided for each section._

---

#### 11.1 Orientation (→ Part 3)

```bash
repo-status           # branch, ahead/behind, staged, unstaged, stashes, open PRs
git branch -vv        # branch tracking relationships and ahead/behind counts
git lg                # recent commit history with graph decoration
git st                # working tree status (short format)
git stash list        # parked work entries
gh pr status          # pull request state for current branch
```

**The complete orientation sequence — run in order at the start of every session:**

```bash
repo-status && git branch -vv && git lg && git st && git stash list && gh pr status
```

---

#### 11.2 Issues (→ §4.1)

```bash
# Create
gh issue create --title "..." --assignee @me --label enhancement
gh issue create                                  # interactive (opens editor)

# View
gh issue list --assignee @me                     # open issues assigned to you
gh issue list                                    # all open issues
gh issue view 42                                 # view a specific issue
gh issue view 42 --web                           # open in browser
```

---

#### 11.3 Branches (→ §4.2)

```bash
# Create
git sw main && git pull                          # always start from up-to-date main
git co feat/N-short-description                  # create and switch in one step

# Navigate
git sw branch-name                               # switch to existing branch
git sw -                                         # switch to previous branch

# Inspect
git branch -vv                                   # all local branches with tracking info
git branch -a                                    # all branches including remote

# Delete
git branch -d branch-name                        # safe delete (merged only)
git branch -D branch-name                        # force delete (squash-merged)
gh-poi                                           # delete all merged/squash-merged branches

# Rename
git branch -m old-name new-name                  # rename a local branch
```

---

#### 11.4 Staging (→ §4.4)

**Command line:**

```bash
git add <file>                                   # stage entire file
git add --patch <file>                           # interactive hunk staging
git diff --staged                                # review what is staged
git diff                                         # review what is unstaged
git restore --staged <file>                      # unstage a file
git restore <file>                               # discard unstaged changes (irreversible)
```

**lazygit hunk and line staging:**

```
lazygit                    # open lazygit
space                      # toggle file staged/unstaged (Files panel)
Enter                      # open diff view for file
] / [                      # navigate between hunks
space                      # stage/unstage hunk (in diff view)
v then space               # stage/unstage selected lines (visual mode)
```

---

#### 11.5 Commits (→ §4.3)

```bash
git commit                                       # open editor for message
git commit -m "type(scope): description"         # inline message
git commit --amend                               # amend last commit (unpushed only)
git commit --no-verify -m "..."                  # bypass pre-commit hooks (emergency only)
```

**Conventional Commits types:**

|Type|Use|
|---|---|
|`feat`|New behavior|
|`fix`|Bug correction|
|`chore`|Maintenance, no behavior change|
|`docs`|Documentation only|
|`refactor`|Restructure without behavior change|
|`test`|Test additions or corrections|
|`wip`|Incomplete — clean up before PR|
|`fixup`|Addresses review feedback — squash before merge|

---

#### 11.6 Sync Scenarios (→ Part 5)

```bash
# Scenario A: update local main (start of every session)
git sw main && git pull

# Scenario B: rebase feature branch onto main (unshared branch)
git fetch origin
git rebase origin/main
git pushf                                        # --force-with-lease --force-if-includes

# Scenario C: remote branch has new commits (shared branch or Conductor active)
git pull --rebase                                # shared branch, no Conductor
git fetch origin && git merge origin/main        # Conductor active (preserves git notes)
```

**Conflict resolution:**

```bash
git status                                       # identify conflicted files
# edit files — resolve all <<<<<<< markers
git add <resolved-file>
git rebase --continue                            # or: git merge --continue
git rebase --abort                               # cancel rebase, restore original state
git merge --abort                                # cancel merge, restore original state
```

---

#### 11.7 Undoing (→ §7.2)

```bash
# Local commits (not yet pushed) — safe to rewrite
git reset --soft HEAD~1                          # undo commit, keep changes staged
git reset HEAD~1                                 # undo commit, keep changes unstaged
git reset --hard HEAD~1                          # undo commit, discard changes (irreversible)
git reset --soft HEAD~N                          # undo last N commits

# Published commits (already pushed to shared branch) — never rewrite
git revert <SHA>                                 # create inverse commit
git revert HEAD                                  # revert the most recent commit

# Stash as backup before destructive operations
git stash push -m "backup before reset"

# Reflog — recover from any local mistake
git reflog                                       # every HEAD position, in order
git reflog show stash                            # stash-specific reflog (recover dropped stashes)
git reset --hard HEAD@{N}                        # restore HEAD to a previous reflog position
git reset --hard <SHA>                           # restore to any reflog SHA
```

> [!warning] `git reset --hard` and `git restore <file>` permanently discard changes. There is no undo for working tree modifications. Stash first when uncertain.

> [!tip] When something goes badly wrong and you are not sure what happened, `git reflog` is always the first command to run. It shows every position HEAD has been at — including commits that appear to have been lost to a reset or rebase. Almost any local mistake is recoverable within 90 days.

---

#### 11.8 Stash (→ §7.1)

```bash
# Save
git stash push -m "descriptive message"          # stash tracked changes
git stash push --include-untracked -m "..."      # include new untracked files

# Inspect
git stash list                                   # all stash entries
git stash show stash@{0}                         # files in stash entry
git stash show -p stash@{0}                      # full diff of stash entry

# Apply
git stash apply stash@{0}                        # apply, keep entry in list
git stash pop                                     # apply most recent, remove from list

# Remove
git stash drop stash@{0}                         # remove one entry
git stash clear                                  # remove all entries (irreversible)
```

---

#### 11.9 History Auditing (→ §7.4)

```bash
git blame <file>                                 # who changed each line and when
git blame -L 45,60 <file>                        # blame a specific line range
git blame -w <file>                              # ignore whitespace changes

git log -S "string" --oneline                    # pickaxe: when was this string added/removed
git log -G "regex" --oneline                     # regex match on diff content
git log --follow --oneline <file>                # history across file renames
git log --author="name" --oneline                # commits by author
git log --oneline -- <file>                      # commits touching a file
git log --oneline --after="2025-03-01"           # commits after a date
git log -L :function_name:<file>                 # history of a single function

git show <SHA>                                   # full diff of any commit
git diff main...HEAD                             # everything your branch adds (self-review)

# Reflog — recover lost commits and diagnose unexpected HEAD movements
git reflog                                       # every HEAD position, in order
git reflog show stash                            # stash-specific reflog
git reset --hard HEAD@{N}                        # restore to a previous reflog position

# Bisect — binary search for the commit that introduced a regression
git bisect start
git bisect bad                                   # mark current HEAD as bad
git bisect good <SHA-or-tag>                     # mark known-good point
# → git checks out midpoint; test, then: git bisect good/bad
git bisect run <test-script>                     # automate with a pass/fail script
git bisect reset                                 # always end the session when done
```

---

#### 11.10 Cherry-pick (→ §7.3)

```bash
git cherry-pick <SHA>                            # apply one commit to current branch
git cherry-pick <SHA1>^..<SHA2>                  # apply inclusive range
git cherry-pick --no-commit <SHA>                # apply changes without committing
git cherry-pick --continue                       # continue after resolving conflict
git cherry-pick --abort                          # cancel, restore original state
```

---

#### 11.11 Pull Request — Author (→ Part 6)

```bash
# Self-review before opening
git diff main...HEAD                             # full diff of your branch
git log main...HEAD --oneline                    # commit list
git show <SHA>                                   # inspect any commit

# Open
gh pr create --title "..." --body "Closes #N" --reviewer username
gh pr create --draft --title "..." --body "Closes #N"    # draft PR
gh pr ready                                      # promote draft to ready

# Monitor CI
gh run watch                                     # live CI output
gh run view --log-failed                         # failed output only
gh run rerun --failed                            # re-run failed jobs after fix
gh run list --limit 10                           # recent run history

# Respond to review
gh pr comment 47 --body "..."                    # add a comment
gh pr view 47                                    # PR metadata and status
gh pr view 47 --web                              # open in browser

# Merge
gh pr merge --auto --squash                      # queue auto-merge
gh pr merge --disable-auto                       # cancel auto-merge
gh pr merge 47 --squash                          # merge immediately (squash)
gh pr merge 47 --merge                           # merge immediately (merge commit)
gh pr merge 47 --rebase                          # merge immediately (rebase)
```

---

#### 11.12 Pull Request — Reviewer (→ §6.6–6.8)

```bash
# Check out
gh pr checkout 47                                # check out by PR number
gpr                                              # fuzzy picker checkout

# Inspect
gh pr view 47                                    # metadata, CI status, comments
gh pr diff 47                                    # diff with delta highlighting
gh pr view 47 --web                              # open in browser (inline comments here)

# Leave feedback
gh pr review 47 --approve
gh pr review 47 --request-changes --body "..."
gh pr review 47 --comment --body "..."
```

---

#### 11.13 Releases (→ Part 8)

```bash
# Cut a release
gh release create v1.0.0 --generate-notes        # interactive, with auto-notes
gh release create v1.0.0 --generate-notes --notes ""   # immediate, no editor

# Pre-release
gh release create v1.1.0-rc.1 --generate-notes --prerelease

# Inspect
gh release list                                  # all releases
gh release view v1.0.0                           # specific release
git tag --sort=-version:refname                  # all tags, newest first

# Delete
gh release delete v1.0.0                         # delete release, keep tag
gh release delete v1.0.0 --cleanup-tag           # delete release and tag

# Check out a historical release
git checkout v1.0.0                              # detached HEAD at tag
git sw main                                      # return to main

# Hotfix from a tag
git checkout v1.0.0
git sw -c hotfix/1.0.1-description
```

---

#### 11.14 Conductor Commands (→ Part 9)

```bash
# Setup (once per project)
/conductor:setup

# Track lifecycle
/conductor:newTrack                              # define a new track
/conductor:implement                             # run autonomous implementation
/conductor:status                                # current progress
/conductor:review                                # AI review against spec and standards
/conductor:revert                                # revert task / phase / track

# Inspect checkpoint records
git log --show-notes                             # show Conductor's git notes
git log --oneline main..HEAD                     # list Conductor's commits on branch

# Pre-flight check before every /conductor:implement
cat .git/hooks/pre-commit                        # must exist and be non-empty
git branch                                       # must NOT be on main
```

---

#### 11.15 Tmux Keybindings (→ Part 1)

_Prefix key: `C-Space` (configured in `tmux.conf` — Dev Environment §5.9)_

**Sessions:**

```
Ctrl-f          sessionizer picker (open or create any project workspace)
prefix d        detach from current session
prefix L        switch to previous session
prefix s        list and pick from all sessions
prefix X        kill current session
tmux ls         list running sessions (from shell)
tmux kill-session -t name   kill a named session (from shell)
```

**Windows:**

```
prefix c        new window
prefix n        next window
prefix p        previous window
prefix 1–9      go to window by number
prefix ,        rename current window
prefix &        close window (confirm with y)
prefix w        window picker
```

**Panes:**

```
prefix -        split horizontally (pane below)
prefix |        split vertically (pane right)
Ctrl-h/j/k/l   move focus (vim-tmux-navigator — works across Neovim and tmux)
prefix H/J/K/L  resize pane
prefix z        zoom pane to full screen (toggle)
prefix x        close pane (confirm with y)
prefix q        show pane numbers
```

**Copy mode:**

```
prefix [        enter copy mode
v               start selection
y               copy selection
q / Escape      exit copy mode
prefix ]        paste
```

**Config:**

```
prefix r        reload tmux.conf without restarting tmux
```

---

#### 11.16 Shell Utility Functions (→ Part 10)

```bash
repo-status     # branch state, ahead/behind, staged/unstaged, stashes, open PRs
gpr             # fuzzy pull request checkout with preview pane
gh-poi          # delete merged and squash-merged local branches
ghpoi           # shell alias for gh-poi (same function, two names)
```

---

#### 11.17 Aliases Reference (→ Dev Environment §7.2)

_Aliases are defined in Home Manager. This table is a recall reference — not the source of truth._

|Alias|Expands to|Purpose|
|---|---|---|
|`git st`|`git status --short`|Compact working tree status|
|`git lg`|`git log --oneline --graph --decorate --all`|Visual history graph|
|`git co`|`git switch -C`|Create branch and switch (resets to HEAD if branch exists)|
|`git sw`|`git switch`|Switch branch|
|`git pushf`|`git push --force-with-lease --force-if-includes`|Safe force push|

---

#### 11.18 Decision Tables

**Which sync scenario to use (→ Part 5):**

|Situation|Command|
|---|---|
|Start of session, update local `main`|`git sw main && git pull`|
|Feature branch behind `origin/main`, branch is unshared|`git fetch origin && git rebase origin/main && git pushf`|
|Feature branch behind `origin/main`, Conductor is active|`git fetch origin && git merge origin/main`|
|Remote has commits your local branch does not|`git pull --rebase`|

**Which undo to use (→ §7.2):**

|Situation|Command|
|---|---|
|Undo last commit, keep changes staged, not pushed|`git reset --soft HEAD~1`|
|Undo last commit, keep changes unstaged, not pushed|`git reset HEAD~1`|
|Undo last commit, discard all changes, not pushed|`git reset --hard HEAD~1`|
|Undo a commit already pushed to a shared branch|`git revert <SHA>`|
|Recover commits that appear lost after reset/rebase|`git reflog` → `git reset --hard HEAD@{N}`|
|Recover a dropped stash|`git reflog show stash` → `git stash apply <SHA>`|

**Which merge strategy to use (→ §6.9):**

|Situation|Flag|
|---|---|
|Default — clean `main` history, one commit per feature|`--squash`|
|Individual commits are meaningful and worth preserving|`--merge`|
|Linear history, individual commits preserved, no merge commit|`--rebase`|

**Which stash action to use (→ §7.1):**

|Situation|Command|
|---|---|
|Context switch under one hour|`git stash push -m "..."`|
|Interruption over one hour, or overnight|`git commit -m "wip: ..."`|
|Apply stash and keep as fallback|`git stash apply stash@{0}`|
|Apply stash and remove entry|`git stash pop`|

**Rebase vs. merge when keeping a branch current (→ Part 5):**

|Situation|Command|
|---|---|
|Solo unshared branch|`git rebase origin/main`|
|Shared branch, teammate pushed|`git pull --rebase`|
|Conductor active on branch|`git merge origin/main`|

---

#### 11.19 Pre-flight Checklist — Before Starting Work

_Run at the start of every session. Takes 60 seconds. Prevents the most common workflow mistakes._

```
□  repo-status          — confirm branch, ahead/behind, no unexpected staged/unstaged files
□  git branch -vv       — confirm tracking relationship is set
□  git lg               — confirm history looks as expected, no unexpected commits
□  git stash list       — resolve any outstanding stash entries before starting new work
□  gh pr status         — address any open review requests or failing CI before new work
□  git sw main && git pull   — ensure local main is current before branching
```

---

#### 11.20 Pre-flight Checklist — Before Opening a PR

```
□  git diff main...HEAD         — self-review the full diff as a reviewer would
□  git log main...HEAD --oneline — review commit list, no wip: commits remaining
                                   (three-dot log shows commits unique to your branch)
□  git st                        — working tree is clean, nothing accidentally unstaged
□  repo-status                   — branch is ahead of main, not behind (rebased)
□  gh run list --limit 5         — no failing CI runs on this branch from previous pushes
□  git diff main...HEAD | grep "^+" | grep -E "print\(|breakpoint\(\)|console\.log|# TODO|# FIXME|pdb\.set_trace"
                                 — no debug artifacts or incomplete markers in changed lines
```

---

#### 11.21 Pre-flight Checklist — Before Running Conductor

```
□  git branch                   — confirm you are NOT on main
□  cat .git/hooks/pre-commit    — must exist and be non-empty (pre-commit install)
□  conductor/tech-stack.md      — current? updated after last track?
□  conductor/product.md         — current? updated after last track?
□  conductor/standards.md       — current? updated after last track?
□  /conductor:newTrack plan     — reviewed before running /conductor:implement?
```

---

### Appendix A: Troubleshooting

_Organized by symptom. Each entry states the symptom exactly as you would observe it, the cause, and the resolution. For deeper context on any item, follow the cross-reference to the relevant Part._

_If your symptom is not listed here, the fastest path to a resolution is: `git status` to confirm the repository state, then `git reflog` to see every recent HEAD movement — most git mistakes are recoverable from the reflog._

---

#### Authentication and CLI

---

**`gh auth status` outputs an error or `You are not logged into any GitHub hosts`**

Cause: `gh auth login` was never run, or the token has expired.

Resolution:

```bash
gh auth login
# Select: GitHub.com → HTTPS → Login with a web browser
# Follow the device code prompt
```

This is one of the three post-bootstrap manual steps (Dev Environment §2.5). After re-authenticating, verify:

```bash
gh auth status
```

Expected output:

```
github.com
  ✓ Logged in to github.com as username
  ✓ Git operations for github.com configured to use https protocol
  ✓ Token: gho_****
```

---

**`gh pr status` shows nothing, or `no pull requests match your search`**

Cause 1: You are not inside a directory that is a git repository.

Resolution: `pwd` to confirm location. `cd` to the project root. Verify with `git rev-parse --is-inside-work-tree`.

Cause 2: The repository has no GitHub remote configured.

Resolution:

```bash
git remote -v    # should show origin pointing to github.com
```

If no remote is shown:

```bash
git remote add origin https://github.com/owner/repo.git
```

Cause 3: `gh` authentication has expired (see entry above).

---

**`gh run view --log-failed` shows no output**

Cause 1: No failed runs exist on this branch — all runs passed, or no runs have been triggered yet.

Resolution:

```bash
gh run list --limit 10    # inspect status of all recent runs
```

Cause 2: The failure is in a matrix job. The `--log-failed` flag without a run ID shows the most recent run — if that run passed, no output is shown even if an earlier run failed.

Resolution:

```bash
gh run list --limit 10                    # find the failed run ID
gh run view <run-id> --log-failed         # target the specific run
```

---

#### Branches and Commits

---

**Commits appear to be lost after `git reset --hard`, `git rebase`, or `git commit --amend`**

Cause: These operations move `HEAD` or rewrite commit SHAs, making commits unreachable from branch pointers. git does not immediately delete unreachable commits — they remain in the object store and in the reflog for 90 days.

Resolution:

```bash
git reflog
```

Find the SHA or `HEAD@{N}` entry from before the operation that caused the problem. Each line shows what HEAD pointed to and why it moved:

```
a3f9c2b HEAD@{0}: rebase finished: returning to refs/heads/feat/42
7b2d1e4 HEAD@{1}: rebase: feat(orders): add Order model
d4c8f1e HEAD@{2}: rebase: feat(orders): add validation service
9c3f8a1 HEAD@{3}: checkout: moving from feat/42 to feat/42
```

Restore to the pre-operation state:

```bash
git reset --hard HEAD@{3}    # restore to before the rebase
```

Or create a new branch at a recovered SHA without moving your current branch:

```bash
git branch recovered-work d4c8f1e
```

> [!tip] When you are not sure exactly which entry to restore to, create a branch at the candidate SHA first (`git branch test-recovery <SHA>`), inspect it (`git log test-recovery`), and only then reset your actual branch. This way you can try multiple reflog entries without losing anything.

---

**`git push` rejected: `remote contains work that you do not have`**

Cause: The remote branch has commits your local branch does not have. This happens when someone else pushed, or when you pushed from a different machine.

Resolution:

```bash
git pull --rebase    # fetch and replay your local commits on top
git push             # now succeeds
```

Do not use `git pushf` here unless this is your personal unshared branch. On a shared branch, `git pull --rebase` is the correct resolution (§5.4).

---

**`git pushf` rejected after running `git fetch`**

Cause: `--force-with-lease` detected that the remote branch has commits you have not incorporated. Running `git fetch` updates the remote-tracking ref, but if you did not also incorporate those commits (via merge or rebase), `--force-if-includes` blocks the push as a second safety check (§5.3).

Resolution:

```bash
git pull --rebase    # incorporate the remote commits
git pushf            # now succeeds
```

---

**`git branch -d branch-name` rejected: `the branch is not fully merged`**

Cause: After a squash merge, the original branch commits are not in `main`'s history. git considers the branch unmerged even though the content was merged (§6.9).

Resolution:

```bash
git branch -D branch-name    # force delete — safe after a confirmed squash merge
```

If you are unsure whether the branch was actually merged, check before deleting:

```bash
gh pr list --state merged --head branch-name    # confirm the PR merged
```

---

**You are in detached HEAD state**

Symptom: git outputs `You are in 'detached HEAD' state` or `HEAD detached at <SHA>`.

Cause: You ran `git checkout <SHA>` or `git checkout <tag>` directly (§2.2).

Resolution — if you made no commits in detached state:

```bash
git switch -    # return to the previous branch
```

Resolution — if you made commits you want to keep:

```bash
git switch -c new-branch-name    # create a branch at current position before leaving
```

---

**`git rebase --continue` opens the editor repeatedly**

Cause: Normal behavior — each commit in the rebase range that has conflicts requires a separate resolution and continuation step. If you have five commits in the rebase and three have conflicts, you will go through the resolve → `git add` → `git rebase --continue` cycle three times.

Resolution: Continue working through each conflict in turn. `git status` at any point shows how many commits remain:

```bash
git status
# You are currently rebasing branch '...' on '...'.
# (fix conflicts and then run "git rebase --continue")
```

If the rebase is producing more conflicts than expected, abort and consider merging instead:

```bash
git rebase --abort
git merge origin/main    # if Conductor is active, or shared branch
```

---

**Accidentally committed to `main` (not yet pushed)**

Resolution:

```bash
git reset --soft HEAD~1              # undo the commit, keep changes staged
git sw -c feat/N-branch-name         # create the correct feature branch
git commit -m "type(scope): ..."     # recommit on the feature branch
```

Verify `main` is clean:

```bash
git log origin/main..main --oneline  # should show no output
```

---

**Accidentally committed to `main` (already pushed)**

Resolution: Do not force-push `main` unilaterally. Coordinate with your team first.

If you are the only person working on the repository:

```bash
git revert HEAD              # create an inverse commit on main
git push                     # push the revert
git sw -c feat/N-branch-name # create the feature branch
# cherry-pick the original commit onto the feature branch if needed
git cherry-pick <original-SHA>
```

If others are working on the repository: create a GitHub issue describing what happened, communicate in your team channel, and decide together whether to revert on `main` or handle it differently.

---

**`git stash pop` shows conflict markers**

Cause: The stash was created on a different base commit than the current branch state. The stash content and the current working tree have overlapping changes (§7.1).

Resolution:

```bash
# Resolve the conflict markers in each affected file (§5.5)
git add <resolved-file>

# The stash is already applied — do NOT run stash pop or apply again
# Remove the stash entry manually
git stash drop stash@{0}
```

---

**`git log -L :function_name:file` produces no output or an error**

Cause 1: The function name contains special characters or the syntax does not match exactly. The function name must match exactly as it appears in the file — including underscores, case, and without parentheses.

Resolution:

```bash
# Correct
git log -L :validate_line_items:app/services/orders.py

# Incorrect — do not include parentheses
git log -L :validate_line_items():app/services/orders.py
```

Cause 2: Git version is below 2.34, which introduced function-context log. Check: `git --version`.

Resolution: Update git. On Ubuntu with Home Manager, update the `pkgs.git` input in your flake (Dev Environment §2.3).

---

**Repository is in an unexpected detached HEAD state after running `git bisect`**

Cause: A `git bisect` session was started and not ended with `git bisect reset`. Each bisect step checks out a specific commit (detached HEAD), and if the session was abandoned mid-run — by switching to another task, closing the terminal, or forgetting — the repository is left in the middle of a bisect with HEAD detached at the midpoint commit.

Symptom: `git status` outputs `HEAD detached at <SHA>` and `You are currently bisecting`.

Resolution:

```bash
git bisect reset    # end the session and return to the branch you were on before starting
```

If you had already found the culprit and just forgot to reset:

```bash
git bisect log      # review what was tested so the result is not lost
git bisect reset    # end the session
```

> [!tip] Make `git bisect reset` a reflex — run it immediately after identifying the bad commit, before switching to any other task. The bisect session state is stored in `.git/BISECT_HEAD` and `.git/BISECT_LOG`; if you need to reconstruct what happened after a forgotten reset, those files contain the full history of the session.

---

#### Pre-commit Hooks

---

**Pre-commit hook blocks a commit unexpectedly**

Cause: A hook found a violation — formatter needed to run, linter found an error, YAML is invalid, conflict markers detected.

Resolution: Read the hook output completely before taking any action. The output names the file and the problem:

```
ruff.....................................................................Failed
- hook id: ruff
- exit code: 1

app/services/orders.py:52:5: F841 Local variable `result` is assigned to but never used
```

Fix the reported issue, stage the fix, then commit again (§4.5):

```bash
# Fix the file, then:
git add app/services/orders.py
git commit -m "..."    # retry
```

---

**Formatter hook aborts the commit but the file looks correct**

Cause: The formatter (e.g., `ruff-format`) modified the file on disk but the staged version is still the pre-format version. The commit was aborted because the staged content does not match the working tree content. This is expected behavior — not a bug (§4.5).

Resolution:

```bash
git add <file>    # stage the formatted version
git commit -m "..."    # retry — now succeeds
```

---

**Conductor commits bypassed pre-commit hooks**

Cause: `pre-commit install` was not run before `/conductor:implement` executed (§9.7).

Resolution:

```bash
# Install hooks immediately
pre-commit install

# Run all hooks against the entire codebase to find all violations
pre-commit run --all-files

# Fix each violation
# Stage and commit the fixes
git add -A
git commit -m "chore: apply pre-commit fixes to Conductor commits"
```

Then review each Conductor commit manually to confirm no logic errors were introduced alongside the formatting violations:

```bash
git log --oneline main..HEAD    # list Conductor's commits
git show <SHA>                   # inspect each one
```

---

**`pre-commit install` produces `command not found`**

Cause: `pre-commit` is not installed in the current environment.

Resolution: Confirm you are inside the project's devenv shell. If using devenv:

```bash
devenv shell    # enter the project environment
pre-commit install
```

If `pre-commit` is not in the project's devenv packages, add it:

```nix
# devenv.nix
packages = [ pkgs.pre-commit ];
```

Then rebuild: `devenv shell`, then `pre-commit install`.

---

#### Lazygit

---

**lazygit shows `not a git repository`**

Cause: lazygit was opened from a directory that is not inside a git repository — for example, from `~` or `/tmp`.

Resolution: `cd` to the project directory before opening lazygit. If you are already in the project directory, confirm git is initialized:

```bash
ls -la .git    # should show a .git directory
```

If `.git` does not exist and this is a new project:

```bash
git init
```

---

**lazygit conflict resolution view is empty**

Cause: The file has no unresolved conflict markers. Either the conflicts were already resolved manually, or `git rebase --abort` was run and the file was restored.

Resolution: `git status` to confirm which files actually have conflicts. Open only the files listed as `both modified` in lazygit's conflict view.

---

#### Delta and Diff Display

---

**`gh pr diff` output is plain text with no syntax highlighting**

Cause: The `gh` pager is not set to delta. This is a separate configuration from `git`'s `core.pager` and must be set independently (§6.6).

Resolution:

```bash
gh config set pager delta
```

Verify:

```bash
gh config get pager    # should output: delta
```

---

**delta is not activating on `git diff` or `git log`**

Cause: The `core.pager` git config is not set to delta, or the delta binary is not in `PATH`.

Resolution:

```bash
# Confirm delta is available
which delta
delta --version

# Confirm git is using it
git config --global core.pager    # should output: delta
```

If `core.pager` is not set:

```bash
git config --global core.pager delta
```

If you manage git config through Home Manager (Dev Environment §7.4), add it there and rebuild:

```nix
programs.git.extraConfig = {
  core.pager = "delta";
};
```

---

#### Tmux

---

**`Ctrl-h/j/k/l` moves within Neovim but not out to tmux panes**

Cause: The vim-tmux-navigator bindings in `tmux.conf` are missing or out of sync with the Neovim configuration (§1.6).

Resolution:

```bash
prefix r    # reload tmux.conf
```

If the issue persists, check Dev Environment §5.6 (Neovim side) and §5.9 (tmux side) and confirm both sets of bindings are present and matching. Then reload Neovim plugins:

```
:Lazy sync
```

---

**`<leader>g` produces no output or Neovim reports pane not found**

Cause: The Gemini pane in the git window was closed (e.g., `exit` was typed inside it), breaking the pane number that the `<leader>g` binding targets (§1.6).

Resolution:

```bash
tmux kill-session -t session-name    # kill the session
# Then press Ctrl-f and select the project to recreate cleanly
```

---

**tmux Gemini pane numbering breaks after a pane is closed**

Cause: Same as above. The sessionizer assigns pane roles by creation order. Closing any pane shifts the numbering of subsequent panes, breaking any binding that targets panes by number.

Resolution: Kill the session and recreate via the sessionizer. The sessionizer always produces the correct layout with the correct pane assignments.

---

**Sessions are gone after a reboot**

Cause: Expected behavior. tmux sessions persist while the tmux server is running but do not survive a reboot. tmux-resurrect and tmux-continuum are intentionally excluded from this setup (§1.2).

Resolution: Press `Ctrl-f` and select any project. The sessionizer recreates the workspace in under three seconds. This is faster and more reliable than restoring potentially stale saved state.

---

**`tmux ls` shows a session but `Ctrl-f` does not attach to it**

Cause: The session name does not match any directory in the sessionizer's search path. The sessionizer finds projects by scanning a defined set of directories (configured in the sessionizer script — Dev Environment §6.3). A manually created session with `tmux new-session -s name` will not appear in the sessionizer picker if its name does not correspond to a project directory.

Resolution: Either create the session from the sessionizer (so it is always found), or attach to the manually created session directly:

```bash
tmux attach-session -t session-name
```

---

#### Conductor

---

**Conductor commits have no git notes (`git log --show-notes` shows nothing under commits)**

Cause 1: `git rebase` was run on the branch while Conductor was active, rewriting the commit SHAs. Conductor's notes are keyed to the original SHAs and are now orphaned (§9.7, Rule 3).

Cause 2: Conductor did not run successfully — the track was defined but `/conductor:implement` was not completed.

Resolution for Cause 1: The notes cannot be recovered for the rebased branch. Going forward, use `git merge origin/main` instead of `git rebase origin/main` on any branch where Conductor is active.

Resolution for Cause 2: Run `/conductor:implement` to execute the track.

---

**`/conductor:implement` stops mid-track with a test failure**

Cause: Conductor ran the project's test command and one or more tests failed. Conductor does not proceed past a failing checkpoint automatically (§9.4).

Resolution:

```bash
# Read Conductor's output — it shows which test failed and why
git show HEAD    # inspect the commit Conductor made before stopping

# Option 1: fix the test failure manually
# Edit the relevant file, then:
git add <file>
git commit -m "fixup: correct test failure in order validation"
/conductor:implement    # resume from the current checkpoint

# Option 2: if the implementation direction is wrong
/conductor:revert       # revert to before the failing task
# Update the track description or context files
/conductor:implement    # re-implement with corrected context
```

---

**Conductor produces code that does not match the existing codebase patterns**

Cause: The `conductor/` context files are stale — they describe the architecture as it was when they were last updated, not as it is now (§9.7, Rule 4).

Resolution:

```bash
# Revert the track
/conductor:revert

# Update the context files to reflect current patterns
# Then re-implement
/conductor:implement
```

To prevent recurrence: update `conductor/tech-stack.md` and `conductor/standards.md` immediately after every track that introduces a new pattern, dependency, or convention. Do not defer this step.

---

#### Devenv and Direnv

---

**`direnv: error .envrc file not found`**

Cause: You are not in a project directory that has a `.envrc` file, or the `.envrc` file was not created during project setup.

Resolution: Confirm you are in the correct directory. If the project uses devenv, the `.envrc` should contain:

```bash
use devenv
```

If it does not exist, create it:

```bash
echo "use devenv" > .envrc
direnv allow
```

---

**Environment variables from `.envrc` are not loading**

Cause 1: `direnv allow` was never run for this directory. direnv requires explicit approval for each `.envrc` file.

Resolution:

```bash
direnv allow    # run once per .envrc, or after any .envrc change
```

Cause 2: The direnv hook is not loaded early enough in the shell initialization sequence. The direnv hook must be loaded before tmux fires (Dev Environment §8.3).

Resolution: Check the order of hooks in `home.nix` `initContent`. The direnv hook must appear before any tmux auto-attach logic:

```nix
initContent = ''
  eval "$(direnv hook zsh)"    # must be early
  # ... rest of initContent ...
'';
```

Rebuild with `home-manager switch` and open a new terminal.

---

**`devenv shell` is slow or hangs on first entry**

Cause: First-time entry triggers Nix evaluation and potentially large package downloads. This is a one-time cost per project environment.

Resolution: Wait. Subsequent entries use the Nix store cache and are fast. If it hangs indefinitely (more than five minutes), interrupt with `Ctrl-C` and check:

```bash
nix store ping    # confirm the Nix daemon is running
```

If the daemon is not running:

```bash
sudo systemctl start nix-daemon
```

---

### Appendix B: The Standard Workflow at a Glance

_A single-page reference showing the complete day-to-day loop from session start to merged PR. No explanations — return to the relevant Part for full context._

```
┌─────────────────────────────────────────────────────────────────────┐
│  START OF SESSION                                                   │
│                                                                     │
│  Open WezTerm → auto-attaches to main tmux session                 │
│  Ctrl-f → select project → workspace created or resumed            │
│                                                                     │
│  Run orientation sequence:                                          │
│    repo-status                                                      │
│    git branch -vv                                                   │
│    git lg                                                           │
│    git st                                                           │
│    git stash list                                                   │
│    gh pr status                                                     │
│                                                                     │
│  Update local main:                                                 │
│    git sw main && git pull                                          │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  START NEW WORK                                                     │
│                                                                     │
│  gh issue create --title "..." --assignee @me --label enhancement  │
│                                                                     │
│  git co feat/N-short-description                                    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  IMPLEMENT  (repeat until done)                                     │
│                                                                     │
│  Write code                                                         │
│                                                                     │
│  git add --patch <file>   or   lazygit (hunk/line staging)         │
│                                                                     │
│  git commit -m "type(scope): description"                           │
│    → pre-commit hooks run                                           │
│    → formatter modified file? stage again and recommit             │
│    → linter error? fix, stage, recommit                            │
│                                                                     │
│  Keep branch current:                                               │
│    git fetch origin                                                 │
│    git rebase origin/main   (solo branch, no Conductor)            │
│    git merge origin/main    (Conductor active)                      │
│    git pushf                                                        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  OPEN PULL REQUEST                                                  │
│                                                                     │
│  Self-review:                                                       │
│    git diff main...HEAD                                             │
│    git log main...HEAD --oneline                                    │
│                                                                     │
│  Open PR:                                                           │
│    gh pr create --title "type(scope): ..." \                        │
│                 --body "Closes #N" \                                │
│                 --reviewer username                                 │
│                                                                     │
│  Set auto-merge:                                                    │
│    gh pr merge --auto --squash                                      │
│                                                                     │
│  Monitor CI:                                                        │
│    gh run watch                                                     │
│    gh run view --log-failed    (on failure)                        │
│    gh run rerun --failed       (after fixing)                      │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  REVIEW AND MERGE                                                   │
│                                                                     │
│  Respond to feedback:                                               │
│    git commit -m "fixup: ..."                                       │
│    git push                                                         │
│    gh pr comment 47 --body "..."                                    │
│                                                                     │
│  Auto-merge executes when:                                          │
│    ✓ All CI checks pass                                             │
│    ✓ Required reviews approved                                      │
│                                                                     │
│  After merge:                                                       │
│    git sw main && git pull                                          │
│    git branch -D feat/N-...     or   gh-poi                        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  END OF SESSION                                                     │
│                                                                     │
│  prefix d   (detach — session keeps running)                       │
│  or close WezTerm                                                   │
│                                                                     │
│  Never "save" anything. Sessions persist.                           │
│  Ctrl-f recreates any workspace in under 3 seconds.                │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Appendix C: Glossary

_Precise definitions for every term used in this guide. Where a term has a common informal meaning that differs from its git meaning, both are noted._

---

**Ahead / Behind** The number of commits a branch has relative to another. "Ahead 2" means the branch has 2 commits the reference does not have. "Behind 3" means the reference has 3 commits the branch does not have. Shown by `git branch -vv` and `repo-status`.

**Alias** A shorthand name for a longer git command, defined in git config or in the shell. `git st` → `git status --short`. Not to be confused with shell aliases, which are defined in `.zshrc` or `home.nix`.

**Bisect** A git command that uses binary search to find the exact commit that introduced a regression. Given a known-good commit and a known-bad commit, `git bisect` checks out the midpoint for testing and halves the search space each step. Can be automated with a pass/fail script via `git bisect run`. Always end a bisect session with `git bisect reset`.

**Branch** A movable pointer to a commit. Advancing the branch means creating a new commit that the pointer moves to. Branches are cheap — creating one copies only a 40-character SHA, not any files.

**Cherry-pick** Applying a specific commit from one branch onto the current branch, producing a new commit with the same content but a different SHA (different parent pointer). Does not merge the source branch.

**Commit** A snapshot of the entire repository at a point in time. Each commit has a unique SHA, a pointer to its parent, an author, a timestamp, and a message. Not a diff — a snapshot. (git stores diffs for efficiency, but the conceptual model is snapshots.)

**Conductor** A Gemini CLI extension for structured, agentic feature implementation. Operates from a plan, makes commits autonomously, and records checkpoint verification reports as git notes. Covered in Part 9.

**Conflict** Occurs during a merge or rebase when the same lines were changed in two places being combined. git marks the file with conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) and stops for manual resolution.

**Conventional Commits** A commit message format: `type(scope): description`. Types include `feat`, `fix`, `chore`, `docs`, `refactor`, `test`. Enables readable history, auto-generated changelogs, and Conductor compatibility.

**Detached HEAD** A state where HEAD points directly to a commit SHA rather than to a branch. Entered by checking out a tag or SHA. Commits made in this state are not on any branch and will eventually be garbage-collected unless a branch is created.

**devenv** A developer environment tool built on Nix that provides reproducible, project-local toolchains via `devenv.nix`. Activated automatically by direnv when entering a project directory. Covered in Dev Environment.

**direnv** A shell extension that automatically loads and unloads environment variables when entering and leaving directories with an `.envrc` file. Used to activate devenv environments automatically.

**Fetch** Downloads remote changes into remote-tracking refs (`origin/main`, etc.) without modifying any local branch or working tree. Always safe to run. Contrast with pull.

**Force push** Overwrites the remote branch with the local branch regardless of divergence. `git push --force` is unconditional and destructive. `git push --force-with-lease` is conditional — it refuses if someone else pushed since your last fetch. Only used on personal unshared branches after a rebase.

**HEAD** A pointer to where you are right now. Normally points to a branch, which points to a commit. In detached HEAD state, points directly to a commit.

**Home Manager** A Nix-based tool for managing user-level configuration declaratively. Manages shell config, git config, and most installed tools in this setup. Changes require `home-manager switch` to apply. Covered in Dev Environment.

**Hunk** A contiguous block of changed lines within a file diff. `git add --patch` presents changes one hunk at a time, allowing selective staging of individual sections of a file.

**Index** Another name for the staging area — the set of changes that will be included in the next commit. `git add` moves changes into the index. `git commit` records the index as a new commit.

**Issue** A numbered work record on GitHub tracking what needs to be done and why. The issue number connects branches, commits, and PRs to the reason they exist.

**lazygit** A terminal UI for git that provides interactive hunk and line-level staging, visual conflict resolution, and a unified view of the working tree, branches, and log. Covered in §4.4 and §5.5.

**Merge** Combines two branches by creating a new merge commit that has both branch tips as parents. Preserves the complete history of both branches. Contrast with rebase.

**Merge commit** A commit with two parents, produced by `git merge`. Records that two lines of history were combined at this point. Not produced by rebase or squash merge.

**Origin** The conventional name for the primary remote repository. `origin/main` refers to the `main` branch as last seen on the remote named `origin`.

**Pre-commit hook** A script that runs automatically before each `git commit`. Configured via `.pre-commit-config.yaml` or `devenv.nix` git-hooks. Can modify files (formatters) or report errors (linters). Covered in §4.5.

**Pull** `git fetch` followed by `git merge` (or `git rebase` with `--rebase`). Downloads remote changes and applies them to the current branch. Modifies the working tree. Contrast with fetch.

**Pull Request (PR)** A formal proposal on GitHub to merge one branch into another. Provides a diff, a review thread, CI gating, and the merge trigger. Despite the name, the PR author is requesting that the target branch pull their changes.

**Rebase** Replays commits from one branch on top of another, producing a linear history. Rewrites commit SHAs (new parent pointers). Never rebase shared branches without coordinating. Contrast with merge.

**reflog** A local log of every position HEAD has been at, in order. Survives `git reset` and `git rebase`. The recovery tool of last resort — almost any git mistake can be undone using the reflog.

**Remote** A named reference to another copy of the repository, usually on GitHub. The default remote is named `origin`. `git remote -v` lists all configured remotes.

**Remote-tracking ref** A local reference that records the last known state of a branch on a remote: `origin/main`, `origin/feat/42`. Updated by `git fetch`. Read-only — you cannot commit to a remote-tracking ref directly.

**Repository (repo)** A directory tracked by git — contains the `.git` directory with the full history, configuration, and object database. Everything git knows about a project lives in `.git`.

**Revert** Creates a new commit that is the inverse of a target commit — net effect is as if the target commit never happened, but both commits remain in history. The safe way to undo published commits on shared branches.

**Scope** The optional second component of a Conventional Commit message: `feat(orders): ...`. Identifies the module or area affected. Lowercase, consistent with module names.

**Session (tmux)** The top level of the tmux hierarchy. One session per project. Sessions persist until explicitly killed or the tmux server stops. Managed by the sessionizer. Covered in Part 1.

**Sessionizer** A custom script that fuzzy-finds project directories and creates or attaches to named tmux sessions. Invoked with `Ctrl-f`. A user-managed dotfile — not managed by Home Manager. Covered in Dev Environment §6.3.

**SHA** A 40-character hexadecimal identifier uniquely identifying a git object (commit, tree, blob). Often abbreviated to 7 characters in display contexts. Commits, trees, and blobs all have SHAs.

**Squash merge** Combines all commits on a branch into a single new commit on the target branch. No merge commit. The branch's original commits are not in the target branch's history — `git branch --merged` will not detect the branch as merged. The recommended default merge strategy in this guide.

**Staging area** See Index.

**Stash** A temporary storage location for uncommitted changes. `git stash push` saves changes and cleans the working tree. `git stash apply` restores them. Stashes are local — not pushed to the remote.

**Tag** A named pointer to a specific commit. Unlike a branch, a tag does not move when new commits are made. Used to mark release points. Pushed explicitly: `git push origin --tags`.

**Track (Conductor)** A single feature or significant change delegated to Conductor for implementation. Defined with `/conductor:newTrack`, executed with `/conductor:implement`. Broken into phases and tasks.

**Untracked file** A file in the working directory that git has never been told about — not staged, not committed, not ignored. Shown as `??` in `git status --short`. Either stage it, commit it, or add it to `.gitignore`.

**Working tree** The actual files on disk in the project directory — what you see in your editor. Distinct from the staging area (what will be committed) and the repository (what has been committed).