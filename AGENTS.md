# Agent Behavioural Rules — homebrew-epics

These rules apply to all AI coding agents (GitHub Copilot, Claude, etc.) working in
this repository. Read this file before making any changes to Formula files or workflows.

For project background and architectural decisions, read [docs/CONTEXT.md](docs/CONTEXT.md).
For the full module dependency graph, canonical versions and upstream URLs, read
[docs/EPICS_VERSIONS.md](docs/EPICS_VERSIONS.md). For step-by-step formula authoring,
use the skill at [.github/skills/brew-formula/SKILL.md](.github/skills/brew-formula/SKILL.md).

---

## 1. Formula Quality Gates

### 1.1 `brew audit --strict` is mandatory before declaring a formula done

Run this before finishing any formula work:

```sh
brew audit --strict --new Formula/<name>.rb   # for new formulae
brew audit --strict Formula/<name>.rb          # for updates
```

Fix **every** warning and every error. A formula with outstanding audit issues is not
complete. If an audit rule genuinely does not apply, add a comment explaining why.

### 1.2 Every formula must have a `livecheck` block

EPICS Base uses dot-separated tags (`R7.0.10`); support modules use dash-separated
tags (`R4-44-2`, `R1-7-4`). The livecheck regex handles both with `[.-]`:

```ruby
livecheck do
  url :stable
  strategy :github_latest
  regex(/^R(\d+(?:[.-]\d+)+)$/i)
end
```

For modules that do **not** use EPICS tag conventions (StreamDevice uses plain semver
tags like `2.8.24`), adjust accordingly:

```ruby
livecheck do
  url :stable
  strategy :github_latest
  regex(/^v?(\d+(?:\.\d+)+)$/i)
end
```

Do not omit livecheck. It is required for `brew bump-formula-pr` and autobump CI to work.

### 1.3 Always use `opt_prefix` for cross-formula EPICS dependencies

When one formula references another EPICS formula's installation directory, always use
`Formula["epics-base"].opt_prefix`, never `Formula["epics-base"].prefix`. The `prefix`
method resolves to the versioned Cellar path (`/opt/homebrew/Cellar/epics-base/7.0.10/`)
and will be baked into installed `configure/RELEASE` files, breaking them when the
formula is upgraded.

The standard approach is to write a `configure/RELEASE.local` file with the correct
paths, rather than patching `configure/RELEASE` directly:

```ruby
# CORRECT — write RELEASE.local with stable opt_prefix symlinks
(buildpath/"configure/RELEASE.local").write <<~EOS
  EPICS_BASE=#{Formula["epics-base"].opt_prefix}
  ASYN=#{Formula["epics-asyn"].opt_prefix}
EOS

# Also ensure configure/RELEASE includes RELEASE.local (append if missing)
release = buildpath/"configure/RELEASE"
unless release.read.include?("RELEASE.local")
  release.open("a") { |f| f.puts "\n-include $(TOP)/configure/RELEASE.local" }
end

# WRONG — bakes /opt/homebrew/Cellar/epics-base/7.0.10 into installed files
# (and mutates the original configure/RELEASE unnecessarily)
inreplace "configure/RELEASE",
  /^EPICS_BASE\s*=.*/,
  "EPICS_BASE=#{Formula["epics-base"].prefix}"
```

See [.github/skills/brew-formula/configure-release.md](.github/skills/brew-formula/configure-release.md)
for the full reference including per-module variable names and complete examples.

### 1.4 Never hardcode path prefixes

The following strings must never appear literally in formula Ruby code:

- `/usr/local`
- `/opt/homebrew`
- `/home/linuxbrew/.linuxbrew`
- Any string produced by `prefix` (which embeds the Cellar version component)

Use `opt_prefix` for references to *other* formulae. Use `prefix` only when installing
the formula's own files inside `install do`.

### 1.5 Every formula must have a `test do` block

Every formula must include a `test do` block that asserts the module's shared library
is present in the arch-specific output directory (`lib/<epics_arch>/`). See
[.github/skills/brew-formula/SKILL.md](.github/skills/brew-formula/SKILL.md) Step 8
for the standard pattern.

### 1.6 `keg_only` for Base and support module formulae

Every formula that installs **libraries or headers** that other formulae link against
must contain:

```ruby
keg_only :versioned_formula
```

This prevents symlinking into the Homebrew prefix and avoids conflicts between EPICS
versions. This applies to `epics-base` and all support modules (asyn, autosave, busy,
calc, seq, sscan, std, streamdevice, motor, etc.).

**Exception — standalone GUI applications and display tools**: Formulae for apps such
as Phoebus, EDM, MEDM, or other operator display tools do **not** need `keg_only`.
These formulae are not linked against by other formulae, and users typically install
only one version at a time. Omit `keg_only` for app-style formulae unless there is a
specific, documented conflict reason.

### 1.7 Bottle annotations: `cellar: :any` vs `cellar: :any_skip_relocation`

| Situation | Cellar annotation |
|-----------|-------------------|
| Formula installs `.dylib` / `.so` shared libraries | `cellar: :any` |
| Formula is static-only (`.a` files, headers, scripts) | `cellar: :any_skip_relocation` |
| Formula installs a mix (prefer conservative choice) | `cellar: :any` |

All EPICS formulae that link to other EPICS modules produce shared libraries and must
use `cellar: :any`. The bottle `root_url` must point to GHCR:

```ruby
bottle do
  root_url "https://ghcr.io/v2/<org>/homebrew-epics"
  cellar :any
  sha256 arm64_tahoe:   "..."
  sha256 arm64_sequoia: "..."
  sha256 arm64_sonoma:  "..."
  sha256 sonoma:        "..."
  sha256 arm64_linux:   "..."
  sha256 x86_64_linux:  "..."
end
```

Replace `<org>` with the actual GitHub organisation hosting this tap.

---

## 2. Dependency Graph

The authoritative dependency graph lives in
[docs/EPICS_VERSIONS.md](docs/EPICS_VERSIONS.md). Consult it before adding or changing
`depends_on` lines. When adding a dependency not listed there, verify it does not
create a cycle and document it in [docs/CONTEXT.md](docs/CONTEXT.md).

---

## 3. `revision` vs Version Bump

| Situation | Action |
|-----------|--------|
| New upstream release available | Bump `version`, reset `revision` to 0 (remove the `revision` line) |
| Rebuild against new `epics-base`, same module version | Increment `revision` by 1 |
| Formula bug fix using the same source tarball | Increment `revision` by 1 |
| New platform added to bottle block | Increment `revision` by 1 |
| Significant compiler flag change affecting binary compatibility | Increment `revision` by 1 |

When `epics-base` is updated, **every formula that depends on it** must have its
`revision` incremented. The `bump-dependents.yml` workflow opens PRs for these
automatically. After it runs, verify each PR and merge in dependency order (base first).

---

## 4. Commit Message Format

```
epics-asyn: update 4.44.2 bottle
epics-base: 7.0.10 (new formula)
epics-motor: bump revision for epics-base 7.0.10
epics-base: update livecheck regex
```

Format: `<formula-name>: <imperative lowercase description>`. No trailing period.
Use the formula name exactly as it appears in the `Formula/` directory (without `.rb`).

---

## 5. Build System Notes

- **Compiler**: Apple Clang only on macOS. Never add `depends_on "gcc"`. The EPICS
  darwin configuration in `configure/os/CONFIG.darwin` already targets Apple Clang
  and sets the correct flags. Do not override `CC`, `CXX`, or `FC`.
- **Parallel builds**: EPICS supports parallel make. Do not call `ENV.deparallelize`
  unless a specific race condition is documented in a comment.
- **Architecture**: EPICS detects `darwin-aarch64` vs `darwin-x86_64` automatically
  via `uname`. Do not force `EPICS_HOST_ARCH`.
- **Linux bottles**: When building for `arm64_linux` / `x86_64_linux`, the EPICS
  host arch is `linux-aarch64` / `linux-x86_64`. Linuxbrew path is
  `/home/linuxbrew/.linuxbrew`; never hardcode it.

---

## 6. Writing a New Formula

Follow the step-by-step process in
[.github/skills/brew-formula/SKILL.md](.github/skills/brew-formula/SKILL.md).
Verify `docs/EPICS_VERSIONS.md` is current first — if not, run the
[update-epics-versions skill](.github/skills/update-epics-versions/SKILL.md) before
authoring the formula.
