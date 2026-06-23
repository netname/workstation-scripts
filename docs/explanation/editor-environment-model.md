# Editor Environment Model

Editors need to see the same project tools that the terminal sees.

The common failure mode is that a terminal shell activates direnv and devenv, but an editor process starts outside that environment. Then LSPs, formatters, and debuggers resolve to missing or wrong binaries.

## Neovim

Open Neovim from an activated project shell when possible. Configure language servers to use project-provided binaries rather than editor-global installers when the project owns the tool version.

## VS Code

VS Code needs direnv integration so extensions inherit the project environment. Without it, extensions may use system PATH or global tools.

## Debuggers

Debuggers are special because they attach to running processes. Some need packages installed inside a project virtualenv or runtime environment rather than only listed as global editor dependencies.

The goal is one source of truth: project behavior comes from project configuration.

## Why Not Let Editors Install Everything?

Editor package managers are convenient for UI plugins, but language tooling is part of the project contract. If Mason, VS Code extensions, or global npm packages install language servers independently, the editor can disagree with CI or with another developer's shell.

Use editor plugin managers for editor behavior. Use `devenv.nix` for project behavior.

## Tradeoff

This model asks you to pay attention to how the editor is launched. Neovim should start from an activated project shell, and VS Code needs direnv integration. The payoff is that diagnostics, formatting, tests, and CLI behavior all resolve the same project-owned tools.
