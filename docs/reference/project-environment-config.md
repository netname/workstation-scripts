# Project Environment Config

Project environments are owned by the project, not by global workstation configuration.

## Files

| File | Purpose |
|---|---|
| `devenv.nix` | Declares project-local tools and languages |
| `.envrc` | Lets direnv activate devenv on directory entry |
| `docker-compose.yml` | Runs stateful services such as databases and caches |
| `.env.example` | Documents non-secret environment variables |
| SOPS-encrypted files | Store committed encrypted secrets |

## Checks

```bash
direnv status
direnv allow
devenv --version
docker compose ps
sops --version
age-keygen -y ~/.config/sops/age/keys.txt
```

## Placement Rules

- Put project runtimes, LSPs, formatters, and test tools in `devenv.nix`.
- Put databases, queues, caches, and other stateful services in Docker Compose.
- Put stable personal shell tools in Home Manager.
- Keep plaintext secrets out of git; commit only encrypted SOPS files.

## Expected Values

| Setting | Expected pattern |
|---|---|
| `.envrc` | `use devenv` |
| Docker ports | bind to `127.0.0.1`, not all interfaces |
| database passwords | loaded from `.env` or SOPS, not hard-coded |
| language servers | declared per project when version-sensitive |

## Activation Chain

The expected activation chain is:

1. You `cd` into a project.
2. direnv reads `.envrc`.
3. `.envrc` runs `use devenv`.
4. devenv evaluates `devenv.nix`.
5. Project tools, language servers, and environment variables become available in that shell.

If `.envrc` changes, run:

```bash
direnv allow
```

## Docker Compose Rules

Use Docker Compose for stateful services such as databases, queues, object stores, and caches. Keep application source code on the host during development so editors, language servers, tests, and git all see the same files.

Safe default port binding:

```yaml
ports:
  - "127.0.0.1:5432:5432"
```

Avoid binding development databases to all interfaces unless the project explicitly needs LAN access.

## SOPS and Environment Data

Use three tiers:

| Data type | Where it belongs |
|---|---|
| Public defaults | committed config or `.env.example` |
| Local non-secret overrides | uncommitted `.env` |
| Secrets | SOPS-encrypted files |

Use the `env` attrset in `devenv.nix` for literal non-secret values. If a value depends on variables from `.env` or SOPS, derive it in `enterShell` after those files have been loaded; shell expansions such as `${VAR:-default}` are not valid inside Nix strings.

## Common Failure States

| Symptom | First check |
|---|---|
| project tools missing | `direnv status` and `direnv allow` |
| service port exposed too widely | inspect `docker-compose.yml` port bindings |
| editor uses global formatter | launch/reload editor from active project environment |
| SOPS file cannot decrypt | `age-keygen -y ~/.config/sops/age/keys.txt` |

See [Project Tooling Model](../explanation/project-tooling-model.md).
