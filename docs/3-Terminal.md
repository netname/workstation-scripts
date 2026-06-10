> **Development Workstation** · [Overview](0-Overview.md) · [Stack](1-Stack.md) · [Installation](2-Installation.md) · **Terminal** · [Projects](4-Projects.md) · [Editors](5-Editors.md) · [Desktop](6-Desktop.md) · [Troubleshooting](7-Troubleshooting.md) · [Workflows](8-DevWorkflows.md)

## Part 3: WezTerm — The Terminal Emulator

> [!note] **What you will understand by the end of this part**
> - Why WezTerm is the terminal of choice and what role it actually plays (hint: less than you might think — tmux owns the workspace)
> - How the TERM variable propagates from WezTerm through tmux to Neovim, and why getting this wrong breaks colour rendering
> - The user-managed vs. Home Manager boundary as applied to WezTerm config: why a 1-second reload matters
> - How to configure, reload, and iterate on `wezterm.lua` without restarting the terminal

WezTerm is your entry point into the workspace, but its role in this stack is deliberately narrow: it is a rendering surface. It draws text, handles fonts, manages GPU-accelerated output, and launches tmux. Everything else — sessions, windows, panes, running processes — belongs to tmux. This boundary is what makes WezTerm _disposable_: close it mid-work, reopen it, and tmux reconnects to exactly where you were.

Understanding this role prevents a common mistake: using WezTerm tabs and keybindings for workspace management when that work should happen in tmux. This section explains the boundary clearly before covering the configuration.

---

### 3.1 What WezTerm Does in This Stack

WezTerm's responsibilities in this stack, and nothing more:

- **Renders text** with GPU acceleration and true 24-bit colour
- **Applies the Nerd Font** so tmux and Neovim glyphs render correctly
- **Launches tmux automatically** on open, attaching to an existing session or creating one
- **Reloads configuration instantly** with `SUPER+SHIFT+R` — no restart required
- **Provides WezTerm-level tabs** for transient shells that live outside any project session

WezTerm does _not_ manage your workspace. It does not hold sessions. Closing it kills nothing. When you reopen WezTerm, `default_prog = { "tmux", "new-session", "-A", "-s", "main" }` attaches to the running tmux session and your workspace is exactly as you left it.

---

### 3.2 Why WezTerm Config Is User-Managed (Not Home Manager)

As established in [1-Stack.md §1.5](1-Stack.md#15-the-dotfile-boundary-what-home-manager-manages-vs-what-you-manage-directly), WezTerm configuration is user-managed: you edit `~/dotfiles/wezterm/wezterm.lua` directly and reload with `SUPER+SHIFT+R` in under a second.

The specific reason this tradeoff is correct for WezTerm: the settings you tune most often — `font_size`, `window_padding`, `color_scheme` — are hardware-dependent. A font size that looks right on a 27-inch 4K external monitor is too small on a 14-inch laptop screen. Padding that feels comfortable in bright light is too sparse in a dark room. These settings change frequently during the first weeks of use, and occasionally thereafter.

A Home Manager rebuild for a single `font_size` change takes 30–60 seconds of Nix evaluation. `SUPER+SHIFT+R` takes under one second. The iteration speed difference makes user-managed the correct choice here, even though it means this file is not rebuilt by Nix.

The file is still version-controlled in `~/dotfiles/wezterm/wezterm.lua`. The lifecycle is:

```
Edit ~/dotfiles/wezterm/wezterm.lua
       ↓
Press SUPER+SHIFT+R in WezTerm
       ↓
Change takes effect immediately
       ↓
Verify visually
       ↓
cd ~/dotfiles && git add wezterm/wezterm.lua && git commit && git push
```

---

### 3.3 The TERM Propagation Chain — How Colour Gets from WezTerm to Neovim

_Without this mental model, colour problems are impossible to diagnose._

Three programs are involved in rendering a Neovim colour scheme: WezTerm, tmux, and Neovim. Each needs to correctly advertise and pass through colour capabilities to the next. When any link in this chain is misconfigured, Neovim themes render with washed-out 256-colour approximations instead of true 24-bit colour.

```
WezTerm
  Advertises: TERM = "wezterm"  (or "xterm-256color")
  Renders true 24-bit colour natively
        ↓ SSH or direct pty connection
tmux intercepts the connection
  Internally uses: TERM = "tmux-256color"
  Passes Tc capability via: terminal-overrides ",<your-TERM>:Tc"
  (must match the TERM value WezTerm advertises — see §3.4)
        ↓
Neovim (or any inner program)
  Sees the Tc flag → sets termguicolors = true
  Renders true 24-bit colour correctly
```

The two tmux lines required (covered in full in Part 3 §3.4):

```bash
set -g default-terminal "tmux-256color"
# Use whichever matches your wezterm.lua term setting:
set -ga terminal-overrides ",wezterm:Tc"        # if term = "wezterm"
# set -ga terminal-overrides ",xterm-256color:Tc" # if term = "xterm-256color"
```

Both lines are required. The first tells tmux what terminal type to advertise to inner programs. The second tells tmux to pass the `Tc` true-colour capability through to the outer terminal. One without the other is insufficient — Neovim themes will look degraded even if the terminal is capable.

#### The `term` Setting: `"wezterm"` vs. `"xterm-256color"`

This is the one WezTerm setting with a meaningful trade-off. Both options are presented here; the choice is yours.

**Option A: `term = "wezterm"`**

Sets `TERM` to `wezterm` inside WezTerm. This value corresponds to a terminfo entry that ships with WezTerm and describes its full capabilities.

_What you gain:_

- **Undercurl support** — wavy underlines for LSP diagnostics and spelling errors in Neovim render correctly. Without this, undercurls fall back to straight underlines or disappear entirely.
- **Richer true-colour declaration** — some programs read the terminfo entry directly rather than relying on the `Tc` capability flag; `wezterm` describes more capabilities than `xterm-256color`.

_What you give up:_

- SSH sessions to remote hosts that do not have the `wezterm` terminfo entry fail with `unknown terminal type`. This affects any server you have not explicitly configured.

_How to handle the SSH problem if you choose `"wezterm"`:_

WezTerm's `wezterm ssh` command installs the terminfo entry automatically on the remote host. For standard `ssh`:

```bash
# Install wezterm terminfo on the remote host (run once per host)
infocmp wezterm | ssh your-remote-host "tic -x -"
```

Or, override `TERM` per SSH session without changing your WezTerm config:

```bash
# In your shell config (home.nix programs.zsh.initContent):
alias ssh='TERM=xterm-256color ssh'
```

---

**Option B: `term = "xterm-256color"`**

Sets `TERM` to `xterm-256color`, a universally supported value present in the terminfo database of every Linux server.

_What you gain:_

- SSH to any remote host works without any extra steps.

_What you give up:_

- **No undercurl** — LSP diagnostics and spelling errors in Neovim use straight underlines instead of wavy ones.
- Slightly less accurate colour capability description, though in practice 24-bit colour still works correctly with the tmux `Tc` override.

---

> [!tip] If you are unsure, start with `"xterm-256color"` You can switch to `"wezterm"` at any point by changing one line and pressing `SUPER+SHIFT+R`. The SSH problem only surfaces when you actually SSH to a remote host. If you rarely SSH to remote servers, `"wezterm"` costs you nothing. If you SSH frequently to un-configured hosts, `"xterm-256color"` removes friction you would otherwise hit repeatedly.

---

### 3.4 Annotated Base Configuration

The following covers every setting in the base configuration with an explanation of what it does and why it is set this way. This is not the complete file — it is an annotated walkthrough of the decisions. The complete copy-paste file is in the reference section at the end of Part 3.

Place the config at `~/dotfiles/wezterm/wezterm.lua`. `setup-desktop.sh` symlinks it to `~/.config/wezterm/wezterm.lua`.

#### The Required Preamble

```lua
local wezterm = require 'wezterm'

return {
  -- all settings go inside this table
}
```

Every WezTerm config follows this structure. `wezterm` is the WezTerm Lua API module. All settings are keys in the returned table.

#### Font

```lua
font = wezterm.font("JetBrainsMono Nerd Font"),
font_size = 13,
```

`wezterm.font()` selects the font by family name exactly as registered in the system font database. JetBrainsMono Nerd Font is installed by Home Manager (`nerd-fonts.jetbrains-mono` in `home.packages`). If you see boxes (`□`) instead of icons, the font name here does not match the installed family name — verify with `fc-list | grep JetBrains`.

`font_size = 13` is a reasonable baseline for a 1080p monitor. On a 4K display at 100% scaling, 13 will appear very small — 15–16 is more comfortable. On a HiDPI laptop at 200% scaling, 13 renders at an effective 26px and may feel large — 11–12 is more comfortable. Change this freely; it reloads instantly.

#### Colour Scheme

```lua
color_scheme = "Catppuccin Mocha",
```

Catppuccin Mocha is set here and must be set to the same theme in `tmux.conf` (via the Catppuccin tmux plugin). This is not a preference — it is a requirement for colour consistency at pane borders. WezTerm renders the background behind everything; tmux renders its status bar and pane borders on top. If their background colours differ, visible seams appear at every pane border. When both use Catppuccin Mocha, the pane borders are invisible against the background.

To use a different colour scheme: change it in both `wezterm.lua` _and_ `tmux.conf` together, or accept visible seams. The Catppuccin tmux plugin (installed via TPM) supports multiple flavours: Mocha, Macchiato, Frappe, Latte. See §3.7 for the colour consistency mechanism in detail.

#### TERM Setting

```lua
term = "wezterm",   -- or "xterm-256color" — see §3.3 for the trade-off
```

Choose one of the two options described in §3.3.

#### Default Program

```lua
default_prog = { "tmux", "new-session", "-A", "-s", "main" },
```

This is what makes WezTerm disposable. Every time WezTerm opens a new window, it runs this command. The `-A` flag means "attach if a session named `main` already exists; create it if not." The practical effect: closing WezTerm does not kill tmux or any running processes. Reopening WezTerm drops you back into your existing session.

The session name `main` is the catch-all entry point. Project-specific sessions are created by the sessionizer (Part 3) and are separate from `main`. `main` is where you land before switching to a project.

#### Tab Bar

```lua
enable_tab_bar = true,
hide_tab_bar_if_only_one_tab = true,
```

WezTerm tabs are for transient shells that exist outside any tmux session — an SSH connection to a remote server, a one-off script you want isolated, a quick file lookup before returning to your project. With `hide_tab_bar_if_only_one_tab = true`, the tab bar disappears when there is only one tab (which is most of the time), removing visual clutter. It reappears automatically when you open a second tab with `SUPER+T`.

Do not use WezTerm tabs as a substitute for tmux sessions. Tmux sessions survive WezTerm closing; WezTerm tabs do not.

#### Window Padding

```lua
window_padding = { left = 6, right = 6, top = 6, bottom = 6 },
```

6px on all sides provides visual breathing room without wasting screen space on a large monitor. On a small laptop screen (13–14 inches), reduce to 2–4px.

---

### 3.5 Recommended Additions

These settings are not in the minimal base config but are recommended for this stack. Each has a specific reason.

```lua
-- Removes the title bar, keeps resize handles.
-- The tmux status bar provides all the information the title bar would show.
-- Cleaner look with no functional loss.
window_decorations = "RESIZE",

-- WezTerm catches output that occurs before tmux attaches (rare, but useful).
-- tmux manages its own separate scrollback buffer.
scrollback_lines = 5000,

-- Audible bell is almost always the wrong choice in a terminal workflow.
audible_bell = "Disabled",

-- Block cursor is easier to track when moving between panes quickly.
default_cursor_style = "BlinkingBlock",

-- Required for Neovim themes to render correctly.
-- Without this, some colour operations produce inverted results.
force_reverse_video_cursor = false,

-- Do not copy to clipboard on mouse selection.
-- Reason: enabling this conflicts with tmux copy mode.
-- When both are active, they write to different clipboard targets
-- and the behaviour becomes unpredictable.
-- Use Shift-click for quick WezTerm-level selections;
-- use tmux copy mode (prefix [) for structured multi-line copies.
copy_on_select = false,
```

---

### 3.6 Keybindings

These are WezTerm-level bindings. They operate _around_ tmux — they work before tmux loads and affect the WezTerm window itself, not the tmux session inside it.

```lua
keys = {
  -- Open a new WezTerm tab with a plain shell (outside tmux).
  -- Useful for: SSH sessions, one-off commands, anything that
  -- should not pollute your project session.
  { key = "t", mods = "SUPER", action = wezterm.action.SpawnTab "CurrentPaneDomain" },

  -- Reload wezterm.lua without restarting WezTerm.
  -- Use this after every config change.
  { key = "r", mods = "SUPER|SHIFT", action = wezterm.action.ReloadConfiguration },

  -- Font size adjustment without restarting.
  { key = "=", mods = "SUPER", action = wezterm.action.IncreaseFontSize },
  { key = "-", mods = "SUPER", action = wezterm.action.DecreaseFontSize },
  { key = "0", mods = "SUPER", action = wezterm.action.ResetFontSize },
},
```

**When to use WezTerm tabs vs. tmux sessions:**

|Use case|Use|
|---|---|
|SSH to a remote server|WezTerm tab (`SUPER+T`)|
|Quick one-off command outside a project|WezTerm tab|
|Project workspace (editor + services + git)|tmux session via sessionizer|
|Long-running process you want to survive terminal close|tmux session|
|Switching between two active projects|tmux sessions (switch with `Ctrl-f`)|

---

### 3.7 Colour Consistency with Tmux

The colour-bleed problem deserves a concrete explanation because it is easy to encounter and the cause is non-obvious.

WezTerm renders the terminal background. tmux renders its status bar and pane borders as text drawn _on top of_ that background. They are separate rendering layers with no direct coordination. If WezTerm's background colour is `#1e1e2e` (Catppuccin Mocha base) and tmux's status bar background is `#1e1e2e` (also Catppuccin Mocha), they match perfectly and the border is invisible. If they differ by a single hex digit, a visible seam runs along every pane border.

The solution used by this stack: both WezTerm and tmux use the Catppuccin Mocha theme from the same source. WezTerm uses the built-in `"Catppuccin Mocha"` colour scheme. tmux uses the Catppuccin plugin (installed via TPM, declared in `tmux.conf`). Both reference the same colour values, so the seams disappear.

**To verify:** Inside a tmux session, the pane borders should be effectively invisible — only distinguishable from the background because the terminal content stops at the border. If you can clearly see a bright line between panes, the themes are mismatched.

**To change the theme:** Update `color_scheme` in `wezterm.lua` and update the Catppuccin flavour in `tmux.conf` simultaneously. Both must change together.

---

### 3.8 How to Change or Add Settings

The complete workflow for any WezTerm configuration change:

```bash
# 1. Edit the config
nvim ~/dotfiles/wezterm/wezterm.lua

# 2. Reload (no restart required)
# Press SUPER+SHIFT+R inside WezTerm

# 3. Verify the change visually

# 4. Commit
cd ~/dotfiles
git add wezterm/wezterm.lua
git commit -m "chore: describe what changed and why"
git push
```

To find available settings not covered here: the WezTerm documentation at `wezfurlong.org/wezterm/config/lua/config/` lists every configuration key with its type, default value, and description.

---

### 3.9 Gotchas

Each gotcha: symptom, cause, resolution.

---

**Boxes instead of icons (`□` or `?` characters in tmux or Neovim)**

_Symptom:_ Powerline separators in the tmux status bar appear as boxes. File icons in Neovim's file explorer appear as boxes or question marks.

_Cause:_ Either the Nerd Font is not installed, or WezTerm is not configured to use it. The two failure modes have different diagnostics.

_Resolution:_

```bash
# Check if the font is installed:
fc-list | grep JetBrains
```

If this returns nothing, the font installation by Home Manager failed. Re-run `hms` to retry, or manually download JetBrainsMono Nerd Font from `nerdfonts.com`, unzip to `~/.local/share/fonts/`, and run `fc-cache -fv`.

If the font is installed but boxes still appear, the `font` setting in `wezterm.lua` does not match the installed family name. Use the exact family name from `fc-list` output.

---

**`term = "wezterm"` breaks SSH sessions**

_Symptom:_ SSH to a remote host prints `unknown terminal type` or produces garbled output.

_Cause:_ The remote host does not have the `wezterm` terminfo entry in its database.

_Resolution (choose one):_

Option 1 — Install the terminfo entry on the remote host (permanent fix):

```bash
infocmp wezterm | ssh your-remote-host "tic -x -"
```

Option 2 — Override TERM for all SSH sessions (no remote changes needed):

```bash
# Add to home.nix programs.zsh.initContent:
alias ssh='TERM=xterm-256color ssh'
```

Option 3 — Switch `wezterm.lua` to `term = "xterm-256color"` (simplest, but loses undercurl).

---

**`default_prog` prevents opening a plain shell**

_Symptom:_ Every WezTerm window immediately attaches to tmux. You cannot get a plain shell without going through tmux.

_Cause:_ This is by design — `default_prog` always launches tmux. It is not a bug.

_Resolution:_ Press `SUPER+T` to open a new WezTerm tab. The tab spawns a plain shell session before tmux loads. Alternatively, inside tmux, open a new window with `prefix c` for a shell inside the session.

---

**`copy_on_select = true` and tmux copy mode produce unpredictable clipboard behaviour**

_Symptom:_ Selecting text with the mouse sometimes copies to clipboard, sometimes does not. Pasting after a tmux copy-mode selection sometimes pastes the wrong content.

_Cause:_ WezTerm's `copy_on_select` and tmux copy mode write to different clipboard mechanisms. When both are active, whichever one ran most recently owns the clipboard, but the interaction is not deterministic.

_Resolution:_ Keep `copy_on_select = false` (the recommended setting from §3.5). Use the two tools for their intended purposes:

- **`Shift`-click drag in WezTerm**: quick single-line selection, copies to OS clipboard via WezTerm
- **`prefix [` in tmux**: enter copy mode for multi-line structured selection, copies via tmux-yank to OS clipboard

---

### Part 3 Summary

WezTerm is a thin rendering surface, not a workspace manager. Its one job is to draw text, apply the Nerd Font, and hand off to tmux. Everything you tune frequently — font size, padding, colour scheme — lives in `~/dotfiles/wezterm/wezterm.lua` and reloads with `SUPER+SHIFT+R` in under a second, bypassing Nix entirely.

The TERM propagation chain (`wezterm` → `tmux-256color` inside tmux → Neovim) is the single most common source of colour-rendering bugs. The two settings `term = "wezterm"` and the corresponding tmux lines are load-bearing — do not remove them.

**What carries forward:** Part 4 covers tmux — the persistent layer that WezTerm wraps and the reason WezTerm is disposable.

---

### Complete `wezterm.lua` Reference

Complete annotated configuration. Save to `~/dotfiles/wezterm/wezterm.lua`. `setup-desktop.sh` symlinks it to `~/.config/wezterm/wezterm.lua`. Reload with `SUPER+SHIFT+R` after any change.

```lua
-- ~/dotfiles/wezterm/wezterm.lua
local wezterm = require 'wezterm'

return {

  -- ── Font ────────────────────────────────────────────────────────────────────
  -- Primary: JetBrainsMono Nerd Font (installed by Home Manager: nerd-fonts.jetbrains-mono).
  -- Nerd Font required for Powerline symbols, file icons, git branch indicators.
  -- Fallbacks: Noto Sans Symbols 2 and Noto Sans Symbols cover the Miscellaneous
  -- Technical Unicode block (U+2300–U+23FF), including U+23F5 (⏵) used by the
  -- Catppuccin tmux theme. Without the fallback, WezTerm logs glyph warnings.
  -- Noto fonts are installed by setup-desktop.sh: apt install fonts-noto fonts-noto-core
  -- If you see boxes (□) instead of icons, verify the primary font name with:
  --   fc-list | grep JetBrains
  font = wezterm.font_with_fallback({
    'JetBrainsMono Nerd Font',
    'Noto Sans Symbols 2',  -- Miscellaneous Technical + broader Unicode coverage
    'Noto Sans Symbols',    -- additional symbol fallback
  }),
  font_size = 13,   -- Adjust for your monitor DPI: 4K external → 15-16, laptop → 11-13

  -- ── Colour scheme ───────────────────────────────────────────────────────────
  -- Catppuccin Mocha: must match tmux's theme to prevent visible seams at
  -- pane borders. Both WezTerm and tmux must use the same palette.
  -- If you change this, also update tmux.conf Catppuccin flavour.
  -- See §3.7 in 3-Terminal.md for the full colour consistency mechanism.
  color_scheme = "Catppuccin Mocha",

  -- ── TERM setting ────────────────────────────────────────────────────────────
  -- "wezterm": enables undercurl (wavy LSP diagnostic underlines in Neovim)
  --            and richer true-colour support. Downside: SSH to remote hosts
  --            without the wezterm terminfo entry fails with "unknown terminal".
  --            Fix: infocmp wezterm | ssh remote "tic -x -"
  --
  -- "xterm-256color": universally supported, no SSH issues. Loses undercurl.
  --
  -- See §3.3 in 3-Terminal.md for the full trade-off explanation.
  term = "wezterm",

  -- ── Default program ──────────────────────────────────────────────────────────
  -- Launches tmux on every WezTerm window open.
  -- -A: attach if session named "main" exists, create it if not.
  -- This is what makes WezTerm disposable: close it, reopen, tmux is still there.
  default_prog = { "tmux", "new-session", "-A", "-s", "main" },

  -- ── Tab bar ──────────────────────────────────────────────────────────────────
  -- Tabs are for transient shells outside tmux (SSH, one-off commands).
  -- Hide when only one tab to reduce chrome — reappears when SUPER+T opens more.
  enable_tab_bar           = true,
  hide_tab_bar_if_only_one_tab = true,

  -- ── Window ───────────────────────────────────────────────────────────────────
  window_padding = { left = 6, right = 6, top = 6, bottom = 6 },
  -- "RESIZE": removes title bar, keeps resize handles. The tmux status bar
  -- provides all information the title bar would show.
  window_decorations = "RESIZE",

  -- ── Rendering ─────────────────────────────────────────────────────────────────
  force_reverse_video_cursor = false,  -- required for correct Neovim colour rendering
  scrollback_lines           = 5000,   -- WezTerm catches output before tmux attaches
  audible_bell               = "Disabled",
  default_cursor_style       = "BlinkingBlock",  -- easier to track across panes

  -- ── Keybindings ──────────────────────────────────────────────────────────────
  -- WezTerm-level bindings — operate around tmux, not inside it.
  keys = {
    -- New WezTerm tab (plain shell outside tmux — useful for SSH, one-offs)
    { key = "t", mods = "SUPER",       action = wezterm.action.SpawnCommandInNewTab { args = { "zsh" } } },
    -- New WezTerm window
    { key = "n", mods = "SUPER",       action = wezterm.action.SpawnWindow },
    -- Reload wezterm.lua without restarting WezTerm
    { key = "r", mods = "SUPER|SHIFT", action = wezterm.action.ReloadConfiguration },
    -- Font size adjustment
    { key = "=", mods = "SUPER",       action = wezterm.action.IncreaseFontSize },
    { key = "-", mods = "SUPER",       action = wezterm.action.DecreaseFontSize },
    { key = "0", mods = "SUPER",       action = wezterm.action.ResetFontSize },
    -- Pass Ctrl+f through to tmux (overrides WezTerm's built-in pane search)
    { key = "f", mods = "CTRL",        action = wezterm.action.SendKey { key = "f", mods = "CTRL" } },
  },
}
```

---

## Part 4: Tmux — The Workspace Manager

> [!note] **What you now know**
> WezTerm is configured and reloads in under a second. You understand how TERM propagates through the stack, why WezTerm is deliberately thin, and how to iterate on `wezterm.lua` without friction. Part 4 covers the centerpiece that WezTerm wraps: tmux.

---

> [!note] **What you will understand by the end of this part**
> - Why tmux is the *centerpiece* of the workspace and WezTerm is disposable around it
> - The session → window → pane hierarchy and how to map it to your actual projects
> - How the two required TERM/colour lines work and what breaks without them
> - How to configure, reload, and evolve `tmux.conf` at 1-second iteration speed

tmux is the centerpiece of the workspace. While WezTerm is disposable — close it and reopen it freely — tmux is persistent. Sessions outlive any terminal window, survive WezTerm restarts, and continue running through the night. The sessionizer (Part 3) builds on this persistence to give you a declarative, one-keypress workspace for every project.

Understanding why tmux occupies this role, before touching the configuration, prevents the most common mistake: trying to replicate what tmux does at the WezTerm level.

---

### 4.1 What Tmux Does and Why It Is the Centerpiece

tmux maintains a server process that runs independently of any terminal emulator. When you open WezTerm, you are not creating a workspace — you are attaching to a tmux server that is already running (or starting one). When you close WezTerm, the tmux server keeps running. Every session, window, pane, and process inside tmux continues exactly as it was.

This property is what makes the rest of the stack possible:

- **WezTerm can be disposable** (§4.1) because tmux holds all workspace state
- **The sessionizer** (Part 3) can recreate a workspace in two seconds because it creates a tmux session, not a WezTerm window
- **Long-running processes** (Docker log tailing, `bench serve`, test runners) survive terminal close because they run inside tmux panes, not inside the terminal emulator

**The three-level hierarchy:**

```
Session  ─── one per project (e.g., "mipapelera", "achemex", "main")
  │
  └── Window ─── one per role within the project
        │          e.g., "editor", "services", "git"
        │
        └── Pane ─── subdivisions of a window
                       e.g., Neovim | shell | shell
```

Sessions are projects. You switch between projects by switching between sessions. Windows are roles — the "editor" window has Neovim and a shell pane; the "services" window tails Docker logs. Panes are subdivisions of a window for closely related simultaneous work.

---

### 4.2 Why Tmux Config Is User-Managed (Not Home Manager)

For the same reason as WezTerm (§3.2): prefix key choice, status bar layout, and keybindings are personal settings that change frequently during initial setup. `prefix r` reloads `tmux.conf` in under a second. A Home Manager rebuild for the same change takes 30–60 seconds.

The lifecycle is identical to WezTerm:

```
Edit ~/dotfiles/tmux/tmux.conf
       ↓
Press prefix r inside tmux
       ↓
Change takes effect immediately
       ↓
Verify behaviour
       ↓
cd ~/dotfiles && git add tmux/tmux.conf && git commit && git push
```

The bootstrap symlinked `~/dotfiles/tmux/tmux.conf` to `~/.config/tmux/tmux.conf`. Editing either path edits the same file.

---

### 4.3 Installation Verification

tmux is installed by Home Manager (declared in `home.nix` packages). Verify the version:

```bash
tmux -V
```

Expected output: `tmux 3.x` where x is 2 or higher. All features used in this guide require tmux 3.2 or later.

If `tmux -V` returns a version below 3.2, the Home Manager-installed tmux may not be on your `$PATH` yet — open a new shell and retry. If the version is still below 3.2, verify that `tmux` is in your `home.nix` packages list and run `hms`. The system tmux from Ubuntu apt is typically older; the Home Manager version in nixpkgs is always recent.

---

### 4.4 The TERM and True Colour Settings — The Two Required Lines

Before the annotated configuration, these two settings deserve their own section because they are the most commonly misconfigured and the consequences are not obvious.

```bash
set -g default-terminal "tmux-256color"
# Use whichever matches your wezterm.lua term setting (§3.3):
set -ga terminal-overrides ",wezterm:Tc"        # if term = "wezterm"
# set -ga terminal-overrides ",xterm-256color:Tc" # if term = "xterm-256color"
```

**Why both lines are required — not just one:**

The first line sets what terminal type tmux _advertises_ to programs running inside it (Neovim, shell, etc.). Setting it to `tmux-256color` tells inner programs they are running inside a capable terminal.

The second line tells tmux to pass the `Tc` (true-colour) capability _through_ to the outer terminal (WezTerm). Without this second line, tmux blocks the true-colour capability from reaching Neovim even when WezTerm supports it fully.

**Why the override value must match your WezTerm `term` setting:** The override pattern `,<TERM>:Tc` adds the `Tc` flag to the terminfo entry that WezTerm is advertising. If WezTerm advertises `wezterm` but the override targets `xterm-256color`, the flag is never applied and true colour silently breaks. Match them: `wezterm` with `wezterm`, or `xterm-256color` with `xterm-256color`.

The failure mode when only one line is present, or when the TERM values are mismatched: Neovim's colour scheme renders with 256-colour approximations — muddy greens, inaccurate reds, washed-out blues. The symptom looks like a theme problem, but it is a tmux configuration problem. Running `:checkhealth` inside Neovim and looking for a `termguicolors` warning is the fastest diagnostic.

These two lines connect to the TERM propagation chain described in §3.3. The full chain only works when all three links are correct: WezTerm's `term` setting, the first tmux line, and the second tmux line — with the second line's target matching the first link.

---

### 4.5 Full Annotated Configuration

The following covers every setting group in `tmux.conf` with an explanation of what each does and why it is configured this way. Settings that interact with other parts of the stack are flagged explicitly. The complete copy-paste file is in the reference section at the end of Part 4 below.

#### Prefix Key

```bash
set -g prefix C-Space
unbind C-b
bind C-Space send-prefix
```

`C-Space` (Control + Space) is the recommended prefix for this stack. The reasoning against the two common alternatives:

- `C-b` (tmux default): awkward to reach; requires moving the left hand off the home row
- `C-a` (screen tradition): conflicts with readline's "move to beginning of line" and with Neovim's increment-number operator

`C-Space` is reachable with one thumb without moving either hand from the home row. It has no conflicts with readline, Neovim, or any shell binding.

`bind C-Space send-prefix` means pressing `C-Space C-Space` sends a literal `C-Space` through to the inner program — useful in the rare case a program needs that keystroke.

#### Terminal and Colour

```bash
set -g default-terminal "tmux-256color"
# Must match your wezterm.lua term setting — see §4.4:
set -ga terminal-overrides ",wezterm:Tc"        # if term = "wezterm"
# set -ga terminal-overrides ",xterm-256color:Tc" # if term = "xterm-256color"
```

Covered in full in §4.4. The override value must match the `term` setting in `wezterm.lua` — mismatching these silently breaks true colour.

#### Window and Pane Numbering

```bash
set -g base-index 1
set -g pane-base-index 1
set-window-option -g pane-base-index 1
set -g renumber-windows on
```

Windows and panes start numbering at 1, not 0. The reason is ergonomic: the `1` key is on the left side of the keyboard; `0` is on the right. `Alt-1` to jump to the first window is a natural left-hand motion. `Alt-0` would be awkward.

`renumber-windows on` prevents gaps in the window list when a window is closed. Closing window 2 of [1, 2, 3] produces [1, 2], not [1, 3]. Without this, window numbers drift and the `Alt-1`, `Alt-2`, `Alt-3` bindings stop being predictable.

#### Behaviour Settings

```bash
set -g history-limit 50000
set -sg escape-time 0
set -g focus-events on
set -g mouse on
set -g automatic-rename off
set -g allow-rename off
```

`history-limit 50000`: tmux manages its own scrollback buffer separately from WezTerm's. 50,000 lines is generous enough to scroll through long build logs without impacting memory meaningfully.

`escape-time 0`: **Critical for Neovim.** This setting eliminates tmux's default 500ms delay after receiving an escape character. tmux uses this delay to distinguish a bare Escape keypress from the start of an escape sequence (which begins with `\x1b`). The default 500ms means every time you press Escape in Neovim to exit insert mode, there is a half-second pause before the mode changes. At 0ms, Escape is immediate.

> [!warning] `escape-time 0` is non-negotiable Do not set this to anything other than 0. Even 10ms is perceptible during rapid Neovim use. The symptom without this setting: Escape in Neovim feels "sticky" or laggy, and sometimes registers as the wrong character before the mode change. If Neovim ever feels slow to respond to Escape, check this setting first.

`focus-events on`: **Required for Neovim's `autoread`.** Without this, tmux does not forward `FocusGained`/`FocusLost` events to inner programs. Neovim uses these events to trigger `autoread` — automatic reload of files changed by another process. Without focus events, switching from a shell pane (where you edited a file with a different tool) to the Neovim pane does not refresh the buffer. You see stale content until you manually run `:e`. Plugins that react to focus — auto-save, gitsigns refresh, lualine updates — also stop working silently.

`mouse on`: Enables mouse click-to-focus and scroll wheel support. You will still use the keyboard for almost everything, but mouse click to switch pane focus is useful when you have three or more panes open.

`automatic-rename off` and `allow-rename off`: Prevent tmux from overwriting your intentional window names with the currently running command. The sessionizer names windows explicitly ("editor", "services", "git"). Without these settings, as soon as you run a command in a window, tmux renames it to that command name and the layout becomes unreadable.

#### Status Bar

```bash
set -g status-position bottom
set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
set -g status-left "#[fg=#89b4fa,bold] #S  "
set -g status-left-length 30
set -g status-right "#[fg=#6c7086] %H:%M "
set -g window-status-format "#[fg=#6c7086] #I:#W "
set -g window-status-current-format "#[fg=#cba6f7,bold] #I:#W "
```

The Catppuccin Mocha hex values here (`#1e1e2e`, `#cdd6f4`, `#89b4fa`, etc.) must match WezTerm's colour scheme to prevent colour seams at pane borders (§4.7). These values are from the Catppuccin Mocha palette. If you switch to a different colour scheme, update both this block and WezTerm's `color_scheme` setting together.

The status bar shows: session name on the left, window list in the centre, time on the right. This is the minimum useful information. The Catppuccin tmux plugin (§4.7) overrides this with a more polished version while keeping the same colour values.

#### Pane Navigation

```bash
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"

bind -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
bind -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
bind -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
bind -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'
```

This is the tmux side of the vim-tmux-navigator integration (the Neovim side is covered in §4.14). The `is_vim` shell command checks whether the active process in the current pane is Neovim or fzf. If it is, `Ctrl-h/j/k/l` is passed through to that process. If it is not, tmux handles the keystroke as a pane navigation command.

The result: `Ctrl-h` always means "move left" regardless of whether you are in a shell pane or inside Neovim. The same four keys navigate everywhere.

> [!warning] `Ctrl-l` conflict `Ctrl-l` is the standard terminal shortcut to clear the shell screen. With vim-tmux-navigator, it becomes "move right" in shell panes. To clear the terminal screen, use `prefix Ctrl-l` — this passes `Ctrl-l` through tmux to the shell.

#### Window Navigation

```bash
bind -n M-1 select-window -t :1
bind -n M-2 select-window -t :2
bind -n M-3 select-window -t :3
bind -n M-4 select-window -t :4
```

`Alt-1` through `Alt-4` jump to windows by number without requiring the prefix key. In the standard sessionizer layout, `Alt-1` is always the editor window and `Alt-2` is always the services window. This makes window switching a single-chord motion.

#### Pane Splitting

```bash
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %
```

`|` for a vertical split and `-` for a horizontal split are more intuitive than the defaults (`%` and `"`). The `-c "#{pane_current_path}"` flag opens the new pane in the same directory as the current pane — not the session root directory. This is the expected behaviour when you split a pane inside a project subdirectory.

#### Config Reload

```bash
bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"
```

`prefix r` reloads `tmux.conf` and displays a confirmation message in the status bar. Use this after every `tmux.conf` change instead of restarting tmux.

---

### 4.6 Mouse Mode: Who Owns Mouse Events

With `mouse on`, three programs can receive mouse events inside a tmux session. Understanding who owns what prevents unexpected behaviour.

|Action|Owner|Effect|
|---|---|---|
|Click inside a Neovim pane|Neovim|Moves cursor to click position; tmux does not interfere|
|Click on a non-Neovim pane|tmux|Switches pane focus; the shell or program in that pane is unaffected|
|Click and drag a pane border|tmux|Resizes the pane|
|Scroll wheel inside Neovim|Neovim|Scrolls the buffer|
|Scroll wheel outside Neovim|tmux|Enters tmux scroll mode for that pane|
|`Shift`-click anywhere|WezTerm|Bypasses tmux entirely; selects text at the WezTerm level; copies to OS clipboard via WezTerm|

The practical guidance: use mouse clicks for pane focus switching and pane resizing. Use `Shift`-click for quick single-line text copies that you want in the OS clipboard immediately. Use the keyboard for all navigation inside Neovim.

---

### 4.7 Plugin Management

Tmux plugins are managed by **TPM** (tmux Plugin Manager). They are declared in `tmux.conf` using `set -g @plugin` lines and installed from inside tmux with TPM's install command (`prefix` + `I`). Three plugins are configured. This section explains each plugin's role.

#### The Three Declared Plugins

**Catppuccin** (`catppuccin/tmux`) provides a polished status bar that matches WezTerm's colour scheme, eliminating the colour seams described in §4.6. It replaces the manual hex colour settings in §4.5 with a theme-aware implementation. Full colour consistency mechanism: §4.7.

**vim-tmux-navigator** (`christoomey/vim-tmux-navigator`) enables the seamless `Ctrl-h/j/k/l` navigation between tmux panes and Neovim windows described in §4.5. The tmux side is configured in `tmux.conf`; the Neovim side requires a matching plugin declaration. Full Neovim integration: [5-Editors.md §10.14](5-Editors.md).

> [!note] **The `Ctrl-h/j/k/l` bindings will not work across pane–Neovim boundaries until you complete [5-Editors.md §10.14](5-Editors.md).** The tmux side is active now; the Neovim plugin is not installed until the Editors document. If cross-pane navigation appears broken in Neovim, this is why — continue to that section before debugging.

**tmux-yank** (`tmux-plugins/tmux-yank`) copies tmux copy-mode selections to the OS clipboard. Without it, text copied in tmux copy mode (`prefix [`) is only available in tmux's internal buffer — invisible to the browser, other applications, or Neovim's system clipboard register. Full clipboard integration: §4.8.

> [!note] **Why tmux-resurrect and tmux-continuum are not installed.** These plugins save and restore tmux session state across reboots. They are excluded because they conflict with the declarative recreation model: you recreate workspaces from the sessionizer script (Part 5), not from saved state. Saved state goes stale after crashes, produces conflicts after reboots, and introduces exactly the kind of unpredictable environment the stack is designed to prevent.

#### Managing Plugins After Setup

Plugins are declared at the bottom of `~/dotfiles/tmux/tmux.conf`:

```bash
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'catppuccin/tmux'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-yank'

run '~/.tmux/plugins/tpm/tpm'
```

To add a plugin: add a `set -g @plugin` line, reload the config with `prefix r`, then install with `prefix + I` (capital I).

To remove a plugin: delete the `set -g @plugin` line, reload with `prefix r`, then uninstall with `prefix + alt + u`.

To update plugins: `prefix + U` from inside tmux.

---

### 4.8 Clipboard Integration — The Three-Way Problem

By default, Neovim, tmux, and the OS clipboard are three separate systems that do not communicate. A developer who does not configure this will be confused when `yy` in Neovim cannot be pasted into the browser, and when text copied in tmux copy mode cannot be pasted into Neovim.

The complete solution connects all three.

#### Step 1: Identify Your Display Server

```bash
echo $XDG_SESSION_TYPE
```

Output will be `x11` or `wayland`. This determines which clipboard provider to use.

#### Step 2: Confirm the Clipboard Provider Is Installed

Home Manager installs the correct provider based on your `home.nix` configuration. Verify:

```bash
# For X11:
which xclip

# For Wayland:
which wl-copy
```

If either command returns `not found`, add the missing package to `home.nix` packages (`pkgs.xclip` for X11, `pkgs.wl-clipboard` for Wayland) and run `hms`.

#### Step 3: Tmux Clipboard Setting

Add to `tmux.conf`:

```bash
set -g set-clipboard on
```

This tells tmux to interact with the OS clipboard via OSC 52 (a terminal escape sequence that WezTerm supports natively). With this setting, tmux copy mode selections are accessible to the OS clipboard.

tmux-yank (§4.7) handles the copy-mode → OS clipboard direction more reliably than `set-clipboard` alone. Both settings are recommended together.

#### Step 4: Neovim Clipboard Setting

Add to `~/dotfiles/nvim/lua/config/options.lua`:

```lua
vim.opt.clipboard = "unnamedplus"
```

This makes Neovim's `y` (yank) and `p` (paste) operations use the OS clipboard register (`+`) by default. Without this, Neovim yanks go to Neovim's internal registers, which are invisible to tmux and the browser.

#### End-to-End Verification

After all four steps:

```bash
# Test 1: Neovim → browser
# In Neovim: yy (yank a line)
# In browser: Ctrl+V — should paste the line

# Test 2: tmux copy mode → Neovim
# In tmux: prefix [ to enter copy mode
# Select text with v, copy with y
# In Neovim: p — should paste the text

# Test 3: Browser → Neovim
# In browser: Ctrl+C to copy text
# In Neovim (insert mode): Ctrl+Shift+V or p — should paste
```

If Test 1 fails: confirm `vim.opt.clipboard = "unnamedplus"` is set and that `xclip` or `wl-copy` is installed.

If Test 2 fails: confirm tmux-yank is installed (`ls ~/.tmux/plugins/tmux-yank/`) and that `set -g set-clipboard on` is in `tmux.conf`.

---

### 4.9 Keybinding Reference

The complete daily-use keybinding table. `prefix` means `C-Space` followed by the next key.

|Keys|Action|
|---|---|
|`Ctrl-h` / `Ctrl-j` / `Ctrl-k` / `Ctrl-l`|Move between panes (and Neovim windows)|
|`prefix \|`|New vertical split in current directory|
|`prefix -`|New horizontal split in current directory|
|`prefix [`|Enter copy mode (scroll, search, select, copy)|
|`prefix r`|Reload `tmux.conf`|
|`Alt-1` / `Alt-2` / `Alt-3` / `Alt-4`|Jump to window by number|
|`Ctrl-f`|Open sessionizer project picker|
|`prefix d`|Detach from session (session keeps running)|
|`prefix $`|Rename current session|
|`prefix ,`|Rename current window|
|`prefix c`|New window|
|`prefix &`|Kill current window|
|`prefix x`|Kill current pane|
|`prefix r`|Reload tmux config (after `hms`)|

**Copy mode keys** (after `prefix [`):

|Keys|Action|
|---|---|
|`v`|Begin selection|
|`y`|Copy selection to OS clipboard (via tmux-yank)|
|`Ctrl-v`|Toggle rectangle selection|
|`q` or `Escape`|Exit copy mode|
|`/`|Search forward|
|`?`|Search backward|

---

### 4.10 How to Change or Add Settings

The workflow for any `tmux.conf` change:

```bash
# 1. Edit
nvim ~/dotfiles/tmux/tmux.conf

# 2. Apply (no restart required — active sessions update immediately)
# Press prefix r inside any tmux pane

# 3. Verify — the status bar briefly shows "Config reloaded"

# 4. Commit
cd ~/dotfiles
git add tmux/tmux.conf
git commit -m "chore: describe what changed and why"
git push
```

To add a new keybinding, follow the `bind` syntax used in the existing config. Example — binding `prefix e` to open a new window named "scratch":

```bash
bind e new-window -n "scratch"
```

To add a new plugin, follow the pattern in §4.7.

---

### 4.11 Gotchas

Each gotcha: symptom, cause, resolution.

---

**Escape in Neovim feels laggy or registers incorrectly**

_Symptom:_ Pressing Escape to exit insert mode has a noticeable delay of around half a second. Occasionally the mode change registers with a stray character.

_Cause:_ `escape-time` is not set to 0, or is set to a non-zero value.

_Resolution:_ Verify `set -sg escape-time 0` is in `tmux.conf`. Reload with `prefix r`. If the setting is present but the lag persists, run `tmux show-options -g escape-time` — the output must show `0`, not `500`.

---

**Neovim colour scheme looks washed out or wrong**

_Symptom:_ Neovim themes use muted, approximated colours instead of the expected vibrant ones. Specific colours — reds, greens, certain blues — look wrong.

_Cause:_ True colour is not passing through from WezTerm to Neovim. Either the two required tmux lines are missing, or one of them is incorrect.

_Diagnosis:_

```bash
# Inside Neovim:
:checkhealth
# Look for a warning about termguicolors
```

_Resolution:_ Verify both lines are present exactly as shown in §4.4. Reload with `prefix r`. If the issue persists, check WezTerm's `term` setting (§4.3) — if it is set to a value other than `"wezterm"` or `"xterm-256color"`, the capability chain may be broken.

---

**direnv does not activate in new tmux panes**

_Symptom:_ Opening a new tmux pane or creating a new window in a project directory does not activate the devenv environment. `which python` shows a system path instead of a `/nix/store/...` path.

_Cause:_ The `eval "$(direnv hook zsh)"` line in `home.nix` programs.zsh.initContent is positioned too late in the shell initialisation sequence. tmux fires the initial window command before the shell finishes loading, and if the direnv hook is not loaded yet, it never fires for that pane.

_Resolution:_ In `home.nix`, move `eval "$(direnv hook zsh)"` to position 3 in `programs.zsh.initContent` — after PATH additions and Nix profile sourcing, before zoxide and fzf. The correct shell config load order is covered in §7.4.

---

**`Ctrl-l` no longer clears the terminal**

_Symptom:_ Pressing `Ctrl-l` in a shell pane does nothing or switches to the right pane instead of clearing the screen.

_Cause:_ vim-tmux-navigator binds `Ctrl-l` to "move right." This binding is active in shell panes as well as Neovim panes.

_Resolution:_ Use `prefix Ctrl-l` to send `Ctrl-l` through tmux to the shell. This is a one-time adjustment — after a few days it becomes automatic.

---

**Colour seams visible at pane borders**

_Symptom:_ A thin visible line appears between panes, or the tmux status bar background does not match the terminal background.

_Cause:_ The Catppuccin colour values in `tmux.conf` do not match WezTerm's `color_scheme`. This can happen if you manually edited the hex colours without updating WezTerm, or if you switched WezTerm themes without updating tmux.

_Resolution:_ Ensure `color_scheme = "Catppuccin Mocha"` in `wezterm.lua` and that the Catppuccin tmux plugin is active (declared in `tmux.conf` via TPM). If you are using a custom colour scheme, update both files simultaneously with matching hex values. Full mechanism: §4.7.

---

### Part 4 Summary

tmux is the persistent workspace layer. Sessions outlive terminal windows, survive WezTerm restarts, and keep long-running processes alive. This is what makes WezTerm disposable — closing it never kills anything.

The two TERM/colour lines in `tmux.conf` (`set -g default-terminal` and `set -ga terminal-overrides`) are the bridge between WezTerm's colour capabilities and what Neovim sees. Getting them wrong produces the most common rendering complaints.

The direnv-in-new-panes problem (§4.11) is the most common post-install surprise. If new tmux panes don't activate your project environment, the fix is the `initContent` load order in `home.nix` — direnv hook must be position 3, not position 7.

**What carries forward:** Part 5 adds the sessionizer — the script that turns tmux sessions into declarative, one-keypress workspaces. It builds directly on the session model you now understand.

---

### Complete `tmux.conf` Reference

Complete annotated configuration. Save to `~/dotfiles/tmux/tmux.conf`. Home Manager symlinks it to `~/.config/tmux/tmux.conf` via `home.file.mkOutOfStoreSymlink`. Reload with `prefix r` after any change.

```bash
# ~/dotfiles/tmux/tmux.conf

# ── Prefix key ───────────────────────────────────────────────────────────────
# C-Space: doesn't conflict with Neovim (C-a = increment number)
# or readline (C-a = beginning-of-line). Easy thumb reach.
set -g prefix C-Space
unbind C-b
bind C-Space send-prefix

# ── Terminal and true colour ─────────────────────────────────────────────────
# BOTH lines are required. The first sets what tmux advertises to inner
# programs. The second passes the Tc (true-colour) capability through to the
# outer terminal (WezTerm). One without the other = washed-out Neovim themes.
# See §3.7 and §3.8 for the full explanation.
#
# ACTION: uncomment the line that matches your wezterm.lua term setting.
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",wezterm:Tc"        # if term = "wezterm"   ← default
# set -ga terminal-overrides ",xterm-256color:Tc" # if term = "xterm-256color"

# ── Window and pane numbering ────────────────────────────────────────────────
# Start at 1 (not 0): 1 is on the left of the keyboard, 0 is on the right.
# Alt-1, Alt-2, Alt-3 for window jumping is ergonomic.
set -g base-index 1
set -g pane-base-index 1
set-window-option -g pane-base-index 1
# Prevent gaps: closing window 2 of [1,2,3] gives [1,2] not [1,3]
set -g renumber-windows on

# ── Behaviour ────────────────────────────────────────────────────────────────
# tmux manages its own scrollback separately from WezTerm
set -g history-limit 50000

# CRITICAL for Neovim: default 500ms delay makes Escape feel laggy.
# Without this, every mode exit in Neovim has a half-second pause.
set -sg escape-time 0

# Required for Neovim autoread: tmux must forward FocusGained/FocusLost events.
# Without this, switching panes does not trigger buffer auto-reload in Neovim.
set -g focus-events on

# Mouse: click-to-focus and scroll. Use Shift-click to bypass tmux for
# WezTerm-level clipboard copies (see §4.8 in 3-Terminal.md).
set -g mouse on

# Prevent tmux from renaming windows to the running command.
# The sessionizer names windows explicitly ("editor", "services", "git").
set -g automatic-rename off
set -g allow-rename off

# Required for tmux-yank to write to OS clipboard
set -g set-clipboard on

# ── Status bar ───────────────────────────────────────────────────────────────
# Catppuccin Mocha colours — must match WezTerm's color_scheme to prevent
# visible seams at pane borders. See §4.7 in 3-Terminal.md.
# The Catppuccin TPM plugin (§4.7) will override most of this with a
# more polished version — these values serve as the fallback.
set -g status-position bottom
set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
set -g status-left "#[fg=#89b4fa,bold] #S  "
set -g status-left-length 30
set -g status-right "#[fg=#6c7086] %H:%M "
set -g window-status-format "#[fg=#6c7086] #I:#W "
set -g window-status-current-format "#[fg=#cba6f7,bold] #I:#W "

# ── Pane borders ─────────────────────────────────────────────────────────────
set -g pane-border-style "fg=#313244"
set -g pane-active-border-style "fg=#cba6f7"

# ── Pane navigation: vim-tmux-navigator ──────────────────────────────────────
# Ctrl-h/j/k/l moves between panes AND Neovim windows seamlessly.
# The is_vim check detects whether the active pane is running Neovim or fzf;
# if so, the keystroke is passed through to that program instead.
# Requires the vim-tmux-navigator plugin in Neovim (see 5-Editors.md Part 10).
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"

bind -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
bind -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
bind -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
bind -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'

# ── Window navigation ─────────────────────────────────────────────────────────
# Alt+number: jump to window without prefix. No conflict with Neovim.
bind -n M-1 select-window -t :1
bind -n M-2 select-window -t :2
bind -n M-3 select-window -t :3
bind -n M-4 select-window -t :4

# ── Sessionizer binding ───────────────────────────────────────────────────────
# Ctrl-f: open sessionizer project picker from anywhere in tmux, no prefix
bind -n C-f display-popup -E "~/.local/bin/sessionizer"

# ── Pane splitting ────────────────────────────────────────────────────────────
# | for vertical split, - for horizontal — more intuitive than defaults.
# -c "#{pane_current_path}" opens the new pane in the current directory.
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# ── Copy mode ─────────────────────────────────────────────────────────────────
# Vi-style copy mode. tmux-yank (TPM plugin) handles OS clipboard integration.
set-window-option -g mode-keys vi
bind -T copy-mode-vi v   send-keys -X begin-selection
bind -T copy-mode-vi y   send-keys -X copy-pipe-and-cancel
bind -T copy-mode-vi C-v send-keys -X rectangle-toggle

# ── Config reload ─────────────────────────────────────────────────────────────
bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"

# ── TPM plugins ───────────────────────────────────────────────────────────────
# To add a plugin: add set -g @plugin line, reload with prefix r, then prefix+I.
# tmux-resurrect and tmux-continuum are intentionally excluded —
# they conflict with the declarative sessionizer model (§5.1).
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'catppuccin/tmux'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-yank'

# TPM entry point — must be the last line in this file
run '~/.tmux/plugins/tpm/tpm'
```

---

## Part 5: The Sessionizer — Declarative Workspace Management

> [!note] **What you now know**
> tmux is configured, plugins are installed, colour is consistent with WezTerm, and you understand the session → window → pane model. Part 5 builds on this: the sessionizer turns tmux sessions into declarative, one-keypress project workspaces.

---

> [!note] **What you will understand by the end of this part**
> - The declarative principle: why recreating a workspace from a script is better than saving and restoring state
> - How the sessionizer combines fzf + zoxide + tmux into a one-keypress project switcher
> - The three standard layouts (code, ops, writing) and how to extend them for your own projects
> - How to install, test, and customise the sessionizer script

The sessionizer is a shell script that turns project switching into a single keypress. Press `Ctrl-f` from anywhere in tmux, fuzzy-type a partial project name, press Enter, and you are in a tmux session rooted at that project directory. If the session already exists, you switch to it instantly (under a second). If it is new, it is created in the project root in about two seconds.

The script installed by the bootstrap is deliberately minimal: it handles discovery, naming, creation, and switching without imposing a full workspace layout system. §5.5 walks through it. Sections §5.2–§5.4 describe the layout concepts you can add to it: three patterns (code, ops, writing) for automatically opening Neovim, docker logs, and AI tools when a new session is created. These are extensions, not pre-installed behaviour.

This part covers the philosophy behind the sessionizer, the layout patterns you can build into it, and how to install and test it.

---

### 5.1 The Declarative Principle: Recreate, Never Save

The sessionizer operates on one principle: **you never save tmux state. You recreate workspaces from a script.**

This is a deliberate rejection of session-persistence plugins like tmux-resurrect. Those plugins save the current tmux state to disk and restore it on reboot. The approach sounds convenient until you encounter its failure modes: saved state goes stale after a crash, produces conflicts after a hard reboot, and accumulates windows and panes from sessions you no longer use. The restored environment is not the environment you intended — it is a snapshot of whatever state happened to exist at the moment of the last save.

The sessionizer avoids all of this by making recreation cheaper than restoration. A session is always created from scratch by a deterministic script. Every session named `mipapelera` is identical: same windows, same pane layout, same startup commands. If a session is broken, you kill it and recreate it. The recreation takes two seconds and produces a known-good state.

> [!tip] The practical consequence When something goes wrong in a session — a pane is accidentally closed, a window is in the wrong state — the correct response is never to try to repair the session manually. Kill the session with `tmux kill-session -t session-name` and press `Ctrl-f` to let the sessionizer recreate it. Two seconds, clean state.

---

### 5.2 What the Sessionizer Does

The sessionizer is a bash script bound to `Ctrl-f` in `tmux.conf` using `display-popup -E`. The popup gives fzf a real terminal to render in — without it, fzf has no TTY and exits silently. When invoked:

```
Ctrl-f pressed (from anywhere in tmux)
        ↓
tmux opens a popup window
        ↓
fzf appears listing immediate subdirectories of each configured search path
        ↓
You fuzzy-type a partial name and press Enter
        ↓
Does a tmux session with this name already exist?
  YES → switch-client to the existing session (under 1 second)
  NO  → create a new session rooted at the selected directory
      → switch-client to the new session (under 1 second)
```

The session name is derived from the directory's basename with spaces and dots replaced by underscores. `~/projects/my-app` becomes `my-app`. `~/projects/achemex.mx` becomes `achemex_mx`.

> [!important] **The popup shell does not inherit your Nix profile.** `fzf` lives in `~/.nix-profile/bin`, which is not in the popup's default PATH. The sessionizer script sources the Nix profile at startup to ensure `fzf` is found. Do not remove those two lines from the top of the script.

---

### 5.3 The Three Standard Layouts

The sessionizer detects project type from the contents of the selected directory and applies the matching layout. Every layout creates named windows so `Alt-1`, `Alt-2`, `Alt-3` always jump to the same roles.

#### The `code` Layout

Used for: Python projects, JavaScript/TypeScript projects, ERPNext/Frappe, FastAPI, any general software development.

Detected by: presence of `devenv.nix`, `pyproject.toml`, `package.json`, or `Cargo.toml`.

```
Window 1 "editor":
┌──────────────────────────┬─────────────────────┐
│                          │                     │
│   Neovim (60%)           │   shell (40%)       │
│   nvim .                 │                     │
│                          ├─────────────────────┤
│                          │   shell (40% of     │
│                          │   right column)     │
└──────────────────────────┴─────────────────────┘

Window 2 "services":
┌──────────────────────────────────────────────────┐
│   docker compose logs -f                         │
│   (or "[no compose file]" if none exists)        │
└──────────────────────────────────────────────────┘
```

**Window 1 "editor"** is where you spend most of your time. Neovim occupies 60% of the width on the left. The right column splits into two shell panes — the upper pane (60% of the right column height) for commands you want visible alongside the editor, the lower pane (40%) for a second context. Quick commands — `just fmt`, `git status`, running a single test — run here without switching windows.

**Window 2 "services"** tails `docker compose logs -f` immediately on creation. If no `docker-compose.yml` exists in the project root, it prints `[no compose file]` and leaves a shell ready. You switch to this window with `Alt-2` when you need to watch service output.

#### The `ops` Layout

Used for: Ansible playbooks, infrastructure repositories, Terraform, anything where you are primarily running commands and inspecting output rather than editing code in a tight loop.

Detected by: presence of `docker-compose.yml` or `docker-compose.yaml` (without the code-layout markers listed above).

```
Window 1 "config":
┌──────────────────────────────────────────────────┐
│   Neovim (full width)                            │
│   nvim .                                         │
└──────────────────────────────────────────────────┘

Window 2 "shells":
┌────────────────┬────────────────┬────────────────┐
│   shell 1      │   shell 2      │   shell 3      │
│                │                │                │
└────────────────┴────────────────┴────────────────┘
```

**Window 1 "config"** opens Neovim full-width. Infrastructure files — YAML, TOML, HCL — benefit from the extra horizontal space for long lines and nested structures.

**Window 2 "shells"** provides three equal-width shell panes. Typical use: one for running the playbook or command, one for watching logs or output, one for auxiliary commands. Switch with `Alt-2`.

#### The `writing` Layout

Used for: documentation projects, Markdown files, notes, any directory without code markers.

Detected by: fallback when no code or ops markers are found. Can also be forced with a `.workspace-writing` marker file (§5.4).

```
Window 1 "main":
┌──────────────────────────┬─────────────────────┐
│                          │                     │
│   Neovim (55%)           │   shell (45%)       │
│   markdown files         │                     │
│                          │                     │
└──────────────────────────┴─────────────────────┘
```

A single window with Neovim on the left and a shell pane on the right. No services window — writing projects rarely need background service monitoring.

---

### 5.4 Project Type Detection

The sessionizer detects project type by checking for specific files in the selected directory. The checks run in priority order — the first match wins.

|Check|Project type assigned|
|---|---|
|`devenv.nix`, `pyproject.toml`, `package.json`, `Cargo.toml` present|`code`|
|`docker-compose.yml` or `docker-compose.yaml` present|`ops`|
|`.workspace-code` marker file present|`code` (forced)|
|`.workspace-writing` marker file present|`writing` (forced)|
|None of the above|`writing` (fallback)|

**The marker file approach.** For projects that do not match the standard heuristics, create a marker file in the project root:

```bash
# Force the code layout for a project without standard code markers:
touch .workspace-code

# Force the writing layout for a code project you want a quieter layout for:
touch .workspace-writing
```

Marker files take the guesswork out of detection for unusual project structures. They are safe to commit — they have no effect on tools other than the sessionizer.

**Extending detection for new project types.** The sessionizer script uses a simple `if/elif` chain. Adding a new condition follows the same pattern as the existing ones. For example, adding ERPNext/Frappe detection:

```bash
# In the detection block, before the fallback:
elif [ -f "$selected/apps.json" ] || [ -d "$selected/apps/frappe" ]; then
  project_type="code"
```

Full instructions for adding a new layout type are in §5.7.

---

### 5.5 Full Annotated Script Walkthrough

The sessionizer in `~/dotfiles/scripts/sessionizer` is deliberately small and explicit. Understanding each block tells you where to extend it when your workflow grows beyond the basics.

#### The Complete Script

```bash
#!/usr/bin/env bash
# sessionizer — tmux project switcher

set -euo pipefail

# Popup shells do not always load the Nix profile. Source it so fzf is available.
. "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true
export PATH="$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH"

SEARCH_PATHS=(
    "$HOME/projects"
    "$HOME/dotfiles"
)

find_args=()
for path in "${SEARCH_PATHS[@]}"; do
    if [ -d "$path" ]; then
        find_args+=("$path")
    fi
done

if [ ${#find_args[@]} -eq 0 ]; then
    echo "sessionizer: no search paths found" >&2
    exit 1
fi

selected=$( \
    find "${find_args[@]}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sort \
    | fzf --prompt="project: " --height=40% --reverse \
    || true \
)

if [ -z "$selected" ]; then
    exit 0
fi

session_name=$(basename "$selected" | tr ' .' '_')

if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -ds "$session_name" -c "$selected"
fi

if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$session_name"
else
    tmux attach-session -t "$session_name"
fi
```

#### Block 0: Nix Profile Sourcing

```bash
. "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true
export PATH="$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH"
```

The popup shell launched by `display-popup` does not run `.zshrc` or `.profile`. It is a minimal bash shell with the system PATH. `fzf` is in `~/.nix-profile/bin`, which is not in that PATH. These two lines source the Nix profile and prepend its bin to PATH, making `fzf` available for the rest of the script.

#### Block 1: Directory Discovery and Selection

```bash
selected=$( \
    find "${find_args[@]}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sort \
    | fzf --prompt="project: " --height=40% --reverse \
    || true \
)

if [ -z "$selected" ]; then
    exit 0
fi
```

`find` lists every immediate subdirectory of each existing path in `SEARCH_PATHS` and pipes the sorted list to `fzf`. `-mindepth 1` excludes the search root itself; `-maxdepth 1` limits to direct children — enough for a flat project layout.

The `|| true` keeps `set -e` from exiting the script before cleanup when the user presses Escape or `Ctrl-c`. The empty-selection check then exits cleanly without creating a session.

**To search deeper or add more locations:** extend the `find` command:

```bash
# Also scan ~/work:
SEARCH_PATHS+=("$HOME/work")
```

#### Block 2: Session Naming

```bash
session_name=$(basename "$selected" | tr ' .' '_')
```

The session name is the directory basename with spaces and dots replaced by underscores. This produces stable, predictable names: `~/projects/achemex.mx` becomes `achemex_mx`. The name is used for both `tmux has-session` (checking if it exists) and `tmux new-session -s` (creating it) — consistent naming is what makes the "switch to existing session" path work.

#### Block 3: Session Creation and Switch

```bash
if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -ds "$session_name" -c "$selected"
fi

tmux switch-client -t "$session_name"
```

If the session does not yet exist, `new-session -d` creates it in the background (detached, without switching to it). The `-c "$selected"` flag sets the session's starting directory to the project root — this is what triggers direnv when the first shell starts, activating the devenv environment automatically.

`switch-client` then moves the client to the session, whether newly created or pre-existing. Pressing `Ctrl-f` for a project you are already working in takes under one second: `has-session` returns true, `new-session` is skipped, and `switch-client` is immediate.

**Extending with layouts.** The point after `new-session` and before `switch-client` is where you add multi-window setup. For example, to open Neovim automatically in every new session:

```bash
if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -ds "$session_name" -c "$selected"
    tmux send-keys -t "$session_name" "nvim ." Enter
fi

tmux switch-client -t "$session_name"
```

The layout concepts in §5.2–§5.4 (code layout, ops layout, project type detection) describe patterns for extending this block into a full workspace automation system.

---

### 5.6 Installation

**Where the script comes from.** In §M.7 of the installation guide, you copied `templates/sessionizer` from `workstation-scripts` into `~/dotfiles/scripts/sessionizer`. That file is the live script — edit it there when you want to change search paths or layouts.

**What the bootstrap did with it.** During Step 9, the bootstrap ran:

```bash
chmod +x ~/dotfiles/scripts/sessionizer
ln -sf ~/dotfiles/scripts/sessionizer ~/.local/bin/sessionizer
```

This creates a symlink: `~/.local/bin/sessionizer` → `~/dotfiles/scripts/sessionizer`. The script lives in your dotfiles (version-controlled, editable), and the symlink puts it on your `$PATH`. When you edit `~/dotfiles/scripts/sessionizer`, the change is live immediately — no reinstall step needed.

**The tmux binding** in `tmux.conf` uses `display-popup -E` (not `run-shell`) so fzf has a real terminal to render in:

```
bind -n C-f display-popup -E "~/.local/bin/sessionizer"
```

> [!important] Do not use `run-shell` for the sessionizer. `run-shell` executes the script in the background without a TTY. fzf requires a TTY to display its interface and will exit silently if one is not available. `display-popup -E` opens a proper terminal popup.

Verify the full installation chain before first use:

```bash
# 1. Script is executable and on PATH
which sessionizer
```

Expected output: `/home/yourusername/.local/bin/sessionizer`

```bash
# 2. Script is the symlink to your dotfiles
readlink ~/.local/bin/sessionizer
```

Expected output: `/home/yourusername/dotfiles/scripts/sessionizer`

```bash
# 3. Test the script manually before relying on the tmux binding
sessionizer
```

fzf should open with your project directories. Select one and press Enter. A new tmux session should be created with the correct layout. If this works, the `Ctrl-f` binding will work automatically.

**If `sessionizer` is not found:**

```bash
echo $PATH | tr ':' '\n' | grep local
```

If `~/.local/bin` is not in the output, it is not on your `$PATH`. Add it to `home.nix` `programs.zsh.initContent`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then run `hms` and open a new shell.

---

### 5.7 How to Add a New Project Type

Adding a new project type requires three changes to the sessionizer script, all in `~/dotfiles/scripts/sessionizer`:

**Step 1: Add a detection condition** to the `if/elif` chain in the detection block. Add it before the final `else` (writing fallback):

```bash
elif [ -f "$selected/your-marker-file" ]; then
  project_type="your-type"
```

**Step 2: Add a layout block** to the `case` statement, following the pattern of the existing layouts:

```bash
your-type)
  tmux rename-window -t "$session_name:1" "your-window-name"
  # Add panes, send startup commands, create additional windows
  # as needed. Follow the pattern from the code or ops blocks.
  ;;
```

**Step 3: Test** by running `sessionizer` from the command line (not via `Ctrl-f`), selecting the new project type, and verifying the layout is created correctly. Debug with `tmux list-panes -t "$session_name"` to inspect the pane structure.

**Step 4: Commit:**

```bash
cd ~/dotfiles
git add scripts/sessionizer
git commit -m "feat: add your-type layout to sessionizer"
git push
```

**Example: Adding an ERPNext/Frappe layout** that opens bench commands alongside Neovim:

```bash
# Detection — add before the final else:
elif [ -f "$selected/apps.json" ] || [ -d "$selected/apps/frappe" ]; then
  project_type="erpnext"

# Layout block — add to the case statement:
erpnext)
  tmux rename-window -t "$session_name:1" "editor"
  tmux split-window -t "$session_name:editor" -h -p 40 -c "$selected"
  tmux split-window -t "$session_name:editor.2" -v -p 40 -c "$selected"

  tmux new-window -t "$session_name" -n "bench" -c "$selected"
  tmux send-keys -t "$session_name:bench" \
    "cd frappe-bench && bench start 2>/dev/null || echo '[no frappe-bench]'" Enter

  tmux select-window -t "$session_name:editor"
  tmux select-pane -t "$session_name:editor.1"
  tmux send-keys -t "$session_name:editor.1" "nvim ." Enter
  ;;
```

---

### Part 5 Summary

The sessionizer embodies a single principle: recreate, never restore. A workspace is defined by a script that can rebuild it in two seconds from scratch. This means there is no state to corrupt, no persistence plugin to maintain, and no session database to lose.

The three layouts (code, ops, writing) cover the three modes of work. Each layout is a set of tmux `send-keys` calls — readable, editable, and extensible without learning any new API. Adding a new project type means adding a new `elif` branch and committing it.

> [!tip] If a pane is accidentally closed and the layout feels wrong, do not try to repair it manually. Kill the session with `tmux kill-session -t session-name` and press `Ctrl-f` to let the sessionizer recreate it cleanly.

**What carries forward:** Part 6 covers Nerd Fonts — the prerequisite for all the icons and Powerline separators that the WezTerm, tmux, and Neovim layers use.

---

## Part 6: Nerd Fonts — Making the Terminal Render Correctly

> [!note] **What you now know**
> The sessionizer is installed and bound to `Ctrl-f`. You can switch between any project in two seconds and recreate a broken workspace cleanly. Part 6 covers the font layer that makes icons and Powerline separators render correctly.

---

> [!note] **What you will understand by the end of this part**
> - Why Nerd Fonts exist and what breaks without them (icons, Powerline separators, language glyphs)
> - How font installation works on Ubuntu and how the bootstrap automated it
> - How to verify correct rendering and how to switch fonts if you prefer a different one

Nerd Fonts are a prerequisite for the visual layer of this stack — tmux status bar, Neovim file explorer, git branch indicators — to render correctly. This part explains what they are, why installation is automated, and how to switch to a different font if you prefer one.

---

### 6.1 What Nerd Fonts Are and Why They Are Required

A Nerd Font is a standard programming font that has been patched with thousands of additional glyphs from several icon sets. The additions that matter for this stack:

|Glyph category|Where you see them|
|---|---|
|Powerline symbols|Angled separators between sections in the tmux status bar|
|File-type icons|Folder and language icons in Neovim's file explorer (neo-tree)|
|Box-drawing characters|Pane borders, window chrome throughout tmux and Neovim UI|
|Git branch indicators|Branch name symbols in the tmux status bar and Starship prompt|
|Devicon glyphs|Language-specific icons in Neovim's statusline and bufferline|

Without a Nerd Font installed _and_ selected in WezTerm, every one of these renders as a box (`□`), a question mark, or a missing-character placeholder. The tools still function — LSP, formatting, git operations all work regardless — but the visual layer is broken in a way that is immediately obvious and distracting.

The font must satisfy two conditions simultaneously:

1. **Installed at the OS level** — in `~/.local/share/fonts/` and registered with `fc-cache`
2. **Selected in WezTerm** — `font = wezterm.font("JetBrainsMono Nerd Font")` in `wezterm.lua`

If either condition is missing, glyphs do not render. A common failure mode is having the font installed but using the wrong family name in `wezterm.lua` — the font renders as a fallback and icons appear as boxes.

---

### 6.2 Why the Bootstrap Handles This

Font installation is a fully automatable sequence of file operations: download a zip, unzip into the correct directory, run `fc-cache`. There is no interactive step, no decision to make, and no variation between machines. Making it a manual step would guarantee it gets skipped at least once — typically on a new machine setup where there are many steps to complete and this one seems minor until the terminal opens and everything looks broken.

Home Manager handles this (§6.3), with two specific properties:

**Pinned version.** `nerd-fonts.jetbrains-mono` in `home.packages` is resolved against the nixpkgs version pinned by `flake.lock`. This means two machines running `hms` from the same flake revision install the same font files, regardless of when the switch is run.

**Idempotency.** `hms` only rebuilds the font symlink if the derivation output changed. On a re-run with no `flake.lock` changes, this step is a no-op.

If you ever need to verify the font installation manually:

```bash
fc-list | grep JetBrains
```

Expected output — one or more lines such as:

```
/home/yourusername/.local/share/fonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf: JetBrainsMono Nerd Font:style=Regular
```

If this returns nothing, the font is not registered. Re-run the font installation steps:

```bash
# Re-run font cache refresh
fc-cache -fv

# If still not found, verify the files exist
ls ~/.local/share/fonts/JetBrainsMono/ | grep JetBrains
```

If the directory is empty, Home Manager did not install the font. Run `hms` and check for errors, or download JetBrainsMono Nerd Font manually from `nerdfonts.com`, unzip to `~/.local/share/fonts/`, and run `fc-cache -fv`.

---

### 6.3 Switching to a Different Nerd Font

JetBrainsMono is the default because it has excellent legibility at small sizes, comprehensive glyph coverage, and clear distinction between similar characters (`0`, `O`, `o`; `1`, `l`, `I`). If you prefer a different font, any font from `nerdfonts.com` works — the stack has no dependency on JetBrainsMono specifically, only on any Nerd Font being present.

**Step 1: Download the new font**

Go to `nerdfonts.com`, find your preferred font, and download the zip. Example for FiraCode:

```bash
cd /tmp
curl -fLo FiraCode.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
```

**Step 2: Install the font files**

```bash
mkdir -p ~/.local/share/fonts/FiraCode
unzip /tmp/FiraCode.zip -d ~/.local/share/fonts/FiraCode/
fc-cache -fv
```

**Step 3: Find the exact family name**

The name you use in `wezterm.lua` must match the font's registered family name exactly — including capitalisation and spacing.

```bash
fc-list | grep -i fira
```

Look for the family name in the output. It will appear as the second field after the file path:

```
/home/you/.local/share/fonts/FiraCode/FiraCodeNerdFont-Regular.ttf: FiraCode Nerd Font:style=Regular
```

The family name here is `FiraCode Nerd Font`.

**Step 4: Update `wezterm.lua`**

```lua
-- In ~/dotfiles/wezterm/wezterm.lua:
font = wezterm.font("FiraCode Nerd Font"),
```

**Step 5: Reload and verify**

Press `SUPER+SHIFT+R` in WezTerm. The font changes immediately. Verify that Powerline symbols in the tmux status bar and file icons in Neovim render correctly as glyphs rather than boxes.

**Step 6: Commit**

```bash
cd ~/dotfiles
git add wezterm/wezterm.lua
git commit -m "chore: switch to FiraCode Nerd Font"
git push
```

> [!tip] Keeping the old font installed There is no reason to remove the previous font. Each font lives in its own subdirectory under `~/.local/share/fonts/` and they coexist without conflict. WezTerm uses whichever family name is specified in `wezterm.lua`. You can switch back by changing one line and pressing `SUPER+SHIFT+R`.

---

### Part 6 Summary

Nerd Fonts are a rendering prerequisite, not a cosmetic feature. The Home Manager declaration (`nerd-fonts.jetbrains-mono` in `home.nix`) handles download, installation, and `fc-cache` refresh automatically — no manual font management required. The Noto font package in `setup-desktop.sh` is the fallback that covers Unicode codepoints the Nerd Font omits.

Switching fonts is a one-line change in `wezterm.lua` plus a `SUPER+SHIFT+R` reload. The only constraint: the family name in `wezterm.lua` must exactly match the family name in `fc-list` output.

**What carries forward:** Part 7 covers fzf, zoxide, and the shell config load order — the support tools the sessionizer and interactive shell rely on.

---

## Part 7: Support Tools — Fzf, Zoxide, and the Shell Config

> [!note] **What you now know**
> JetBrainsMono Nerd Font is installed and verified. Icons render correctly in tmux, WezTerm, and Neovim. Part 7 covers fzf and zoxide — the tools the sessionizer depends on — and the shell init order that makes everything work together.

---

> [!note] **What you will understand by the end of this part**
> - Why fzf and zoxide are hard dependencies of the stack, not optional additions
> - The exact shell initialisation order that must be preserved — and what silently breaks when it isn't
> - How to configure fzf appearance, zoxide behaviour, and shell aliases inside `home.nix` safely

fzf and zoxide are not optional additions. fzf is a hard dependency of the sessionizer (Part 3) and powers `Ctrl-R` shell history search. zoxide replaces `cd` with a learned directory jumper that dramatically reduces typing once it has observed a few days of navigation patterns. Both are installed by Home Manager and both require shell integration lines in the correct position in `home.nix`.

This part covers what each tool does, how to configure it, and — most importantly — the exact order in which shell initialization lines must appear. Getting that order wrong is the most common source of subtle, hard-to-diagnose breakage in this stack.

---

### 7.1 Why These Tools Are Not Optional

**fzf** is used in three places in this stack:

1. **The sessionizer** (Part 3) — the project picker is an fzf interface. Without fzf, `Ctrl-f` produces nothing.
2. **`Ctrl-R` shell history search** — replaces the default reverse history search with an interactive fuzzy picker over the full shell history.
3. **lazygit** — uses fzf for several interactive file and branch selection interfaces.

**zoxide** is not a hard dependency of the sessionizer template, but after a few days of use it becomes functionally irreplaceable. Instead of typing `cd ~/projects/mi-papelera`, you type `z pap` and arrive at the same place in three keystrokes. If you later extend the sessionizer, zoxide's frecency database is a useful source for ranking or adding frequently visited directories.

Both are installed by Home Manager. Neither requires any configuration beyond the shell integration lines covered in §7.4.

---

### 7.2 Fzf: Fuzzy Finder

#### What Fzf Does

fzf takes any list on stdin and presents it as an interactive, real-time fuzzy filter. You type characters and the list narrows. You press Enter and the selected item goes to stdout. Every interactive picker in this stack — sessionizer, lazygit branch selection, `Ctrl-R` history — is fzf consuming a list from some source and returning the selection.

#### Installation

fzf is in `home.nix` packages (`pkgs.fzf`) and is installed by Home Manager. Verify:

```bash
fzf --version
```

#### Shell Key Bindings

Home Manager's `programs.fzf` module enables shell key bindings automatically when configured in `home.nix`. The bindings this enables:

|Key|Action|
|---|---|
|`Ctrl-R`|Fuzzy search over shell history|
|`Ctrl-T`|Fuzzy file picker, inserts selected path at cursor|
|`Alt-C`|Fuzzy `cd` into a subdirectory|

`Ctrl-R` is the one you will use constantly. It replaces the default reverse-incremental history search with a full-height fuzzy picker over your entire history. Type any fragment of a command you remember and it appears immediately.

#### Recommended `FZF_DEFAULT_OPTS`

These options configure fzf's appearance for every interface that uses it, including the sessionizer:

```bash
export FZF_DEFAULT_OPTS="
  --height 40%
  --layout=reverse
  --border
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
```

The colour values are Catppuccin Mocha, matching WezTerm and tmux. `--layout=reverse` puts the input prompt at the bottom and the list above it — the standard orientation for terminal pickers. `--height 40%` keeps the picker compact without covering the full terminal.

This goes in `home.nix` `programs.zsh.initContent`. The exact position in the init block is covered in §7.4.

#### Verification

```bash
# Basic picker test — should open an interactive list
echo -e "one\ntwo\nthree" | fzf

# History search — press Ctrl-R in your shell
# Should open a full fuzzy history picker, not the default reverse search
```

---

### 7.3 Zoxide: Smart Directory Jumper

#### What Zoxide Does

zoxide tracks every directory you visit and builds a frecency database — a score that combines frequency (how often) and recency (how recently). The `z` command jumps to the highest-scoring directory that matches your query. After a few days of use, `z pap` reliably jumps to `~/projects/mi-papelera` and `z ach` jumps to `~/work/achemex`.

`zi` opens an interactive fzf picker over all known directories — useful when the non-interactive `z` produces the wrong match.

#### Installation

zoxide is in `home.nix` packages (`pkgs.zoxide`) and is installed by Home Manager. Verify:

```bash
zoxide --version
```

#### Daily Usage

```bash
# Jump to the best match for a partial name
z pap         # → ~/projects/mi-papelera
z ach         # → ~/work/achemex
z dot         # → ~/dotfiles

# Interactive picker over all known directories
zi

# Add a directory to the database immediately (without cd-ing there)
zoxide add ~/projects/my-project

# Show the top matches for a query without jumping
zoxide query --list pap
```

#### Populating Zoxide on a New Machine

zoxide starts empty — it only knows directories you have visited since it was installed. On a fresh machine after the bootstrap, run `zoxide add` for your main project directories before the database builds up naturally:

```bash
zoxide add ~/projects
zoxide add ~/dotfiles
# Add any other directories you navigate to frequently
```

After a week of normal use, the database is populated and `z` becomes consistently useful.

> [!tip] zoxide and the sessionizer can work together The starter sessionizer scans fixed project roots from `SEARCH_PATHS`. If you want frecency-ranked results later, extend its discovery block with `zoxide query --list` and merge that list before opening `fzf`.

#### The `cd` Alias Ordering Warning

Some developers alias `cd` to `z` so that normal `cd` usage populates the zoxide database automatically:

```bash
alias cd='z'
```

If you use this alias, it must be defined _before_ `eval "$(zoxide init zsh)"` in your shell config. zoxide's init script checks whether `cd` is already aliased and adjusts its behaviour accordingly. If zoxide initialises first and finds no `cd` alias, then the alias is added afterward, the zoxide integration may not intercept `cd` correctly.

The correct shell load order, which handles this, is in §7.4.

---

### 7.4 Shell Config Load Order — The Most Common Source of Subtle Breakage

> [!important] Read this section even if the tools are already working Subtle ordering failures are often latent — everything seems fine until you add one more tool or change one line, at which point the interaction between two incorrectly ordered initializers produces a failure that looks like the new tool's fault but is actually an ordering problem that was always there.

Home Manager generates `~/.zshrc` from your `home.nix` configuration. You never edit `~/.zshrc` directly. All shell initialization — PATH additions, tool hooks, aliases — goes in `home.nix` `programs.zsh.initContent`. Home Manager places this block near the end of the generated `~/.zshrc`, after the Nix profile is sourced.

Within `initContent`, order matters. Here is the complete block in the correct order, with a one-sentence explanation of why each line must precede the next:

```bash
# In home.nix → programs.zsh.initContent:

# ── 1. PATH additions ─────────────────────────────────────────────────────────
# Must be first. Every tool initialized below needs its binary findable.
# ~/.local/bin holds the sessionizer symlink and any user-installed scripts.
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.nix-profile/bin:$PATH"

# ── 2. Nix environment ────────────────────────────────────────────────────────
# Sources the Nix profile, making nix-installed binaries available.
# Must come before any tool whose binary lives in the Nix store.
. "$HOME/.nix-profile/etc/profile.d/nix.sh"

# ── 3. direnv hook — must be early ───────────────────────────────────────────
# tmux fires its initial window command as soon as a pane shell starts,
# before .zshrc finishes loading. If direnv is initialized too late,
# the first pane in every new tmux session will not have direnv active,
# and devenv environments will not activate automatically on cd.
eval "$(direnv hook zsh)"

# ── 4. cd alias — must come before zoxide init ───────────────────────────────
# If you want `cd` to route through zoxide, define the alias HERE — before
# `eval "$(zoxide init zsh)"`. zoxide's init script checks whether `cd` is
# already aliased and adjusts its integration accordingly. Defining the alias
# after zoxide init means zoxide never intercepts it correctly.
alias cd='z'   # optional: remove this line if you prefer to use `z` explicitly

# ── 5. zoxide — must come after the cd alias ─────────────────────────────────
# zoxide init checks for an existing cd alias; if you alias cd=z,
# that alias must be defined before this line.
eval "$(zoxide init zsh)"

# ── 6. fzf options ───────────────────────────────────────────────────────────
# Shell key bindings (Ctrl-R, Ctrl-T, Alt-C) are injected automatically by
# Home Manager when programs.fzf.enableZshIntegration = true is set.
# Do NOT add `source ~/.fzf.zsh` manually — Home Manager generates and sources
# the integration file itself; the path may not exist for Nix-installed fzf.
export FZF_DEFAULT_OPTS="
  --height 40%
  --layout=reverse
  --border
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

# ── 7. Starship prompt — must be last ────────────────────────────────────────
# Starship wraps the shell prompt by modifying PS1/PROMPT.
# Any initializer that runs after starship and also modifies the prompt
# will silently overwrite Starship's output, breaking the prompt display.
eval "$(starship init zsh)"

# ── 8. Remaining aliases — after all tool inits ───────────────────────────────
# These aliases have no ordering sensitivity relative to each other,
# but must come after the tool inits they reference.
alias ls='eza --color=auto --icons'
alias cat='bat'
```

**The three ordering rules that cause the most problems when violated:**

**Direnv must be early (rule 3).** When tmux creates a new session with `tmux new-session -c ~/projects/my-project`, the shell that opens in that pane runs `.zshrc` from the beginning. If direnv is initialized near the end of `.zshrc` and tmux's initial window command fires before that point, direnv is not active for that pane. The environment never activates. `which python` shows a system path. The symptom is identical to not having run `direnv allow` — confusing if you have definitely run it.

**The `cd` alias must come before zoxide init (rule 4).** zoxide's init script detects whether `cd` is already aliased and configures its hook accordingly. If you define `alias cd='z'` after `eval "$(zoxide init zsh)"`, zoxide has already finished its setup and the alias is never intercepted. The `cd` command appears to work but does not populate the zoxide database, making zoxide less useful and weakening any future sessionizer extension that uses frecency ordering.

**Starship must be last (rule 7).** Starship modifies `PS1` (the prompt variable). Any subsequent initializer that also touches `PS1` — a version manager, another prompt tool, a shell framework — silently overwrites Starship's configuration. The symptom: the Starship prompt renders for a moment and then reverts to a plain prompt, or shows a garbled mix of Starship and another prompt format.

---

### 7.5 How to Add a New Shell Tool

Every shell tool that needs initialization follows the same pattern. No exceptions — editing `~/.zshrc` directly will be overwritten by the next `hms`.

**Step 1: Add the binary to `home.nix` packages**

```nix
home.packages = with pkgs; [
  # ... existing packages ...
  your-new-tool
];
```

**Step 2: Add the initialization line to `home.nix` programs.zsh.initContent**

Place it in the correct position per the load order in §7.4. If the tool modifies the prompt, it must go before Starship (rule 7). If it depends on PATH, it must go after PATH additions (rule 1). If it is a simple alias or export with no ordering sensitivity, place it in the aliases block at the end.

```nix
programs.zsh = {
  enable = true;
  initContent = ''
    # ... existing init lines in correct order ...
    eval "$(your-new-tool init zsh)"   # place at the correct position
  '';
};
```

**Step 3: Apply and verify**

```bash
hms
# Open a new shell (the current shell has the old .zshrc)
your-new-tool --version
```

**Step 4: Commit**

```bash
cd ~/dotfiles
git add home.nix
git commit -m "feat: add your-new-tool to shell config"
git push
```

> [!warning] Never edit `~/.zshrc` directly Home Manager overwrites `~/.zshrc` on every `hms`. Any change made directly to `~/.zshrc` will be silently lost. If you find yourself wanting to edit `~/.zshrc`, the correct action is to identify which `home.nix` block the change belongs in and make it there. The mapping is: packages → `home.packages`; initialization hooks and shell functions → `programs.zsh.initContent`; simple aliases (like `ls = "eza --icons";`) → `programs.zsh.shellAliases`.

---

### Part 7 Summary

fzf and zoxide are multipliers: fzf makes `Ctrl-R` history search fast enough to replace muscle-memory retyping; zoxide makes `z project` faster than any alias. Both are declared in `home.nix` and require no manual PATH management.

The shell init load order (§7.4) is the most consequential thing in this Part. The seven rules are not arbitrary — each has a specific dependency on what ran before it. Getting the order wrong produces silent breakage: tools that appear installed but behave incorrectly, completions that don't fire, or direnv that activates too late for tmux panes.

**What carries forward:** Part 8 covers Devenv — the per-project environment layer that Direnv activates when you `cd` into a project directory.

---
**Next:** [4-Projects.md — Project Environments](4-Projects.md)
