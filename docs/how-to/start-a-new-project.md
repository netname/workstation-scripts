# Start a New Project

Use this guide to create a project that works with the workstation stack: git, devenv, direnv, Docker Compose, and editor tooling.

## 1. Create the Repository

```bash
mkdir -p ~/projects/my-project
cd ~/projects/my-project
git init
```

Create the remote repository in GitHub, then add it:

```bash
git remote add origin git@github.com:yourusername/my-project.git
```

## 2. Add Project Environment Files

```bash
cp ~/workstation-scripts/templates/devenv.nix ./devenv.nix
cp ~/workstation-scripts/templates/docker-compose.yml ./docker-compose.yml
cp ~/workstation-scripts/templates/.env.example ./.env.example
cp .env.example .env
printf '.env\n' > .gitignore
printf 'use devenv\n' > .envrc
```

Edit `devenv.nix`, `docker-compose.yml`, and local `.env` values for the project. Commit `.env.example`, but keep `.env` local.

## 3. Allow direnv

```bash
direnv allow
```

Verify the environment loads:

```bash
devenv --version
which python || true
which node || true
```

## 4. Start Optional Services

```bash
docker compose up -d
docker compose ps
```

## 5. Add Editor Configuration

Use project-local editor settings for language behavior and keep global editor preferences in dotfiles.

For Neovim, open the project from a direnv-enabled shell. For VS Code, install the `mkhl.direnv` extension so language tools inherit the project environment.

## 6. Commit the Starting Point

```bash
git add .
git commit -m "chore: initialize project"
git push -u origin main
```

For concepts, see [Project Tooling Model](../explanation/project-tooling-model.md) and [Editor Environment Model](../explanation/editor-environment-model.md).
