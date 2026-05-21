# CI Pipeline

This repository has two GitHub Actions workflows. They run in sequence: the first
builds and validates; the second publishes. Neither starts the other automatically —
a human action (adding a label) bridges them.

---

## Workflow 1 — `brew test-bot` (`tests.yml`)

**Trigger:** Every pull request (any branch → main), and every push to `main`.

**Platform:** `macos-15` (Apple Silicon, `arm64_sequoia`).

**Concurrency:** One run per ref; a new push cancels any in-progress run for the same ref.

**What it does:**

| Step | Runs on | What happens |
|------|---------|--------------|
| Cleanup / setup | always | `brew test-bot --only-cleanup-before` and `--only-setup` reset the Homebrew environment |
| Tap syntax check | always | `brew test-bot --only-tap-syntax` — lints all `.rb` files; uses `--except=installed` internally to skip EPICS cellar checks |
| Build changed formulae | PR only | For each `Formula/*.rb` file changed in the PR: install deps → build from source (`--build-bottle`) → audit (`--except=installed`) → run test block → linkage check |
| Package bottles | PR only | `brew bottle --json` produces a `.bottle.tar.gz` + `.bottle.json` per formula; sha256 is merged back into the formula file |
| Sanity check | PR only | Fails the job if formula files changed but no bottles were produced |
| Upload artifact | PR only | All bottle files are uploaded as a single artifact named `bottles_macos-15` |

**Outcome:** A green check on the PR, plus a `bottles_macos-15` artifact attached to
the run. The artifact is what the publish workflow consumes.

**On a push to `main`** (e.g. after a PR is merged): the build and bottle steps are
skipped (they only run on `pull_request` events). Only cleanup, setup, and tap-syntax
run, so the job completes quickly.

---

## Workflow 2 — `brew pr-pull` (`publish.yml`)

**Trigger:** A `labeled` event on a pull request — specifically when the label
`pr-pull` is added by a maintainer.

**Platform:** `ubuntu-latest` (x86\_64). The bottles it handles were built on macOS;
this job only orchestrates — it does not build.

**Permissions required:** `contents: write`, `packages: write`, `pull-requests: write`.

**What it does:**

| Step | What happens |
|------|--------------|
| Set up Homebrew | Clones the tap and configures git credentials |
| Set up git | Configures `user.name` / `user.email` for the commit that will be made |
| Pull bottles | `brew pr-pull` does all the heavy lifting (see below) |
| Push commits | `git-try-push` pushes the new commits to `main` (retries on race) |
| Delete branch | Deletes the PR's head branch from origin |

**What `brew pr-pull` does internally:**

1. Cherry-picks all commits from the PR branch onto the local `main`
2. Finds the latest passing CI run for the PR and downloads the `bottles_*` artifact
3. Updates the formula file: sets `root_url`, adds the real `sha256` for each platform
4. Commits the formula update with a message like `epics-base: update 7.0.10_2 bottle.`
5. Calls `brew pr-upload` to push the `.bottle.tar.gz` files to GHCR

After `brew pr-pull` finishes, `git-try-push` pushes all accumulated commits (the
original PR commits + the bottle update commit) to `main`. Then the PR branch is
deleted, which causes GitHub to close the PR.

**Outcome:** The PR is closed (not merged via GitHub's merge button — `brew pr-pull`
uses a direct push). `main` has two new commits. The bottle is live on GHCR and
installable via `brew install`.

---

## End-to-end flow for a formula change

```
Developer                 GitHub Actions              Maintainer
─────────                 ──────────────              ──────────
Create branch
Bump formula
Open PR          ──────►  tests.yml runs
                          • builds formula
                          • packages bottle
                          • uploads artifact
                          • PR check goes green
                                              ◄──────  Review + add 'pr-pull' label
                          publish.yml runs
                          • cherry-picks PR commits
                          • downloads artifact
                          • updates formula sha256
                          • pushes bottle to GHCR
                          • pushes commits to main
                          • deletes branch / closes PR
```

---

## GHCR bottle location

Bottles are stored in the GitHub Container Registry under:

```
ghcr.io/ulrikpedersen/epics/<formula-name>:<version>_<revision>
```

Example: `ghcr.io/ulrikpedersen/epics/epics-base:7.0.10_2`

Browse published packages at:
<https://github.com/ulrikpedersen?tab=packages>

> **Namespace note:** Homebrew strips the `homebrew-` prefix from the tap repository
> name when deriving the GHCR package path. The tap is `homebrew-epics`; the GHCR
> namespace is `epics`.

---

## Adding a new platform

1. Add the new runner to `runs-on:` in `tests.yml`.
2. Add a placeholder `sha256 <platform>:` line to the formula's `bottle do` block.
3. Increment `revision` by 1 (rebuilding for a new platform is a bottle change).
4. Open a PR → CI builds the new platform bottle → add `pr-pull` label to publish.
