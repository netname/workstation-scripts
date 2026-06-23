# First Project Environment

This tutorial gives you a first successful encounter with project-local tooling.

By the end, entering a project directory will activate direnv, load a devenv shell, and make project tools available without installing them globally.

## Success Criteria

You are done when `direnv allow` succeeds, project tools resolve only inside the project directory, optional Docker services start, and the environment files are committed.

## What This Tutorial Does Not Do

This tutorial does not choose a production deployment model, install project dependencies for a specific framework, or design secret rotation. It only establishes the local development environment pattern.

## 1. Create a Project Directory

```bash
mkdir -p ~/projects/example-app
cd ~/projects/example-app
git init
```

## 2. Add `devenv.nix`

Start with the template from `workstation-scripts`.

```bash
cp ~/workstation-scripts/templates/devenv.nix ./devenv.nix
```

Edit it for the language and tools your project needs. Keep project runtimes here, not in global Home Manager packages.

## 3. Add `.envrc`

```bash
printf 'use devenv\n' > .envrc
direnv allow
```

When direnv activates successfully, the shell prompt should return with the project environment loaded.

## 4. Verify Project Tools

Run a tool declared by the project environment.

```bash
devenv --version
which python || true
which node || true
```

Only the tools declared for the project should appear from the project environment.

## 5. Add Optional Services

If the project needs stateful services, copy and adapt the Docker Compose template.

```bash
cp ~/workstation-scripts/templates/docker-compose.yml ./docker-compose.yml
cp ~/workstation-scripts/templates/.env.example ./.env.example
cp .env.example .env
printf '.env\n' > .gitignore
```

Edit `.env` before starting services if the default local passwords or ports are not appropriate. Commit `.env.example`, not `.env`.

```bash
docker compose up -d
docker compose ps
```

## 6. Commit the Project Scaffolding

```bash
git add devenv.nix .envrc docker-compose.yml .env.example .gitignore
git commit -m "chore: add project environment"
```

For a fuller task guide, see [Start a New Project](../how-to/start-a-new-project.md). For the model behind this split, see [Project Tooling Model](../explanation/project-tooling-model.md).
