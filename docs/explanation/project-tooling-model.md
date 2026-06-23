# Project Tooling Model

Global tools and project tools serve different needs.

Home Manager provides stable personal tools: shell, git, tmux, editors, common CLIs.

Devenv provides project tools: language versions, formatters, linters, test tools, and language servers that should match the project.

Docker Compose provides stateful services: databases, queues, caches, and other long-running dependencies.

Direnv connects the shell to the project. When you enter a directory, it activates the environment declared by that project.

This prevents one project from forcing global tool versions onto every other project.

## Why Not Install Everything Globally?

Global tools are convenient, but they create drift when projects need different versions. A Python formatter, Node runtime, or language server that works for one project can quietly break another.

The stack keeps durable personal tools global and project-sensitive tools local. That means `git`, `tmux`, `gh`, and `nvim` are always available, while `pyright`, `ruff`, Node, Python, and service dependencies can follow each project.

## Tradeoff

The tradeoff is an extra activation step: each project needs `.envrc` and `direnv allow`. In exchange, the project describes its own environment and new contributors do not need to reverse-engineer your global machine state.
