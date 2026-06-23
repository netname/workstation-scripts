# Cut a Release

Use this guide when a repository is ready for a tagged GitHub release.

## Pre-Flight

Start from an up-to-date `main`:

```bash
git switch main
git pull --ff-only
git status --short
```

Run the repository checks:

```bash
just check
# or the repo's documented check command
```

Review the commits since the previous tag:

```bash
git tag --sort=-creatordate
git log --oneline <previous-tag>..HEAD
```

## Choose a Version

Use the repository's versioning policy. If there is no formal policy, keep it simple:

| Change type | Version move |
|---|---|
| Breaking user-facing behavior | major |
| New backwards-compatible feature | minor |
| Bug fix or documentation-only release | patch |

## Create the Release

Create and push an annotated tag:

```bash
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

Create the GitHub release:

```bash
gh release create v1.2.3 --title "v1.2.3" --notes-file RELEASE_NOTES.md
```

If you do not have a release notes file, let `gh` generate notes:

```bash
gh release create v1.2.3 --title "v1.2.3" --generate-notes
```

## Release Notes Shape

Use sections that help future readers scan:

```markdown
## What's Changed

### Features

- ...

### Bug Fixes

- ...

### Maintenance

- ...

## Verification

- ...
```

## Pre-Releases

Use a pre-release for release candidates or validation builds:

```bash
gh release create v1.2.3-rc.1 --prerelease --generate-notes
```

## Inspect or Delete a Release

```bash
gh release list
gh release view v1.2.3
git tag --list
```

Delete with care:

```bash
gh release delete v1.2.3
git push origin :refs/tags/v1.2.3
git tag -d v1.2.3
```

## Check Out a Historical Release

```bash
git switch --detach v1.2.3
```

Return to main:

```bash
git switch main
```

## Hotfix From a Tag

```bash
git switch -c hotfix/v1.2.4 v1.2.3
# make the fix
git add <files>
git commit -m "fix: describe hotfix"
```

Merge or cherry-pick the hotfix according to the repository's branch policy.
