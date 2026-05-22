---
name: brew-formula
description: >
  Activates when asked to write or update an EPICS Homebrew formula. Provides
  step-by-step authoring guidance, required-fields checklist, livecheck templates,
  configure/RELEASE.local dependency injection, cellar annotation decisions, test block
  requirements, and the mandatory brew audit --strict gate.
applyTo: "Formula/**/*.rb"
---

# Formula Authoring Skill — EPICS Homebrew Tap

Use this skill whenever you are asked to write a new formula, update an existing
formula version, add a bottle block, or fix audit failures in this tap.

---

## Step-by-step authoring process

### Step 1 — Verify the local docs are current

**Before writing a single line of Ruby**, confirm that `docs/EPICS_VERSIONS.md` already
has an up-to-date entry for the module you are packaging. If it does not — or if you
are unsure — stop here and run the **update-epics-versions** skill first
([../update-epics-versions/SKILL.md](../update-epics-versions/SKILL.md)).

Once the docs are current, collect the following from them:

1. **Version and URL**: Find the target formula's row in the package table. Copy the
   exact version string and archive URL. Do not invent URLs from memory.

2. **Tag format**: Note the tag format (e.g. `R4-44-2` vs `2.8.24`). This determines
   the livecheck regex.

3. **Dependencies**: Check the dependency graph and the per-package section in
   [../../docs/EPICS_VERSIONS.md](../../docs/EPICS_VERSIONS.md).
   List all build-time and run-time dependencies. Note which are `:build`-only.

4. **Build quirks**: Read the per-package notes in `EPICS_VERSIONS.md` for any special
   configure flags, extra build-time tools, or non-standard RELEASE variable names.

### Step 2 — Set up the formula skeleton

Copy the structure from [exemplar-formula.rb](exemplar-formula.rb) and adapt:

- Rename the class to match the filename: `epics-asyn.rb` → `class EpicsAsyn`
- Set `desc`, `homepage`, `url`, `version` (for dash-style tags), `sha256`
- Add the `livecheck` block immediately after `version`
- Add the `bottle do` block
- Add `keg_only :versioned_formula`
- Add `depends_on` lines

### Step 3 — Write the livecheck block

**For EPICS R-prefixed tags** — Base uses dots (`R7.0.10`); support modules use dashes
(`R4-44-2`, `R7-0-10`, `R2-11-5`, `R5-11`). One regex handles both:

```ruby
livecheck do
  url :stable
  strategy :github_latest
  regex(/^R(\d+(?:[.-]\d+)+)$/i)
end
```

**For plain semver tags** (StreamDevice `2.8.24`, seq if it uses plain tags):

```ruby
livecheck do
  url :stable
  strategy :github_latest
  regex(/^v?(\d+(?:\.\d+)+)$/i)
end
```

The regex **must** capture only the numeric portion (the capture group), not the full
tag. Homebrew's livecheck compares the captured value against the formula's `version`
field after normalising separators (`.` and `-` are treated as equivalent).

Test the livecheck before finalising the formula. There is no MCP tool for
`brew livecheck` — use the terminal:
```sh
brew livecheck --tap local/epics --verbose
```

### Step 4 — Write the bottle block

All formulae use GHCR and target six platforms. The `cellar` annotation was **removed
in Homebrew 4.x** — do not include it; `brew audit` will error. Homebrew now infers
relocatability automatically during `brew test-bot` bottling.

```ruby
bottle do
  root_url "https://ghcr.io/v2/<org>/epics"
  sha256 arm64_tahoe:   "0000000000000000000000000000000000000000000000000000000000000000"
  sha256 arm64_sequoia: "0000000000000000000000000000000000000000000000000000000000000000"
  sha256 arm64_sonoma:  "0000000000000000000000000000000000000000000000000000000000000000"
  sha256 sonoma:        "0000000000000000000000000000000000000000000000000000000000000000"
  sha256 arm64_linux:   "0000000000000000000000000000000000000000000000000000000000000000"
  sha256 x86_64_linux:  "0000000000000000000000000000000000000000000000000000000000000000"
end
```

> **GHCR namespace**: Use `<org>/epics`, not `<org>/homebrew-epics`. Homebrew strips
> the `homebrew-` prefix from the tap name when deriving the GHCR package path.

Real SHA256 hashes are filled in by the custom CI build loop during CI. Use 64-character
hex placeholder strings (e.g. all-zeros) — text like `"placeholder_until_ci_runs"`
fails audit with `Invalid sha256 hash`.

### Step 5 — Add `keg_only` (support modules only)

```ruby
keg_only :versioned_formula
```

Required for `epics-base` and all support module formulae. Place it after the
`bottle do` block and before `depends_on`.

**Skip this step** for standalone GUI application formulae (Phoebus, EDM, MEDM, etc.).
Those are apps, not libraries; nothing links against them and only one version is
typically installed at a time.

### Step 6 — Add dependencies

```ruby
depends_on "re2c" => :build           # build-only tool (not needed at runtime)
depends_on "cmake" => :build          # build-only tool
depends_on "epics-base"               # runtime dependency (default)
depends_on "epics-asyn"               # runtime dependency
```

Rules:
- EPICS module dependencies (epics-base, epics-asyn, etc.) are almost always both
  build-time and run-time. Do **not** mark them `:build`.
- Tools like `cmake`, `re2c`, `python` used only during `install do` get `=> :build`.
- Do not add `depends_on "gcc"` — Apple Clang is the compiler on macOS.

Dependency ordering guardrail (to avoid follow-up style fixes):

```ruby
# ✅ preferred
depends_on "re2c" => :build
depends_on "epics-base"
depends_on "epics-asyn"

# ❌ avoid mixing order
depends_on "epics-base"
depends_on "re2c" => :build
```

### Step 7 — Write the `install` method

The EPICS build system is invoked with `make`. Before invoking make, write a
`configure/RELEASE.local` file with dependency paths, and ensure `configure/RELEASE`
includes it:

```ruby
def install
  # 1. Write configure/RELEASE.local with Homebrew-specific dependency paths.
  #    Variables here override the placeholder paths in configure/RELEASE.
  #    Always use opt_prefix, never prefix.
  (buildpath/"configure/RELEASE.local").write <<~EOS
    EPICS_BASE=#{Formula["epics-base"].opt_prefix}
    ASYN=#{Formula["epics-asyn"].opt_prefix}
  EOS

  # 2. Ensure configure/RELEASE includes RELEASE.local.
  #    Most EPICS modules already do; append the directive only when absent.
  release = buildpath/"configure/RELEASE"
  unless release.read.include?("RELEASE.local")
    release.open("a") { |f| f.puts "\n-include $(TOP)/configure/RELEASE.local" }
  end

  # 3. Build and install.
  #    INSTALL_LOCATION tells EPICS where to put the installed files.
  system "make", "INSTALL_LOCATION=#{prefix}"
end
```

See [configure-release.md](configure-release.md) for the per-module variable name
reference and complete examples for asyn, busy, motor, and others.

### Step 8 — Write the `test do` block

Assert that the module's shared library is present in the arch-specific output
directory:

```ruby
test do
  epics_arch = if OS.mac?
    Hardware::CPU.arm? ? "darwin-aarch64" : "darwin-x86_64"
  else
    Hardware::CPU.arm? ? "linux-aarch64" : "linux-x86_64"
  end
  assert_path_exists lib/epics_arch.to_s/shared_library("lib<name>")
end
```

Replace `"lib<name>"` with the library the module builds (e.g. `"libasyn"`, `"libbusy"`).
`shared_library` returns `"lib<name>.dylib"` on macOS and `"lib<name>.so"` on Linux.

> **Audit note**: use `assert_path_exists <path>` rather than
> `assert_predicate <path>, :exist?` — `brew audit --strict` flags the latter.
> Also use `epics_arch.to_s` when joining Pathname segments, not `"#{epics_arch}"`
> — audit flags string interpolation inside Pathname chains.

### Step 9 — Check style and run `brew audit --strict`

Before opening a PR, the following must pass for every changed formula:

```sh
brew style Formula/epics-<name>.rb
brew audit --strict --except=installed local/epics/epics-<name>
```

**Step 9a — Style check via MCP tool** (preferred): call `mcp_homebrew_style` with
`formula: "local/epics/epics-<name>"` (and optionally `fix: true` to auto-correct).
This runs RuboCop and is faster than the full audit.

**Step 9b — Full audit via CLI** (required — no MCP equivalent):

```sh
# --except=installed is required for all EPICS formulae: EPICS installs into
# bin/<arch>/ and lib/<arch>/ which fail the standard cellar post-install checks.
brew audit --strict --except=installed local/epics/epics-<name>
# For new formulae:
brew audit --strict --except=installed --new local/epics/epics-<name>
```

Fix every warning and error before declaring the formula ready. The most common
EPICS-specific failures are listed in [../../docs/HOMEBREW_PATTERNS.md](../../docs/HOMEBREW_PATTERNS.md)
section 5.

### Step 10 — Verify the build

Install via MCP tool (preferred): call `mcp_homebrew_install` with
`formula_or_cask: "local/epics/epics-<name>"`. Add `--build-bottle` if you need a
bottleable build — but note the MCP tool may not pass that flag; fall back to CLI:

```sh
brew install --build-bottle local/epics/epics-<name>
```

Then run the formula's `test do` block. There is no MCP equivalent for this — the
`mcp_homebrew_tests` tool runs Homebrew's own internal tests, not formula test blocks:

```sh
brew test local/epics/epics-<name>
```

---

## Required fields checklist

Before finishing a formula, confirm every item is present:

- [ ] `desc` — one sentence, no trailing period, ≤ 80 chars
- [ ] `homepage` — HTTPS URL for the module's documentation or GitHub page
- [ ] `url` — HTTPS GitHub archive URL using the exact tag from EPICS_VERSIONS.md
- [ ] `version` — dotted version string (e.g. `"4.44.2"`), placed immediately after `url` and before `sha256`; **required** when the tag uses dash-separated numbers (e.g. `R4-44-2`); omit when the URL already contains a dot-separated version (e.g. `base-7.0.10.tar.gz`)
- [ ] `sha256` — SHA256 of the source tarball
- [ ] `livecheck` block with `:github_latest` strategy and correct regex
- [ ] `bottle do` block with `root_url` and all six platform sha256 entries as valid 64-char hex (no `cellar` line)
- [ ] `keg_only :versioned_formula` (required for Base/support modules; omit for GUI app formulae)
- [ ] `depends_on` for all dependencies (correct `:build` qualifiers)
- [ ] `configure/RELEASE.local` written with all dependency paths (`opt_prefix`)
- [ ] `system "make", "INSTALL_LOCATION=#{prefix}"` in `install do`
- [ ] `test do` that asserts the expected shared library is present in `lib/<arch>/`
- [ ] `brew style Formula/epics-<name>.rb` passes
- [ ] `brew audit --strict` passes with no warnings or errors

---

## Common mistakes to avoid

| Mistake | Correct approach |
|---------|-----------------|
| Using `Formula["epics-base"].prefix` in RELEASE.local | Use `.opt_prefix` |
| Omitting the livecheck block | Always include it |
| Including `cellar :any` in the bottle block | Remove it — `cellar` was removed in Homebrew 4.x; audit errors with `undefined method 'cellar'` |
| sha256 placeholder is not valid hex (e.g. `"placeholder_until_ci_runs"`) | Use a 64-character hex string such as all-zeros |
| `test do` uses `assert_predicate <path>, :exist?` | Use `assert_path_exists <path>` |
| `test do` uses `"#{epics_arch}"` inside a Pathname chain | Use `epics_arch.to_s` |
| Placing `version` after `sha256` instead of before it | `version` must go immediately after `url` and before `sha256`; `brew bump-formula-pr` expects this order |
| Including a redundant `version` line when Homebrew can parse it from the URL | Omit `version` — audit flags it as redundant; only include it for dash-separated tags |
| Leaving `AUTOSAVE=`, `SSCAN=` etc. pointing at nonexistent paths | Comment them out |
| `depends_on "gcc"` | Remove — use Apple Clang |
| Hardcoding `/opt/homebrew` | Use `Formula[...].opt_prefix` or `opt_prefix` |
| Forgetting `revision` bump when epics-base changes | Always check dependent formulae |
| Running `brew audit Formula/<name>.rb` (path argument) | Path arguments are disabled; tap locally first: `brew tap local/epics /path/to/repo`, then `brew audit --strict local/epics/<name>` |
