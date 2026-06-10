> **Development Workstation** · [Overview](0-Overview.md) · [Stack](1-Stack.md) · [Installation](2-Installation.md) · [Terminal](3-Terminal.md) · [Projects](4-Projects.md) · **Editors** · [Desktop](6-Desktop.md) · [Troubleshooting](7-Troubleshooting.md) · [Workflows](8-DevWorkflows.md)

## Part 10: Neovim with LazyVim — The "Project Owns Its Configuration" Philosophy

> [!note] **What you now know**
> Git is configured with delta, `gh` is authenticated, lazygit is available, and the three utility functions are in `home.nix`. Part 10 covers Neovim with LazyVim — the most complex part of the stack.

---

> [!note] **What you will understand by the end of this part**
> - The "project owns its config" principle: why LSP servers, formatters, and linters come from Devenv, not Mason
> - The four configuration vectors (LazyVim defaults, `plugins/`, `config/`, `.lazy.lua`) and when to use each
> - How to set up language support for Python, TypeScript, Lua, and YAML/TOML
> - How DAP debugging works and why `debugpy` cannot go in `devenv.nix packages`
> - How Neovim integrates with tmux (navigator) for seamless pane navigation

This is the largest section in the guide. It covers both the Neovim installation and the philosophy that governs how formatting, linting, LSP, and debugging work across the entire stack — including VS Code. The concepts introduced here apply equally to both editors.

---

### 10.1 What This Setup Achieves

A Neovim installation that:

- **Auto-formats on save** using the formatter the project has declared, at the version the project has pinned
- **Reports LSP diagnostics inline** from a language server running in the background
- **Runs linters on save** showing problems as underlines, without modifying the file
- **Supports step-through debugging** with breakpoints set in the editor, adapters discovered from `$PATH`
- **Requires zero per-project Neovim configuration** — a new developer clones a repository, runs `direnv allow` and `just setup`, and everything works

The zero-configuration property is not magic — it is the result of a deliberate architecture described in §10.5 and §10.6.

---

### 10.2 Why the Neovim Config Lives Outside Home Manager

Home Manager stores managed config files in the read-only `/nix/store`. LazyVim needs to write its plugin lock file (`lazy-lock.json`) and plugin data to `~/.config/nvim/` at runtime. If Home Manager symlinked `~/.config/nvim` into the Nix store, Neovim would crash immediately with a read-only filesystem error.

The solution is `config.lib.file.mkOutOfStoreSymlink` in `home.nix`:

```nix
# home.nix
home.file.".config/nvim".source =
  config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/nvim";
```

This tells Home Manager to create `~/.config/nvim` as a direct symlink to `~/dotfiles/nvim` — a mutable path outside the Nix store. LazyVim can write to it freely. The underlying config files are still version-controlled in your dotfiles repository.

> [!warning] The dotfiles path is hardcoded `mkOutOfStoreSymlink` requires an absolute path. Your Neovim config depends on `~/dotfiles/nvim` existing at exactly that location. Moving the dotfiles repository breaks the symlink until you run `hms` again with the updated path.

This is the documented pattern for mutable config files with Home Manager. It is not a workaround.

---

### 10.3 File Structure and Path Clarity

Every file in `~/dotfiles/nvim/` with its purpose, who writes it, and whether it should be committed:

```
~/dotfiles/nvim/
  init.lua                   # LazyVim entry point — do not edit directly
  lazyvim.json               # Enabled LazyExtras — commit this
  lazy-lock.json             # Plugin version lockfile — commit this
  lua/
    config/
      options.lua            # Global vim options (clipboard, etc.) — edit freely
      keymaps.lua            # Global keymaps — edit freely
      autocmds.lua           # Global autocommands — edit freely
    plugins/
      lsp.lua                # mason=false, server declarations — created in §10.11
      formatting.lua         # conform.nvim: filetype→binary + condition gates
      linting.lua            # nvim-lint: filetype→linter + condition guards
      dap.lua                # nvim-dap: adapter setup, load_launchjs()
      neoconf.lua            # neoconf.nvim plugin declaration
```

**`lazy-lock.json` and `lazyvim.json` must be committed.** `lazy-lock.json` records the exact commit hash of every installed plugin — committing it means every machine running `hms` and then `nvim --headless "+Lazy! sync" +qa` gets bit-for-bit identical plugin versions. `lazyvim.json` records which LazyExtras are enabled.

---

### 10.4 Installation

The bootstrap staged the LazyVim starter into `~/dotfiles/nvim/` (step 10) and ran the headless plugin sync (step 11). Opening Neovim for the first time should show a fully loaded LazyVim interface with no plugin installation in progress.

Run `:checkhealth` inside Neovim after first open. Look for:

- No `ERROR` lines — any error indicates a missing dependency
- `WARNING` lines for optional features are acceptable — read them but do not act on every one immediately
- Confirm `clipboard` is working (should show `xclip` or `wl-copy` as the provider)

If `:checkhealth` shows plugin errors, the headless sync may have failed silently. Run `:Lazy sync` to install missing plugins interactively.

---

### 10.5 The "Project Owns Its Configuration" Philosophy

_The conceptual foundation for everything that follows. Read this before touching any plugin config._

Two places where formatting, linting, and LSP rules can live:

1. **Inside your editor** (`~/dotfiles/nvim/lua/plugins/`)
2. **Inside the project** (`.editorconfig`, `pyproject.toml`, `devenv.nix`, `pyrightconfig.json`, `.prettierrc`, etc.)

This guide advocates strongly for option 2. Four reasons:

**Editor independence.** Your teammates may use VS Code, JetBrains, or Emacs. Rules encoded in your Neovim config apply only when _you_ open a file. A teammate using VS Code will format differently, producing constant noise in diffs that has nothing to do with actual logic changes.

**The project owns its standards.** Formatting rules, linter configuration, and type-checking strictness are part of a project's definition of "correct code." They belong in the repository, versioned alongside the code, visible to every contributor from day one.

**Onboarding.** A new contributor clones the repository and their editor — whatever it is — picks up the rules automatically. No "ask Alberto which settings to use."

**CI/CD alignment.** When CI runs `ruff check .` or `prettier --check`, it reads the same config files your editor reads. Rules cannot silently diverge between local development and the pipeline.

**The guiding principle:**

> If a tool has a project-local config file, use it. Only put something in the Neovim config when it has no other home.

---

### 10.6 The Three Enforcement Layers

Formatting and linting are enforced at three distinct points, each with different trigger conditions and bypass characteristics:

```
┌──────────────────────────────────────────────────────┐
│  LAYER 1: Editor (Neovim conform.nvim / VS Code)     │
│  Trigger:  you save a file (:w)                      │
│  Bypass:   always possible — it's your editor        │
│  Purpose:  fast feedback while you write             │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│  LAYER 2: pre-commit hook                            │
│  Trigger:  git commit                                │
│  Bypass:   git commit --no-verify                    │
│  Purpose:  safety net — catches what the editor missed│
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│  LAYER 3: CI pipeline (GitHub Actions)               │
│  Trigger:  git push / pull request                   │
│  Bypass:   not possible to merge without passing     │
│  Purpose:  true enforcer                             │
└──────────────────────────────────────────────────────┘
```

**Critical insight:** all three layers invoke the **same binary** and read the **same config files**. The editor never reads `pyproject.toml` — it invokes `ruff`, which finds and reads `pyproject.toml`. This is why the same Neovim configuration works correctly across projects with completely different rules, and why both Neovim and VS Code produce identical output on the same project.

---

### 10.7 The Toolchain Architecture

What each Neovim plugin does and where its configuration comes from:

```
conform.nvim      → runs formatters on :w
                    reads filetype→binary from lua/plugins/formatting.lua
                    binary reads rules from pyproject.toml / .prettierrc / etc.

nvim-lint         → runs linters on BufWritePost / InsertLeave
                    reads filetype→linter from lua/plugins/linting.lua
                    linter reads rules from pyproject.toml / .eslintrc / etc.

nvim-lspconfig    → starts language servers on file open
                    server binary found on $PATH (mason=false) — devenv provides it
                    server reads rules from pyrightconfig.json / tsconfig.json

nvim-dap          → manages debugger sessions
                    adapter binary found via vim.fn.exepath() on $PATH
                    launch configurations from .vscode/launch.json
```

The Neovim plugins are thin wiring layers. They map filetypes to binary names and handle the editor-side protocol. The binaries, their versions, and their rules all live outside the editor.

---

### 10.8 `.editorconfig`: The Universal Baseline

EditorConfig controls the most fundamental mechanical editor properties: indentation style and size, line endings, character encoding, trailing whitespace, final newline. Neovim 0.9+ reads `.editorconfig` natively — no plugin required.

Create `.editorconfig` at the project root:

```ini
# .editorconfig
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.py]
indent_size = 4

[*.{js,ts,jsx,tsx}]
indent_size = 2

[*.{yaml,yml}]
indent_size = 2

[*.json]
indent_size = 2

[*.lua]
indent_size = 2

# Markdown: do NOT trim trailing whitespace
# Two trailing spaces = intentional line break in Markdown
[*.md]
trim_trailing_whitespace = false
indent_size = 2

# Makefiles MUST use real tabs — spaces break them
[Makefile]
indent_style = tab

# Justfiles also use tabs
[justfile]
indent_style = tab
```

**What EditorConfig does NOT control:** which formatter runs, which linter rules apply, LSP behaviour, or anything beyond the mechanical properties above.

**Verification:**

```vim
:verbose set tabstop?
```

The output should include `Last set from editorconfig`. If it shows a different source, `.editorconfig` is not being read — confirm the file is at the project root and that Neovim is version 0.9 or later.

---

### 10.9 Formatters

#### How Formatting Works End-to-End

```
You press :w
        ↓
conform.nvim looks up current filetype in formatters_by_ft
  python → run "ruff" (fix mode), then "ruff_format"
        ↓
ruff binary invoked — finds pyproject.toml by walking up the directory tree
  applies [tool.ruff.lint] fixes (import sorting, unused imports)
  applies [tool.ruff.format] style rules
        ↓
Formatted output replaces buffer contents
```

The editor never reads `pyproject.toml`. It invokes the binary. The binary finds its own config.

#### What LazyVim Already Does

When you enable `lang.python` via `:LazyExtras`, LazyVim automatically wires `python → ruff_format`. Check what is already active:

```vim
:LazyFormatInfo
```

If the output shows the formatters you want and `condition: true` for all of them, you may not need `formatting.lua` at all for those filetypes.

#### When You Need `lua/plugins/formatting.lua`

Create this file in exactly one of these situations:

1. You want a formatter for a filetype no LazyVim extra covers
2. You want to change the default formatter choice (e.g. use `black` instead of `ruff_format`)
3. You want to add condition gates for formatters LazyVim does not gate by default

#### The Condition Gate

A condition gate prevents a formatter from running in projects that have not opted in. Without it, `ruff_format` would run on every `.py` file you open anywhere on your system — including scripts in your home directory with no `pyproject.toml`. The gate checks whether a config file exists in the project tree:

```lua
condition = function(_, ctx)
  return vim.fs.find(
    { "ruff.toml", ".ruff.toml", "pyproject.toml" },
    { path = ctx.filename, upward = true }
  )[1] ~= nil
end
```

`vim.fs.find` walks up the directory tree from the current file's location. If it finds any of the listed files, the formatter runs. If not, it is silently skipped — no error, no message.

#### The Complete `formatting.lua`

```lua
-- ~/dotfiles/nvim/lua/plugins/formatting.lua
-- Purpose: declare which formatter runs per filetype, gate each one
--          so it only runs in projects that have opted in via a config file.
--
-- ACTION: create this file if it does not exist.
--         If it already exists, merge the opts table below into it.

return {
  "stevearc/conform.nvim",
  opts = {

    -- ── Part 1: filetype → formatter mapping ──────────────────────────
    --
    -- Maps filetypes to the binary name(s) to run on save.
    -- Multiple entries run in order. "ruff" runs in fix mode first
    -- (import sorting, auto-fixable lint violations), then "ruff_format"
    -- applies style formatting.
    --
    -- LazyVim extras pre-populate some of these. Declaring them here
    -- overrides those defaults and makes your setup explicitly visible.
    formatters_by_ft = {
      python          = { "ruff", "ruff_format" },
      javascript      = { "prettier" },
      typescript      = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      html            = { "prettier" },
      css             = { "prettier" },
      scss            = { "prettier" },
      json            = { "prettier" },
      yaml            = { "prettier" },
      markdown        = { "prettier" },
      lua             = { "stylua" },
      sh              = { "shfmt" },
      bash            = { "shfmt" },
    },

    -- ── Part 2: condition gates ────────────────────────────────────────
    --
    -- Each formatter only runs when the project has a config file.
    -- The condition function returns true (run) or false (skip silently).
    formatters = {

      ruff_format = {
        condition = function(_, ctx)
          return vim.fs.find(
            { "ruff.toml", ".ruff.toml", "pyproject.toml" },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },

      ruff = {
        condition = function(_, ctx)
          return vim.fs.find(
            { "ruff.toml", ".ruff.toml", "pyproject.toml" },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },

      -- Note: LazyVim already ships a prettier condition gate.
      -- This entry is shown for reference — you do not need to add it.
      -- Do NOT include "package.json" in this list — every JS project
      -- has one, which would make the gate useless.
      prettier = {
        condition = function(_, ctx)
          return vim.fs.find(
            { ".prettierrc", ".prettierrc.json", ".prettierrc.js",
              ".prettierrc.toml", ".prettierrc.yaml", ".prettierrc.yml",
              "prettier.config.js", "prettier.config.ts" },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },

      stylua = {
        condition = function(_, ctx)
          return vim.fs.find(
            { "stylua.toml", ".stylua.toml" },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },
    },
  },
}
```

#### Project Config Files for Formatters

**Python — `pyproject.toml`:**

```toml
[tool.ruff]
# target-version: set to match your Python version.
# ERPNext v15 → "py311"
# ERPNext v16 → "py314"
target-version = "py311"
line-length = 88
exclude = [".git", ".venv", "__pycache__", "migrations"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
magic-trailing-comma = true
docstring-code-format = true
```

**JavaScript/TypeScript — `.prettierrc`:**

```json
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 80,
  "endOfLine": "lf"
}
```

**Lua — `stylua.toml`:**

```toml
column_width = 120
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

#### Verification

```vim
:LazyFormatInfo
```

Expected output for a Python file inside a project with `pyproject.toml`:

```
Active formatters for python:
  ruff        ✓ (condition: true)
  ruff_format ✓ (condition: true)
```

If a formatter shows `condition: false`: the project has no matching config file in the directory tree. If a formatter is missing entirely: either the binary is not on `$PATH` (`which ruff` in the terminal) or the `formatters_by_ft` entry is absent.

```vim
:ConformInfo
```

Shows binary paths for all registered formatters — use this to confirm devenv's binary is being used, not Mason's.

---

### 10.10 Linters

#### How Linting Works

Unlike formatters, linters report problems without modifying files. `nvim-lint` runs the configured linter binary on `BufWritePost` (after save), `BufReadPost` (on open), and `InsertLeave` (when you stop typing). The output feeds into Neovim's diagnostic system — the red and yellow underlines with messages in the status line.

#### What LazyVim Already Does

Check active linters:

```vim
:lua vim.notify(vim.inspect(require("lint").linters_by_ft))
```

If the output already shows what you want for each filetype, you may not need `linting.lua`.

#### The Condition Guard for Nvim-lint

`nvim-lint` does not have a built-in `condition` key like `conform.nvim`. The guard is implemented by patching each linter object's `condition` field in a `config` function. This is the pattern LazyVim supports:

```lua
local shellcheck = require("lint").linters.shellcheck
if shellcheck then
  shellcheck.condition = function(ctx)
    return vim.fs.find(
      { ".shellcheckrc" },
      { path = ctx.filename, upward = true }
    )[1] ~= nil
  end
end
```

Without condition guards, linters produce false diagnostics on files outside proper projects — a flood of errors on scripts in your home directory that have no config, obscuring real problems in actual projects.

#### The Complete `linting.lua`

```lua
-- ~/dotfiles/nvim/lua/plugins/linting.lua
-- Purpose: declare which linter runs per filetype, add condition guards
--          so linters only run in projects that have opted in.
--
-- ACTION: create this file if it does not exist.

return {
  "mfussenegger/nvim-lint",
  opts = {
    linters_by_ft = {
      python = { "ruff" },      -- ruff in lint mode (fast; same binary as formatter)
      sh     = { "shellcheck" },
      yaml   = { "yamllint" },
    },
  },
  config = function(_, opts)
    local lint = require("lint")

    -- Apply the linters_by_ft table
    lint.linters_by_ft = opts.linters_by_ft or {}

    -- ── Condition guards ──────────────────────────────────────────────
    -- Patch each linter's condition field. Returns true = run, false = skip.

    local ruff = require("lint").linters.ruff
    if ruff then
      ruff.condition = function(ctx)
        return vim.fs.find(
          { "ruff.toml", ".ruff.toml", "pyproject.toml" },
          { path = ctx.filename, upward = true }
        )[1] ~= nil
      end
    end

    local shellcheck = require("lint").linters.shellcheck
    if shellcheck then
      shellcheck.condition = function(ctx)
        return vim.fs.find(
          { ".shellcheckrc" },
          { path = ctx.filename, upward = true }
        )[1] ~= nil
      end
    end

    local yamllint = require("lint").linters.yamllint
    if yamllint then
      yamllint.condition = function(ctx)
        return vim.fs.find(
          { ".yamllint", ".yamllint.yaml", ".yamllint.yml" },
          { path = ctx.filename, upward = true }
        )[1] ~= nil
      end
    end

    -- ── Trigger linting on save and on file open ──────────────────────
    vim.api.nvim_create_autocmd(
      { "BufWritePost", "BufReadPost", "InsertLeave" },
      {
        callback = function()
          lint.try_lint()
        end,
      }
    )
  end,
}
```

#### The mypy-in-CI-only Pattern

mypy can take 30–60 seconds on a large codebase. Running it on every save degrades the editor experience; running it on every commit makes commits feel sluggish. The recommended pattern:

- **Editor (Neovim):** ruff only — fast, instant feedback
- **pre-commit hook:** ruff only — catches what the editor missed, still fast
- **CI:** mypy as a separate job — thorough, slow, does not block local workflow

To implement this: omit mypy from `linters_by_ft` in `linting.lua`, omit it from `.pre-commit-config.yaml`, and add it as a separate GitHub Actions job:

```yaml
# .github/workflows/quality.yml
jobs:
  mypy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install -e ".[dev]"
      - run: mypy app/ --ignore-missing-imports
```

#### Project Config Files for Linters

**Python — `pyproject.toml`:**

```toml
[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "C4", "UP"]
ignore = ["E501"]  # line length handled by formatter
fixable = ["I", "UP", "C4"]

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["S101", "ANN"]
"**/migrations/*.py" = ["E501", "F401"]
```

**Shell — `.shellcheckrc`:**

```
disable=SC2034
disable=SC1091
shell=bash
```

**YAML — `.yamllint`:**

```yaml
extends: default
rules:
  line-length:
    max: 120
    level: warning
  document-start: disable
```

---

### 10.11 LSP: Language Servers

#### What an LSP Server Is

A language server is a background process that deeply understands a programming language. It provides autocompletion, go-to-definition, find-references, inline error reporting, and rename refactoring. Unlike formatters (invoked once per save and exit), LSP servers start when you open a file and run continuously while you edit.

#### The Four LSP Components

```
┌───────────────────────────────────────────────────────────┐
│ 1. Neovim built-in LSP client                             │
│    Handles the protocol communication with the server     │
│    API: vim.lsp.*, vim.lsp.config(), vim.lsp.enable()     │
│    You do not call these directly — other layers do it    │
└───────────────────────────────────────────────────────────┘
              ↓ configured by
┌───────────────────────────────────────────────────────────┐
│ 2. nvim-lspconfig                                         │
│    Pre-written launch configs for 200+ servers            │
│    Knows each server's command, filetypes, root detection │
│    You override its defaults per-server in lsp.lua        │
└───────────────────────────────────────────────────────────┘
              ↓ server binaries installed by (default)
┌───────────────────────────────────────────────────────────┐
│ 3. Mason                                                  │
│    Downloads LSP server binaries globally                 │
│    Installs to ~/.local/share/nvim/mason/bin/             │
│    Managed with :Mason inside Neovim                      │
└───────────────────────────────────────────────────────────┘
              ↓ connected to nvim-lspconfig by
┌───────────────────────────────────────────────────────────┐
│ 4. mason-lspconfig                                        │
│    Bridge: Mason-installed servers → nvim-lspconfig       │
│    Translates package names to server names               │
│    LazyVim wires this up automatically                    │
└───────────────────────────────────────────────────────────┘
```

> [!tip] Neovim 0.11 introduces `vim.lsp.config()` and `vim.lsp.enable()` These are a new built-in layer that partially overlaps with nvim-lspconfig. You do not call these functions directly in this stack — LazyVim and nvim-lspconfig handle everything. The diagram above shows the architecture for understanding, not for direct use.

#### The Two Kinds of LSP Settings

This distinction is the most important conceptual point in this section:

**Language rules** — what the server enforces: type strictness, Python version, import paths, virtualenv path. These live in **project config files** (`pyrightconfig.json`, `pyproject.toml [tool.pyright]`, `tsconfig.json`). Every editor reads these automatically — no Neovim config needed.

**Editor-interaction settings** — how Neovim communicates with the server: virtual text display, inlay hints, specific capabilities. These live in `.neoconf.json` (Neovim-specific) or `.vscode/settings.json` (VS Code).

#### The `mason = false` Mechanism

Setting `mason = false` per server in `lsp.lua` tells LazyVim to find the binary on `$PATH` rather than downloading it via Mason:

```
For each server in the servers table:

  mason == true (default):
    → Mason downloads binary to ~/.local/share/nvim/mason/bin/
    → devenv's binary is ignored

  mason == false:
    → Neovim searches $PATH directly
    → devenv's pinned binary is found ✓
```

You still enable language support via `:LazyExtras`. The extra configures keymaps, capabilities, filetype triggers, and diagnostic display. `mason = false` only changes where the binary comes from — everything else the extra provides still applies.

#### The Mason vs. Devenv Decision Rule

|Server|Where|Reason|
|---|---|---|
|`pyright`, `ts_ls`, `eslint`|devenv + `mason = false`|Version matters per project|
|`lua_ls`|Mason|Used to edit Neovim config, which is not inside any devenv project|
|`jsonls`, `yamlls`, `bashls`|Mason|Generic, version-insensitive, always useful|
|Any new language server|devenv + `mason = false`|Consistent with the philosophy|

#### The Complete `lsp.lua`

```lua
-- ~/dotfiles/nvim/lua/plugins/lsp.lua
-- Purpose: declare which servers get their binary from devenv ($PATH)
--          vs which are managed by Mason.
--
-- This is your global Home Manager config — it applies to all projects.
-- Per-project server rules go in pyrightconfig.json / tsconfig.json / etc.
--
-- ACTION: create this file if it does not exist.

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {

      -- ── Project-specific servers: binary from devenv ───────────────
      -- mason = false tells LazyVim to find the binary on $PATH.
      -- devenv.nix must include the corresponding package for each project
      -- that uses these servers. (§10.18 has the per-language packages.)

      -- Python: pyright
      -- devenv.nix package: pkgs.pyright
      -- Project config: pyrightconfig.json or pyproject.toml [tool.pyright]
      pyright = {
        mason = false,
        settings = {
          python = {
            -- These settings are overridden by .neoconf.json per project
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      },

      -- TypeScript: ts_ls (renamed from tsserver in nvim-lspconfig)
      -- devenv.nix package: pkgs.nodePackages.typescript-language-server
      -- Project config: tsconfig.json
      ts_ls = { mason = false },

      -- ESLint LSP: provided by vscode-langservers-extracted
      -- devenv.nix package: pkgs.nodePackages.vscode-langservers-extracted
      -- Project config: .eslintrc.json or eslint.config.js
      eslint = { mason = false },

      -- ── Global servers: binary from Mason ─────────────────────────
      -- These are version-insensitive and useful everywhere, so
      -- keeping them Mason-managed is correct. LazyVim manages them
      -- with no additional config needed here.

      -- Lua: Mason-managed because it serves the Neovim config itself
      -- (which is not inside any devenv project)
      lua_ls = {},

      -- JSON: Mason-managed, schema-aware completion for all projects
      jsonls = {},

      -- YAML: Mason-managed, schema validation for all projects
      yamlls = {},

      -- Bash: Mason-managed, useful for shell scripts everywhere
      bashls = {},
    },
  },
}
```

#### Python LSP Setup: Step by Step

**Step 1 — Enable the LazyVim extra (once per machine):**

```vim
:LazyExtras
```

Navigate to `lang.python` and press `x` to enable. Commit the updated `lazyvim.json` and `lazy-lock.json`.

**Step 2 — Add pyright to `devenv.nix` (per project):**

```nix
packages = [
  pkgs.pyright
  pkgs.ruff
  # debugpy goes in requirements.txt — not here (§10.13)
];
```

**Step 3 — Create `pyrightconfig.json` in the project root (per project):**

```json
{
  "pythonVersion": "3.11",
  "pythonPlatform": "Linux",
  "venvPath": ".",
  "venv": ".venv",
  "typeCheckingMode": "basic",
  "reportMissingImports": true,
  "reportMissingModuleSource": false,
  "exclude": ["**/__pycache__", "**/migrations", ".venv", "dist"]
}
```

Or via `pyproject.toml`:

```toml
[tool.pyright]
pythonVersion = "3.11"
venvPath = "."
venv = ".venv"
typeCheckingMode = "basic"
reportMissingImports = true
exclude = ["**/migrations", ".venv"]
```

**Step 4 — Verify:**

```bash
cd ~/projects/my-project
direnv allow

which pyright-langserver
# Expected: /nix/store/abc.../bin/pyright-langserver
# Not:      ~/.local/share/nvim/mason/bin/pyright-langserver
```

Inside Neovim on a `.py` file:

```vim
:LspInfo
" Expected:
" pyright: attached
" cmd: /nix/store/abc.../bin/pyright-langserver --stdio
" root_dir: /home/you/projects/my-project
```

#### TypeScript LSP Setup: Step by Step

**Step 1 — Enable the LazyVim extra:**

```vim
:LazyExtras → lang.typescript → x
```

**Step 2 — Add to `devenv.nix` (per project):**

```nix
packages = [
  pkgs.nodePackages.typescript-language-server
  pkgs.nodePackages.vscode-langservers-extracted  # provides eslint LSP
  pkgs.nodePackages.prettier
];
```

**Step 3 — Create `tsconfig.json` in the project root:**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src/**/*", "tests/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**Step 4 — Verify:**

```bash
which typescript-language-server
# Expected: /nix/store/xyz.../bin/typescript-language-server
```

#### neoconf.nvim — For Editor-Interaction Settings

Some LSP settings are Neovim-specific and have no home in `pyrightconfig.json` or `tsconfig.json`. `neoconf.nvim` provides a `.neoconf.json` project file for these.

**Install once in your Home Manager Neovim config:**

```lua
-- ~/dotfiles/nvim/lua/plugins/neoconf.lua
return {
  "folke/neoconf.nvim",
  cmd = "Neoconf",
  -- Must load before nvim-lspconfig initializes servers
  priority = 1000,
  opts = {},
}
```

**Use `.neoconf.json` in the project root for per-project Neovim LSP overrides:**

```json
{
  "pyright": {
    "python.analysis.autoSearchPaths": true,
    "python.analysis.useLibraryCodeForTypes": true
  }
}
```

Merge order: global Neovim config → `~/.config/neoconf.json` → project `.neoconf.json`. The project always wins.

---

### Automated LSP Injection Script

This script patches existing `devenv.nix` files to add the project-bound LSP binaries (`pyright`, `ruff`, `typescript-language-server`, `just`) to the `packages` list. Useful when migrating a project that was set up before this guide's LSP strategy was established.

> [!note] **`nodePackages` namespace on `nixos-unstable`**
> This script injects `pkgs.nodePackages.typescript-language-server`. On `nixos-unstable` (the channel this guide uses), many Node packages have migrated from `nodePackages.*` to top-level attribute names. If `devenv update` fails after injection with an error like `error: attribute 'typescript-language-server' missing`, replace it with `pkgs.typescript-language-server`. Similarly, `pkgs.nodePackages.vscode-langservers-extracted` may need to become `pkgs.vscode-langservers-extracted`, and `pkgs.nodePackages.prettier` may need to become `pkgs.nodePackages_latest.prettier`. Check the correct attribute name at [search.nixos.org/packages](https://search.nixos.org/packages) if in doubt.

Save as `inject-lsps.sh` in your dotfiles `scripts/` directory.

```bash
#!/usr/bin/env bash
# inject-lsps.sh
# Scans a directory tree for devenv.nix files and injects LSP binaries
# into the packages list if they are not already present.
#
# Usage: ./inject-lsps.sh [target-directory]
# Default target: ~/projects
#
# The script uses awk for portable multi-line injection, which works
# correctly across both GNU and BSD variants.

set -euo pipefail

TARGET_DIR="${1:-$HOME/projects}"

# Packages to inject if not already present
INJECT_PACKAGES=(
    "pkgs.pyright"
    "pkgs.ruff"
    "pkgs.nodePackages.typescript-language-server"
    "pkgs.just"
)

# Build the injection string (indented to match typical devenv.nix style)
INJECT_STR=""
for pkg in "${INJECT_PACKAGES[@]}"; do
    INJECT_STR+="    ${pkg}\n"
done

echo "Scanning $TARGET_DIR for devenv.nix files..."
echo ""

PATCHED=0
SKIPPED=0

# Use process substitution so PATCHED/SKIPPED are modified in the current shell,
# not a subshell. A pipe (find ... | while ...) would create a subshell, making
# the counter updates invisible to the outer shell and always printing 0.
while read -r file; do
    # Skip if pyright is already present (assume already migrated)
    if grep -q "pkgs.pyright" "$file" 2>/dev/null; then
        echo "SKIP  $file (LSPs already present)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Skip if the file has no packages block to inject into
    if ! grep -q "packages = \[" "$file" 2>/dev/null; then
        echo "SKIP  $file (no 'packages = [' block found)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Backup original
    cp "$file" "${file}.bak"

    # Inject using awk — find the first 'packages = [' line and insert after it.
    # awk is used instead of sed to handle multi-line injection portably.
    awk -v inj="$INJECT_STR" '
        /packages = \[/ && !injected {
            print
            printf "%s", inj
            injected = 1
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    echo "PATCH $file"
    echo "      (backup saved as ${file}.bak)"
    PATCHED=$((PATCHED + 1))
done < <(find "$TARGET_DIR" -name "devenv.nix" -type f | sort)

echo ""
echo "Complete."
echo "  Patched: $PATCHED"
echo "  Skipped: $SKIPPED"
echo ""
echo "Next steps:"
echo "  1. Review each patched file: the injected packages appear at the"
echo "     top of the packages list — reorder if needed."
echo "  2. Run 'devenv update' in each patched directory to update devenv.lock."
echo "  3. Verify: cd into the project, 'which pyright-langserver' should"
echo "     show a /nix/store/... path."
echo "  4. Remove backup files once satisfied: find $TARGET_DIR -name '*.bak' -delete"
```

Make executable:

```bash
chmod +x ~/dotfiles/scripts/inject-lsps.sh
```

Usage:

```bash
# Scan ~/projects (default)
~/dotfiles/scripts/inject-lsps.sh

# Scan a specific directory
~/dotfiles/scripts/inject-lsps.sh ~/work

# After reviewing the patches, update each project's lockfile:
find ~/projects -name "devenv.nix" | while read -r f; do
    dir=$(dirname "$f")
    echo "Updating $dir..."
    (cd "$dir" && devenv update)
done
```

---

### 10.12 Clipboard in Neovim

Add to `~/dotfiles/nvim/lua/config/options.lua`:

```lua
vim.opt.clipboard = "unnamedplus"
```

This makes `y` (yank) and `p` (paste) use the OS clipboard register (`+`) by default. Without this, yanks go to Neovim's internal registers, which are invisible to the browser or other applications.

Requires `xclip` (X11) or `wl-clipboard` (Wayland) — both already in `home.nix` packages. Determine which you need:

```bash
echo $XDG_SESSION_TYPE   # outputs "x11" or "wayland"
```

**Verification:** yank a line in Neovim with `yy`, then paste in the browser with `Ctrl+V`. If nothing pastes, confirm the clipboard provider is installed:

```bash
which xclip      # X11
which wl-copy    # Wayland
```

---

### 10.13 DAP: Debugger

#### What DAP Is

The Debug Adapter Protocol (DAP) is a standardized protocol between editors and debugger backends — the same concept as LSP but for debugging. `nvim-dap` is the client. Adapter processes (`debugpy` for Python, `js-debug` for Node.js) speak the protocol. Launch configurations in `.vscode/launch.json` tell the adapter what to run.

#### The Three DAP Components

```
┌──────────────────────────────────────────────────────────┐
│ 1. nvim-dap                                              │
│    DAP protocol client                                   │
│    Breakpoints, step-through, variable inspection        │
│    Keymaps: <leader>db, <leader>dc, <leader>dn, etc.     │
└──────────────────────────────────────────────────────────┘
              ↓ adapters managed by (default)
┌──────────────────────────────────────────────────────────┐
│ 2. Mason                                                 │
│    Downloads debugger adapter binaries                   │
│    Installs to ~/.local/share/nvim/mason/bin/            │
└──────────────────────────────────────────────────────────┘
              ↓ bridged by
┌──────────────────────────────────────────────────────────┐
│ 3. mason-nvim-dap                                        │
│    Bridge: Mason adapters → nvim-dap configs             │
│    LazyVim wires this up automatically                   │
└──────────────────────────────────────────────────────────┘
```

#### The `debugpy` Exception

> [!warning] debugpy does NOT go in `devenv.nix` packages This is the most important exception in the entire guide. `debugpy` must be installed into the project's Python virtualenv via `requirements.txt` (or `requirements-dev.txt`), not as a Nix package in `devenv.nix`.
> 
> **Why:** The DAP adapter command is `python3 -m debugpy.adapter`. Python must be able to **import** `debugpy` — not just find it on `$PATH`. This means `debugpy` must be in the virtualenv's `site-packages`, installed by pip into `.venv/`. A Nix package places the binary on `$PATH` but does not make it importable by the project's Python interpreter.
> 
> **The fix:** add `debugpy>=1.8` to `requirements.txt`. devenv installs it into `.venv/` when the environment activates.

#### The Complete `dap.lua`

```lua
-- ~/dotfiles/nvim/lua/plugins/dap.lua
-- Purpose: configure DAP adapters to use devenv's binaries ($PATH),
--          load launch configurations from .vscode/launch.json,
--          and disable Mason auto-installation for devenv-managed adapters.

return {

  -- ── Python and Node.js DAP adapter configuration ─────────────────────
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")

      -- ── Python adapter ──────────────────────────────────────────────
      -- Uses debugpy from the project's virtualenv.
      -- vim.fn.exepath() finds the first python3 on $PATH — devenv's
      -- Python when inside a project, system Python otherwise.
      -- debugpy must be installed into .venv via requirements.txt.
      dap.adapters.python = {
        type = "executable",
        command = vim.fn.exepath("python3"),
        args = { "-m", "debugpy.adapter" },
      }

      -- ── Node.js adapter ─────────────────────────────────────────────
      -- js-debug-adapter is not reliably available in nixpkgs.
      -- Install it once with :MasonInstall js-debug-adapter
      -- The config falls back to the Mason path if not on $PATH.
      dap.adapters.node = {
        type = "executable",
        command = vim.fn.exepath("node"),
        args = {
          -- Use devenv's js-debug-adapter if available, else Mason's
          vim.fn.exepath("js-debug-adapter") ~= ""
            and vim.fn.exepath("js-debug-adapter")
            or vim.fn.stdpath("data") .. "/mason/bin/js-debug-adapter",
        },
      }

      -- Also register under pwa-node (used by some launch.json configs)
      dap.adapters["pwa-node"] = dap.adapters.node

      -- ── Load launch configurations from .vscode/launch.json ────────
      -- Runs every time nvim-dap initialises, picking up the project file.
      -- The type mapping connects launch.json "type" values to the
      -- adapter names configured above.
      require("dap.ext.vscode").load_launchjs(nil, {
        python = { "python" },
        node   = { "node", "pwa-node" },
      })
    end,
  },

  -- ── Disable Mason auto-installation for devenv-managed adapters ──────
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = {
      -- Empty list: do not auto-install any adapters
      -- devenv manages Python's debugpy; Mason handles js-debug-adapter
      ensure_installed = {},
      automatic_installation = false,
    },
  },
}
```

#### Python Debugging: Step by Step

**Step 1 — Enable the LazyVim extra:**

The `lang.python` extra already includes `nvim-dap-python` support. If you enabled it in §10.11, this step is complete.

**Step 2 — Add `debugpy` to `requirements.txt` (per project):**

```
# requirements.txt (or requirements-dev.txt)
debugpy>=1.8
```

devenv installs this into `.venv/` when the environment activates.

**Step 3 — Verify `debugpy` is importable:**

```bash
cd ~/projects/my-project
direnv allow

python3 -c "import debugpy; print(debugpy.__file__)"
# Expected:
# /home/you/projects/my-project/.venv/lib/python3.11/site-packages/debugpy/__init__.py
#
# NOT: /nix/store/.../debugpy (that means it's a Nix package, not virtualenv)
```

**Step 4 — Create `.vscode/launch.json` in the project root:**

```jsonc
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "FastAPI dev server",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": ["app.main:app", "--reload", "--host", "0.0.0.0", "--port", "8000"],
      "env": { "DATABASE_URL": "mysql://root:123@localhost:3306/erpnext" },
      "cwd": "${workspaceFolder}",
      "justMyCode": false
    },
    {
      "name": "Pytest: all tests",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": ["tests/", "-v", "--tb=short"],
      "cwd": "${workspaceFolder}"
    },
    {
      "name": "Pytest: current file",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": ["${file}", "-v"],
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

**Step 5 — Verify in Neovim:**

Open a Python file, set a breakpoint with `<leader>db`, press `<leader>dc` to start debugging. A picker shows the available launch configurations from `launch.json`. Select "FastAPI dev server" — the DAP UI should open and execution should pause at the breakpoint.

#### JavaScript/TypeScript Debugging: Step by Step

**Step 1 — The `dap.lua` above already handles Node.js.** No additional Lua config is needed.

**Step 2 — Install `js-debug-adapter` via Mason (once per machine):**

```vim
:MasonInstall js-debug-adapter
```

This installs to `~/.local/share/nvim/mason/bin/js-debug-adapter`. The `dap.lua` fallback path handles this case.

**Step 3 — Confirm Node.js is available from devenv:**

```bash
which node
# Expected: /nix/store/xyz.../bin/node (devenv's Node)
```

**Step 4 — Add JS/TS launch configurations to `.vscode/launch.json`:**

```jsonc
// Add to "configurations" array in the same .vscode/launch.json
{
  "name": "Next.js: dev server",
  "type": "node",
  "request": "launch",
  "runtimeExecutable": "npm",
  "runtimeArgs": ["run", "dev"],
  "cwd": "${workspaceFolder}",
  "env": { "NODE_ENV": "development" },
  "port": 9229
},
{
  "name": "Node.js: current file",
  "type": "node",
  "request": "launch",
  "program": "${file}",
  "cwd": "${workspaceFolder}"
}
```

#### `.vscode/launch.json` Variable Substitutions

These tokens are replaced at debug time by both VS Code and nvim-dap:

|Token|Replaced with|
|---|---|
|`${workspaceFolder}`|Project root (git root directory)|
|`${file}`|Absolute path of the currently open file|
|`${fileBasename}`|Filename only, without directory|
|`${fileDirname}`|Directory of the currently open file|
|`${env:NAME}`|Value of shell environment variable `NAME`|

#### The `.lazy.lua` Escape Hatch for DAP

When `launch.json` cannot express the logic you need — for example, dynamically locating a virtualenv at runtime — use `.lazy.lua` in the project root:

```lua
-- .lazy.lua in project root
-- Use this ONLY when launch.json cannot express the logic.
local dap = require("dap")

dap.configurations.python = {
  {
    type = "python",
    request = "launch",
    name = "FastAPI (dynamic venv)",
    module = "uvicorn",
    args = { "app.main:app", "--reload" },
    pythonPath = function()
      local venv = vim.fn.getcwd() .. "/.venv/bin/python"
      if vim.fn.executable(venv) == 1 then return venv end
      return vim.fn.exepath("python3")
    end,
  },
}

return {}
```

Prefer `.vscode/launch.json` for everything that does not need runtime logic. `.lazy.lua` requires an explicit trust approval from every developer who clones the repo (§10.15).

#### DAP Keymaps Reference (LazyVim defaults)

|Keymap|Action|
|---|---|
|`<leader>db`|Toggle breakpoint on current line|
|`<leader>dB`|Set conditional breakpoint|
|`<leader>dc`|Continue (or start — opens config picker)|
|`<leader>dn`|Step over (next line)|
|`<leader>di`|Step into function|
|`<leader>do`|Step out of function|
|`<leader>dr`|Open REPL|
|`<leader>de`|Evaluate expression under cursor|
|`<leader>dq`|Quit debugger|

---

### 10.14 Neovim ↔ Tmux Integration

#### Vim-tmux-navigator

The tmux side was configured in [3-Terminal.md §4.7](3-Terminal.md). The Neovim side needs a matching plugin declaration:

```lua
-- ~/dotfiles/nvim/lua/plugins/tmux-navigator.lua
return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft", "TmuxNavigateDown",
    "TmuxNavigateUp",   "TmuxNavigateRight",
  },
  keys = {
    { "<c-h>", "<cmd>TmuxNavigateLeft<cr>" },
    { "<c-j>", "<cmd>TmuxNavigateDown<cr>" },
    { "<c-k>", "<cmd>TmuxNavigateUp<cr>" },
    { "<c-l>", "<cmd>TmuxNavigateRight<cr>" },
  },
}
```

Without this, `Ctrl-h/j/k/l` stops working when focus is inside Neovim. You would need `prefix + arrow` to leave a Neovim pane — a completely different motion pattern that interrupts flow.

**Verification:** open a project with the code layout (Neovim left, shell pane right). Press `Ctrl-l` from inside Neovim — focus should move to the shell pane. Press `Ctrl-h` — focus should return to Neovim.

#### persistence.nvim For Buffer Restore

persistence.nvim restores the buffer list from the last session in a directory:

```lua
-- ~/dotfiles/nvim/lua/plugins/persistence.lua
return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  opts = {},
}
```

This is compatible with the declarative tmux model: the tmux session is recreated by the sessionizer, Neovim opens with `nvim .`, and persistence.nvim restores the buffer list from the last session. You get the best of both: declarative workspace creation and restored editor state.

---

### 10.15 The `.lazy.lua` Escape Hatch

`.lazy.lua` is a Lua file placed in the project root that LazyVim evaluates when you open any file in that project. It allows per-project Neovim overrides without modifying the global Home Manager config.

#### When to Use It

Four specific situations only:

1. **Override a vim option for this project** — e.g., `vim.g.autoformat = false` for a legacy codebase where running the formatter would produce thousands of changed lines
2. **Change which formatter or linter runs** when no `$PATH` solution is practical
3. **DAP Lua-level logic** — dynamic `pythonPath` function that `launch.json` cannot express (§10.13)
4. **A formatter not in conform.nvim's built-in list** that cannot be added globally

#### The Security Model

When you open a project that contains `.lazy.lua` for the first time, Neovim shows a trust prompt:

```
.lazy.lua found. Trust this file? [a]llow, [v]iew, [d]eny
```

Always press `v` first to view the file before pressing `a` to allow. Never press `a` blindly on a cloned repository.

Trust is stored in `~/.local/share/nvim/trust` and is per-machine. Every developer who clones a project with `.lazy.lua` must approve it on their machine. This cannot be pre-approved in the repository. Include a note in the project README explaining that `.lazy.lua` is present and what it does.

#### `vim.g.autoformat = false` For Legacy Codebases

```lua
-- .lazy.lua in project root
-- This project has not adopted automated formatting yet.
-- Disable format-on-save to prevent noise in diffs.
vim.g.autoformat = false

return {}
```

This is a project-level decision — commit it so all Neovim users of the project get consistent behaviour.

#### What You Cannot Do in `.lazy.lua`

- Add new plugins not already declared in your Home Manager Neovim config — the dependency graph is fixed at startup
- Call `vim.lsp.enable()` for a server not declared in `lsp.lua`

#### Whether to Commit `.lazy.lua`

Commit it if the overrides are project-level decisions all Neovim users should get (e.g., `autoformat = false`). Add to `.gitignore` if they are personal preferences.

---

### 10.16 What Actually Belongs in the Neovim Config

A precise summary of what belongs in `~/dotfiles/nvim/lua/plugins/` and what must stay in project files:

|Setting|Belongs in|
|---|---|
|Line length (88 vs 120)|`pyproject.toml [tool.ruff]`|
|Quote style|`pyproject.toml [tool.ruff.format]` or `.prettierrc`|
|Which lint rules to enable|`pyproject.toml [tool.ruff.lint]`|
|Type checking strictness|`pyrightconfig.json` or `[tool.pyright]`|
|Python virtualenv path|`pyrightconfig.json` `venv` field|
|TypeScript compiler options|`tsconfig.json`|
|Debug launch commands|`.vscode/launch.json`|
|Formatter binary version|`devenv.nix` packages|
|Filetype → formatter binary|`lua/plugins/formatting.lua`|
|Filetype → linter binary|`lua/plugins/linting.lua`|
|Which servers use `$PATH` vs Mason|`lua/plugins/lsp.lua`|
|DAP adapter configuration|`lua/plugins/dap.lua`|

---

### 10.17 Managing LazyVim: The Four Configuration Vectors

When you want to change something about Neovim, reach for these in priority order:

1. **`:LazyExtras`** — first stop; enables language support bundles (keymaps, capabilities, filetype triggers, diagnostic display); check here before writing any Lua
2. **`:Lazy`** — install, update, clean plugins; check plugin status and error messages
3. **`lua/plugins/`** — override or extend plugin configuration; create files here only for things `:LazyExtras` does not cover
4. **`home.nix` packages** — add system-level Neovim dependencies (`gcc`, `tree-sitter`, clipboard provider, Nerd Font)

The order matters: `:LazyExtras` covers most needs without any Lua; `lua/plugins/` files override and extend specific things; `home.nix` handles the binaries that Neovim needs to function.

When you change anything in `:LazyExtras` or `lua/plugins/`, commit the relevant files:

```bash
cd ~/dotfiles
git add nvim/lazyvim.json nvim/lazy-lock.json nvim/lua/plugins/
git commit -m "feat: enable lang.python, add formatting.lua"
git push
```

---

### 10.18 Practical Setup by Language

#### Python

**LazyExtra to enable:** `lang.python`

**`devenv.nix` packages:**

```nix
packages = [
  pkgs.pyright   # LSP
  pkgs.ruff      # formatter + linter
  pkgs.just      # task runner
  # debugpy goes in requirements.txt, NOT here
];
```

**Project config files to create:**

- `.editorconfig` (§10.8)
- `pyproject.toml` with `[tool.ruff]`, `[tool.ruff.format]`, `[tool.ruff.lint]`, `[tool.pyright]` (§10.9, §10.10, §10.11)
- `requirements.txt` with `debugpy>=1.8` (§10.13)
- `.vscode/launch.json` with Python configurations (§10.13)

**Verification:**

```bash
which pyright-langserver    # must show /nix/store/...
which ruff                  # must show /nix/store/...
python3 -c "import debugpy" # must succeed
```

Inside Neovim on a `.py` file:

```vim
:LspInfo          " pyright attached, /nix/store path
:LazyFormatInfo   " ruff + ruff_format, condition: true
```

#### TypeScript

**LazyExtra to enable:** `lang.typescript`

**`devenv.nix` packages:**

```nix
packages = [
  pkgs.nodePackages.typescript-language-server
  pkgs.nodePackages.vscode-langservers-extracted
  pkgs.nodePackages.prettier
  pkgs.just
];
```

**Project config files to create:**

- `.editorconfig`
- `tsconfig.json` (§10.11)
- `.prettierrc` (§10.9)
- `.eslintrc.json` or `eslint.config.js` (§10.10)
- `.vscode/launch.json` with Node.js configurations (§10.13)

**Verification:**

```bash
which typescript-language-server  # must show /nix/store/...
which prettier                    # must show /nix/store/...
```

Inside Neovim on a `.ts` file:

```vim
:LspInfo          " ts_ls and eslint attached
:LazyFormatInfo   " prettier, condition: true
```

#### Lua

**LazyExtra to enable:** `lang.lua`

**Where the binary comes from:** Mason (exception to the devenv rule — `lua_ls` is used to edit the Neovim config itself, which is not inside any devenv project)

**Project config file to create:** `.luarc.json` in the project root:

```json
{
  "$schema": "https://raw.githubusercontent.com/sumneko/vscode-lua/master/setting/schema.json",
  "Lua.runtime.version": "LuaJIT",
  "Lua.workspace.checkThirdParty": false,
  "Lua.diagnostics.globals": ["vim"],
  "Lua.completion.callSnippet": "Replace"
}
```

**`devenv.nix` packages:** none needed — Mason manages `lua_ls`

**Verification:**

```vim
:LspInfo    " lua_ls attached (Mason path is expected here)
```

#### YAML / TOML / JSON

**LazyExtras to enable:** none required — LazyVim includes basic support by default

**Where binaries come from:** Mason manages `yamlls` and `jsonls`

**Project config files:**

YAML schema validation is handled by `yamlls` reading schema annotations. For strict YAML linting, create `.yamllint` (§10.10).

TOML: tamasfe's `even-better-toml` VS Code extension and LazyVim's built-in TOML support handle this. No project config file is needed beyond the TOML files themselves.

JSON: `jsonls` provides schema-aware completion. Add `$schema` keys to JSON files to get project-specific validation.

**Verification:**

```vim
:LspInfo    " yamlls and jsonls attached (Mason paths are expected)
```

---

### 10.19 New Project Setup Checklist

The single ordered reference for setting up a new project's Neovim/tooling configuration. Each step links to the relevant section.

```
□ uv python install 3.14  (v16 only — before direnv allow) (§10.4, §10.9)
□ devenv init && direnv allow                   (§10.3)
□ Create .editorconfig                          (§10.8)
□ Create pyproject.toml with ruff + pyright     (§10.9, §10.10, §10.11)
  (or tsconfig.json + .prettierrc + .eslintrc)
□ Add pyright + ruff to devenv.nix packages     (§10.4, §10.11)
  (or typescript-language-server + prettier)
□ Add debugpy to requirements.txt               (§10.13)
□ Create .vscode/launch.json                    (§10.13)
□ Create .vscode/settings.json                  (§10.5)
□ Create .vscode/extensions.json                (§10.5)
□ Create justfile with setup/fmt/lint/test       (§10.9)
□ just setup  (installs pre-commit hooks)        (§10.9)
□ Verify: which pyright-langserver (→ /nix/store) (§10.11)
□ Verify: :LspInfo in Neovim                    (§10.11)
□ Verify: :LazyFormatInfo in Neovim             (§10.9)
□ Verify: python3 -c "import debugpy"           (§10.13)
□ Verify: yank in Neovim → paste in browser     (§10.12)
□ git add all project config files && commit
```

---

### 10.20 How to Add a New Language

1. Enable the LazyVim extra via `:LazyExtras`
2. Add `mason = false` for the LSP server in `lua/plugins/lsp.lua`
3. Add the LSP binary to `devenv.nix` packages (per project)
4. Create the project config file (`pyrightconfig.json`, `tsconfig.json`, etc.)
5. Verify with `:LspInfo` and `which binary-name`
6. Commit `lazyvim.json`, `lazy-lock.json`, and `lua/plugins/lsp.lua`

---

### 10.21 How to Add a New Plugin

1. Create `~/dotfiles/nvim/lua/plugins/your-plugin.lua` with the `lazy.nvim` spec:

```lua
return {
  "author/plugin-name",
  event = "VeryLazy",
  opts = {},
}
```

2. Run `:Lazy sync` — LazyVim detects the new file and installs the plugin
3. Commit both the new file and the updated `lazy-lock.json`:

```bash
cd ~/dotfiles
git add nvim/lua/plugins/your-plugin.lua nvim/lazy-lock.json
git commit -m "feat: add your-plugin"
git push
```

---

### 10.22 The Edit → Apply → Verify → Commit Loop for Neovim Config

Every change to Neovim configuration follows the same loop:

```
1. Edit    → modify ~/dotfiles/nvim/lua/plugins/ or lua/config/
2. Apply   → :Lazy sync (for new/updated plugins) or save + reload (for config)
3. Verify  → confirm the feature works — :LspInfo, which binary, visual test
4. Commit  → cd ~/dotfiles && git add nvim/ && git commit && git push
```

For Home Manager–owned settings (e.g., adding the `neovim` package itself):

```
1. Edit    → modify home.nix
2. Apply   → hms
3. Verify  → confirm neovim or the tool is available
4. Commit  → cd ~/dotfiles && git add home.nix && git commit && git push
```

---

### Part 10 Summary

The central principle of this Part — and the one that carries across the entire stack — is that **tools belong to the project, not the editor**. LSP servers, formatters, and linters are declared in `devenv.nix`, run from `/nix/store`, and are identical for every developer on the project regardless of which editor they use. `mason = false` everywhere is not a limitation; it is the enforcement mechanism for this principle.

The four configuration vectors (LazyVim defaults → `plugins/` overrides → `config/` → `.lazy.lua` escape hatch) form a hierarchy. Work with the defaults as far as possible. Override at `plugins/` for tool integration. Use `.lazy.lua` only for per-project deviations that should not apply everywhere.

The `debugpy` exception (§10.13) is the most important "exception to the rule" in this Part. It cannot go in `devenv.nix packages`. It must be in `requirements.txt`. This is a `debugpy` architectural constraint, not a mistake in the setup.

**What carries forward:** Part 11 covers VS Code as the parallel editor path. It shares the entire project layer (`.editorconfig`, `pyproject.toml`, `devenv.nix`) with Neovim — no duplication, no conflict.

---

## Part 11: VS Code Configuration

> [!note] **What you now know**
> Neovim is configured with LSP, formatting, linting, and debugging for Python and TypeScript. The project-owns-its-config principle is implemented end to end. Part 11 covers VS Code as the parallel editor path.

---

> [!note] **What you will understand by the end of this part**
> - VS Code's role in this stack: a parallel editor path for when Neovim is not the right tool
> - The critical devenv/$PATH problem and why it is the most important VS Code configuration detail
> - How VS Code extensions replace Mason's role and how project-level `.vscode/` config works
> - The side-by-side comparison with Neovim so you can decide which editor to use for each task

VS Code and Neovim coexist in this stack without conflict. The project layer is entirely shared: `.editorconfig`, `pyproject.toml`, `pyrightconfig.json`, `tsconfig.json`, `.vscode/launch.json`, `devenv.nix`, and the CI pipeline are identical for both editors. A developer on either editor picks up the project's rules automatically.

The differences are all on the editor side, and smaller than you might expect.

---

### 11.1 Role in This Stack

VS Code reads `.vscode/launch.json` natively — this is its own format. It reads `.editorconfig`, `pyproject.toml`, `pyrightconfig.json`, and `tsconfig.json` through its extensions, exactly as those tools intend. The `mkhl.direnv` extension activates devenv inside VS Code's process so every extension uses the project-pinned binaries.

Where Neovim needed a global Home Manager plugin file (`formatting.lua`, `linting.lua`) to map filetypes to formatters and linters, VS Code uses `.vscode/settings.json` — a per-project file committed to the repository. This is actually more consistent with the "project owns its configuration" philosophy than the Neovim approach.

---

### 11.2 Installation

VS Code is installed via the official apt repository by `setup-desktop.sh` (Installation Step 5). The snap package is explicitly not used — the VS Code snap runs in a sandboxed filesystem that cannot access paths under `/nix/store`, which breaks the `mkhl.direnv` extension and prevents devenv binaries from being found.

Verify:

```bash
code --version
```

If `code` is not found after the bootstrap, the PATH may not include the apt-installed VS Code yet. Open a new shell and retry. If still not found, verify the apt repository was added:

```bash
apt list --installed 2>/dev/null | grep code
```

---

### 11.3 Extensions: What to Install and Why

Extensions are not installed automatically — `code --install-extension` requires a running display and fails when called from a setup script without one. Install them manually after the desktop is up (Installation Step 6):

```bash
jq -r '.recommendations[]' ~/dotfiles/vscode/extensions.json | xargs -I{} code --install-extension {}
```

`~/dotfiles/vscode/extensions.json` uses VS Code's native recommendations format. The global list covers all project types — per-project `.vscode/extensions.json` files (§11.5) trim this down to only what each project needs.

| Extension | Purpose |
|---|---|
| `ms-python.python` | Python language support, Pylance LSP, debugger |
| `ms-python.debugpy` | Python DAP debugging adapter |
| `charliermarsh.ruff` | Ruff linter and formatter (replaces flake8 + black) |
| `esbenp.prettier-vscode` | Prettier formatter for JS/TS/JSON/YAML/Markdown |
| `dbaeumer.vscode-eslint` | ESLint linter integration |
| `mkhl.direnv` | devenv environment activation — critical (see §11.6) |
| `ms-azuretools.vscode-docker` | Docker Compose integration, container management |
| `eamodio.gitlens` | Enhanced git history, inline blame, PR view |
| `redhat.vscode-yaml` | YAML with JSON schema validation |
| `tamasfe.even-better-toml` | TOML syntax and validation |
| `yzhang.markdown-all-in-one` | Markdown TOC, shortcuts, word count — useful for editing this guide |
| `bierner.markdown-mermaid` | Mermaid diagram rendering in VS Code's built-in preview (`Ctrl+Shift+V`) |

**How extensions replace Mason:** in Neovim, `:Mason` downloads and manages tool binaries. In VS Code, extensions either bundle the tools directly or manage them. You do not use a `:Mason`-equivalent in VS Code. The extension handles binary management internally:

|Tool|VS Code Extension|
|---|---|
|Ruff (lint + format)|`charliermarsh.ruff`|
|Pyright (Python LSP)|`ms-python.python` (bundles Pylance/Pyright)|
|Prettier|`esbenp.prettier-vscode`|
|ESLint|`dbaeumer.vscode-eslint`|
|TypeScript LSP|Built into VS Code — no extension needed|
|Biome|`biomejs.biome` (if your project uses Biome)|
|direnv integration|`mkhl.direnv`|

> [!important] `mkhl.direnv` is not optional This extension is what connects devenv to VS Code. Without it, every other extension uses the system `$PATH` rather than devenv's project-pinned binaries. The `charliermarsh.ruff` extension would find Home Manager's global `ruff` instead of the project's pinned version. `ms-python.python` would fail to find the virtualenv's Python. Install it and add it to `.vscode/extensions.json` in every project that uses devenv.

---

### VS Code Extensions List

Save as `vscode/extensions.json` in your dotfiles repository. Uses VS Code's native recommendations format — install with `jq -r '.recommendations[]' ~/dotfiles/vscode/extensions.json | xargs -I{} code --install-extension {}`.

```json
{
  "recommendations": [
    "ms-python.python",
    "ms-python.debugpy",
    "charliermarsh.ruff",
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "mkhl.direnv",
    "ms-azuretools.vscode-docker",
    "eamodio.gitlens",
    "redhat.vscode-yaml",
    "tamasfe.even-better-toml",
    "yzhang.markdown-all-in-one",
    "bierner.markdown-mermaid"
  ]
}
```

---

### 11.4 How Extensions Replace Mason

The Neovim side of this stack used `mason = false` in `lsp.lua` to tell LazyVim to find binaries on `$PATH` rather than in Mason's directory. VS Code extensions handle this differently: they expose a binary path setting that VS Code's direnv extension populates by activating the devenv environment.

The flow when `mkhl.direnv` is installed and active:

```
VS Code opens a file in the project
        ↓
mkhl.direnv reads .envrc → activates devenv shell inside VS Code
        ↓
$PATH = /nix/store/abc-ruff/bin
      : /nix/store/def-pyright/bin
      : ... (devenv's pinned binaries)
        ↓
charliermarsh.ruff finds /nix/store/abc-ruff/bin/ruff    ✓
ms-python.python finds /nix/store/def-pyright/bin/pyright ✓
esbenp.prettier-vscode finds /nix/store/.../prettier       ✓
```

Without `mkhl.direnv`, VS Code extensions search the system `$PATH` — finding Home Manager's global versions, not the project-pinned ones.

---

### 11.5 Project-Level VS Code Configuration

Three files live in `.vscode/` at the project root and are committed to the repository. Together they ensure every VS Code developer on the team gets format-on-save, linting, and extension recommendations without any manual configuration.

#### `.vscode/settings.json` — The VS Code Equivalent of `formatting.lua` and `linting.lua`

This is the most important VS Code project file. Where Neovim used global `formatting.lua` and `linting.lua` in the Home Manager config, VS Code uses this per-project file. The key difference: `.vscode/settings.json` is committed to the repository, making it genuinely per-project rather than per-machine.

```jsonc
// .vscode/settings.json
// Committed to the repository — applies to all VS Code users on this project.
// This file is the VS Code equivalent of formatting.lua + linting.lua.

{
  // ── Python interpreter ─────────────────────────────────────────────────────
  // Point VS Code at the virtualenv created by devenv.
  // devenv.nix: languages.python.venv.enable = true creates .venv/
  // If this path does not exist, run `devenv update` to activate the environment.
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",

  // ── Global format on save ─────────────────────────────────────────────────
  // Enables format-on-save for all filetypes that have a formatter configured.
  // Overridden per-language below where needed.
  "editor.formatOnSave": true,

  // ── Python: ruff handles both formatting and linting ──────────────────────
  // The ruff extension reads rules from pyproject.toml [tool.ruff] and
  // [tool.ruff.lint] automatically — this just activates it.
  "[python]": {
    // Use the Ruff extension for formatting (replaces black, isort separately)
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      // Run ruff's auto-fixable lint rules (import sorting, unused imports, etc.)
      "source.fixAll.ruff": "explicit",
      // Sort imports on save — equivalent to running isort
      "source.organizeImports.ruff": "explicit"
    }
  },

  // ── JavaScript and TypeScript: prettier ───────────────────────────────────
  // Prettier reads rules from .prettierrc in the project root.
  "[javascript]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[typescript]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[javascriptreact]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[typescriptreact]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },

  // ── Web assets: prettier ──────────────────────────────────────────────────
  "[html]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[css]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[json]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[yaml]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[markdown]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },

  // ── Prettier condition gate ────────────────────────────────────────────────
  // The VS Code equivalent of conform.nvim's condition gate.
  // Prevents prettier from running on JS/TS files in projects that have
  // no .prettierrc config — mirrors the condition function in formatting.lua.
  "prettier.requireConfig": true,

  // ── Ruff linter activation ────────────────────────────────────────────────
  "ruff.lint.enable": true,

  // ── ESLint linter activation ──────────────────────────────────────────────
  // Reads rules from .eslintrc.json or eslint.config.js in the project root.
  "eslint.enable": true,

  // ── Python type checking mode ──────────────────────────────────────────────
  // This can also be set in pyrightconfig.json — either location works.
  // If both are set, pyrightconfig.json wins.
  // Options: "off" | "basic" | "standard" | "strict"
  "python.analysis.typeCheckingMode": "basic",

  // ── Python analysis paths ──────────────────────────────────────────────────
  // Helps Pyright resolve imports for ERPNext/Frappe projects.
  // Adjust paths to match your project's app structure.
  "python.analysis.extraPaths": [
    "${workspaceFolder}"
  ],

  // ── Editor: trailing whitespace and final newlines ─────────────────────────
  // These mirror what .editorconfig sets — belt-and-suspenders for VS Code.
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,

  // ── Files to exclude from the explorer and search ─────────────────────────
  "files.exclude": {
    "**/__pycache__": true,
    "**/.venv": true,
    "**/node_modules": true,
    "**/.devenv": true,
    "**/dist": true
  },
  "search.exclude": {
    "**/__pycache__": true,
    "**/.venv": true,
    "**/node_modules": true,
    "**/.devenv": true
  }
}
```

**Verification:** open VS Code in the project, open the Output panel (`View → Output`), select `Ruff` from the dropdown. The output should show the binary path being used — it must show a `/nix/store/...` path. If it shows a system path, `mkhl.direnv` is not active or `direnv allow` has not been run.

#### `.vscode/extensions.json` — Recommended Extensions

This file causes VS Code to prompt new contributors to install the correct extensions when they open the project. No manual installation needed:

Start from the template for your project type below — include only what the project actually uses. `mkhl.direnv` belongs in every project that uses devenv.

**Python project:**

```json
{
  "recommendations": [
    "ms-python.python",
    "ms-python.debugpy",
    "charliermarsh.ruff",
    "mkhl.direnv",
    "redhat.vscode-yaml",
    "tamasfe.even-better-toml"
  ]
}
```

**TypeScript / JavaScript project:**

```json
{
  "recommendations": [
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "mkhl.direnv",
    "redhat.vscode-yaml"
  ]
}
```

> [!tip] If the project uses Biome instead of Prettier + ESLint, replace both with `"biomejs.biome"`.

**Markdown / documentation project:**

```json
{
  "recommendations": [
    "yzhang.markdown-all-in-one",
    "bierner.markdown-mermaid",
    "esbenp.prettier-vscode",
    "redhat.vscode-yaml"
  ]
}
```

The new VS Code developer onboarding flow once this file is committed:

```bash
git clone https://github.com/org/project.git
cd project
direnv allow      # activates devenv environment
just setup        # installs pre-commit hooks
code .            # VS Code opens, prompts to install recommended extensions → Yes
```

Four commands, fully configured editor with project-pinned tools.

#### `.vscode/launch.json` — Debug Configurations

This is VS Code's native debug configuration format. It is covered in full in §11.13, where the same file is read by both VS Code (natively) and Neovim's `nvim-dap` (via `load_launchjs()`). No additional setup is needed for VS Code beyond what was already created in §11.13.

---

### 11.6 The Devenv / `$PATH` Problem — The Most Important VS Code Configuration Detail

This section deserves its own treatment because the failure mode is silent and easy to miss.

**The problem:** VS Code does not inherit the shell's `$PATH` when launched from a GUI launcher (application menu, dock, file manager). When you double-click VS Code or launch it from Spotlight, it opens with a minimal system `$PATH` that contains no devenv binaries.

**Without `mkhl.direnv`:**

```
VS Code opens (launched from GUI)
        ↓
Extensions search $PATH for ruff, pyright, prettier
$PATH = /usr/bin:/usr/local/bin ...  ← system PATH only
        ↓
Extensions either fail to find tools
or find Home Manager's global versions (wrong pinned version)
        ↓
Formatting and linting "work" but use the wrong binary versions
Type checking may fail if pyright cannot find the project virtualenv
```

**With `mkhl.direnv` installed:**

```
VS Code opens any file in the project
        ↓
mkhl.direnv detects .envrc in the project root
        ↓
devenv environment activates inside VS Code's process
$PATH = /nix/store/abc-ruff-0.4.1/bin : ...  ← project's pinned tools
        ↓
All extensions use devenv's binaries ✓
```

**The two requirements for this to work:**

1. `mkhl.direnv` is installed (bootstrap installs it via `vscode/extensions.json`)
2. `direnv allow` has been run in the project directory (once per developer per repo)

**Verification:**

```
View → Output → select "Ruff" from the dropdown
```

The binary path shown must start with `/nix/store/`. If it shows `/home/yourusername/.nix-profile/bin/ruff` (Home Manager's global version) instead, `mkhl.direnv` is not activating. Check:

```bash
# Confirm direnv allow has been run
direnv status

# If status shows "Found .envrc" but "not loaded", run:
direnv allow
```

Then reload the VS Code window (`Ctrl+Shift+P` → "Developer: Reload Window").

---

### 11.7 `.neoconf.json` Has No VS Code Equivalent — And Needs None

`.neoconf.json` exists because Neovim's LSP configuration is programmatic (Lua) with no JSON-based project config mechanism. VS Code extensions read their settings directly from `.vscode/settings.json` — there is no gap to bridge. Settings that go in `.neoconf.json` for Neovim either go into `.vscode/settings.json` for VS Code, or better, into native tool config files (`pyrightconfig.json`, `tsconfig.json`) where both editors read them automatically.

---

### 11.8 `.lazy.lua` Has No VS Code Equivalent — And None Is Needed

`.lazy.lua` exists because Neovim's plugin system is programmatic and global, requiring a per-project Lua escape hatch for overrides. VS Code's per-project configuration _is_ `.vscode/settings.json` — it is the primary mechanism, not a last resort. Every override you would put in `.lazy.lua` either belongs in `.vscode/settings.json` or was already in a project config file.

---

### 11.9 Side-by-Side Comparison: Neovim vs. VS Code

The full equivalence table covering every category where the two editors differ in implementation while sharing the same project-level files.

|Concern|Neovim (Home Manager global config)|VS Code|
|---|---|---|
|**Format on save**|`conform.nvim` in `lua/plugins/formatting.lua` — global, per-machine|`.vscode/settings.json` `"editor.formatOnSave": true` — committed to repo|
|**Lint on save**|`nvim-lint` in `lua/plugins/linting.lua` — global, per-machine|`.vscode/settings.json` `"ruff.lint.enable": true` + extension|
|**Condition gate**|`condition` function in `formatters` block (conform.nvim) and linter object patch (nvim-lint)|`"prettier.requireConfig": true` and equivalent extension settings|
|**Formatter rules**|`pyproject.toml`, `.prettierrc`, `stylua.toml` — project files, editor-agnostic|Same — identical|
|**Linter rules**|`pyproject.toml [tool.ruff.lint]`, `.eslintrc.json`, `.yamllint` — project files|Same — identical|
|**LSP server rules**|`pyrightconfig.json` / `pyproject.toml [tool.pyright]` / `tsconfig.json` — project files|Same — identical|
|**LSP editor settings**|`.neoconf.json` in project root|`.vscode/settings.json` language-specific keys|
|**Binary installation**|Mason (global, version-insensitive servers) + devenv (per project, `mason = false`)|Extensions bundle tools + devenv provides pinned versions|
|**devenv / `$PATH`**|Automatic — Neovim inherits shell `$PATH` when launched from terminal|Requires `mkhl.direnv` extension; breaks silently if not installed|
|**Debug configs**|`.vscode/launch.json` read via `require("dap.ext.vscode").load_launchjs()`|`.vscode/launch.json` — native format|
|**Per-project overrides**|`.lazy.lua` — last resort, requires trust approval per developer|`.vscode/settings.json` — primary mechanism, committed to repo|
|**Recommended extensions**|`:LazyExtras` (global, per-machine, interactive)|`.vscode/extensions.json` (committed to repo, prompts automatically)|
|**pre-commit / CI**|Identical — editor-agnostic|Identical — editor-agnostic|

**The pattern across every row:** project-level concerns (rules, configs, launch configs) are identical between editors. Editor-side concerns (how to activate a formatter, where to find the binary, how to enable a linter) differ in mechanism but produce the same result when the project is configured correctly.

---

### 11.10 How to Change or Add VS Code Settings

**Project-level settings (shared with the whole team):**

Edit `.vscode/settings.json`, commit, push. Every VS Code developer on the team gets the change on their next `git pull`.

```bash
nvim .vscode/settings.json
# Make changes
git add .vscode/settings.json
git commit -m "chore: enable eslint for this project"
git push
```

**User-level settings (personal, not committed):**

`Ctrl+Shift+P` → "Open User Settings (JSON)". These apply to all projects on your machine and are not version-controlled.

**Adding a new extension to project recommendations:**

Add the extension ID to `.vscode/extensions.json` `recommendations` array and commit. The next time a teammate opens the project in VS Code, they will be prompted to install it.

**Adding a new extension to your list:**

Add the extension ID to `~/dotfiles/vscode/extensions.json`, install it, then commit:

```bash
# Edit the recommendations array in extensions.json, then:
code --install-extension new-publisher.new-extension
git -C ~/dotfiles add vscode/extensions.json
git -C ~/dotfiles commit -m "feat: add new-extension to VS Code list"
git -C ~/dotfiles push
```

---

### 11.11 The Edit → Apply → Verify → Commit Loop for VS Code Config

Every change to VS Code project configuration follows the same loop:

```
1. Edit    → modify .vscode/settings.json, extensions.json, or launch.json
2. Apply   → VS Code picks up the change immediately (no reload needed for settings)
3. Verify  → confirm the formatter, linter, or extension works as expected
4. Commit  → git add .vscode/ && git commit && git push
```

For personal extensions:

```
1. Edit    → add to ~/dotfiles/vscode/extensions.json
2. Apply   → code --install-extension publisher.extension
3. Verify  → confirm the extension is active
4. Commit  → cd ~/dotfiles && git add vscode/extensions.json && git commit && git push
```

---

### Part 11 Summary

VS Code and Neovim share the entire project layer — `.editorconfig`, `pyproject.toml`, `pyrightconfig.json`, `devenv.nix`, and `.vscode/launch.json` are identical for both editors. There is no duplication and no conflict. A teammate on either editor picks up the same formatting rules, the same LSP config, and the same debug launch configuration automatically.

The devenv / `$PATH` problem (§11.6) is the single most important VS Code configuration detail. Without the `mkhl.direnv` extension activating first, every other extension (`pylance`, `eslint`, the debugger) uses system binaries instead of the project's pinned versions. Verify with `which python` from the VS Code integrated terminal — it must resolve to a `/nix/store/...` path, not `/usr/bin/python`.

VS Code extensions are not managed by Home Manager. After a fresh bootstrap, install them with the one-liner from `~/dotfiles/vscode/extensions.json`.

---

**Next:** [6-Desktop.md — Graphical Desktop (Optional)](6-Desktop.md)
