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
- Set `desc`, `homepage`, `url`, `sha256`, `version`
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

Test the livecheck before finalising the formula:
```sh
brew livecheck Formula/epics-<name>.rb --verbose
```

### Step 4 — Write the bottle block

All formulae use GHCR and target six platforms:

```ruby
bottle do
  root_url "https://ghcr.io/v2/<org>/homebrew-epics"
  cellar :any          # use :any_skip_relocation only if truly no shared libs
  sha256 arm64_sequoia: "placeholder_until_ci_runs"
end
```

Real SHA256 hashes are filled in by `brew test-bot` during CI. Leave placeholders
in new formulae — CI will update them.

**Cellar annotation decision table**:

| Formula installs | Cellar annotation |
|-----------------|-------------------|
| `.dylib` / `.so` shared libraries | `cellar :any` |
| Only `.a` static libraries + headers | `cellar :any_skip_relocation` |
| Mixed (shared + static) | `cellar :any` |
| Scripts / pure Ruby | `cellar :any_skip_relocation` |

All EPICS support modules install shared libraries. Use `cellar :any` unless you
have verified with `otool -L` (macOS) or `ldd` (Linux) that no `.dylib`/`.so` files
are installed.

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
depends_on "epics-base"               # runtime dependency (default)
depends_on "epics-asyn"               # runtime dependency
depends_on "re2c" => :build           # build-only tool (not needed at runtime)
depends_on "cmake" => :build          # build-only tool
```

Rules:
- EPICS module dependencies (epics-base, epics-asyn, etc.) are almost always both
  build-time and run-time. Do **not** mark them `:build`.
- Tools like `cmake`, `re2c`, `python` used only during `install do` get `=> :build`.
- Do not add `depends_on "gcc"` — Apple Clang is the compiler on macOS.

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
  assert_predicate lib/"#{epics_arch}"/shared_library("lib<name>"), :exist?
end
```

Replace `"lib<name>"` with the library the module builds (e.g. `"libasyn"`, `"libbusy"`).
`shared_library` returns `"lib<name>.dylib"` on macOS and `"lib<name>.so"` on Linux.

### Step 9 — Run `brew audit --strict` and fix all issues

```sh
brew audit --strict Formula/epics-<name>.rb
# For new formulae:
brew audit --strict --new Formula/epics-<name>.rb
```

Fix every warning and error before declaring the formula ready. The most common
EPICS-specific failures are listed in [../../docs/HOMEBREW_PATTERNS.md](../../docs/HOMEBREW_PATTERNS.md)
section 5.

### Step 10 — Verify the build

```sh
brew install --build-bottle Formula/epics-<name>.rb
brew test Formula/epics-<name>.rb
```

---

## Required fields checklist

Before finishing a formula, confirm every item is present:

- [ ] `desc` — one sentence, no trailing period, ≤ 80 chars
- [ ] `homepage` — HTTPS URL for the module's documentation or GitHub page
- [ ] `url` — HTTPS GitHub archive URL using the exact tag from EPICS_VERSIONS.md
- [ ] `sha256` — SHA256 of the source tarball
- [ ] `version` — dotted version string (e.g. `"4.44.2"`)
- [ ] `livecheck` block with `:github_latest` strategy and correct regex
- [ ] `bottle do` block with `root_url`, `cellar`, and all six platform sha256 entries
- [ ] `keg_only :versioned_formula` (required for Base/support modules; omit for GUI app formulae)
- [ ] `depends_on` for all dependencies (correct `:build` qualifiers)
- [ ] `configure/RELEASE.local` written with all dependency paths (`opt_prefix`)
- [ ] `system "make", "INSTALL_LOCATION=#{prefix}"` in `install do`
- [ ] `test do` that asserts the expected shared library is present in `lib/<arch>/`
- [ ] `brew audit --strict` passes with no warnings or errors

---

## Common mistakes to avoid

| Mistake | Correct approach |
|---------|-----------------|
| Using `Formula["epics-base"].prefix` in RELEASE.local | Use `.opt_prefix` |
| Omitting the livecheck block | Always include it |
| `cellar :any_skip_relocation` on a formula with `.dylib` files | Use `cellar :any` |
| `test do` only checks `--version` or omits library assertion | Use `assert_predicate lib/arch/shared_library("lib<name>")` |
| Leaving `AUTOSAVE=`, `SSCAN=` etc. pointing at nonexistent paths | Comment them out |
| `depends_on "gcc"` | Remove — use Apple Clang |
| Hardcoding `/opt/homebrew` | Use `Formula[...].opt_prefix` or `opt_prefix` |
| Forgetting `revision` bump when epics-base changes | Always check dependent formulae |
