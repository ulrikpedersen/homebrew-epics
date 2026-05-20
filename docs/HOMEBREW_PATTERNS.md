# EPICS-Specific Homebrew Patterns

This document records patterns, idioms, and gotchas specific to packaging EPICS modules
as Homebrew formulae. Read this alongside the general Homebrew formula authoring guide.

---

## 1. The `configure/RELEASE.local` pattern

Every EPICS support module ships a `configure/RELEASE` file containing placeholder
dependency paths. The preferred Homebrew approach is to **write a
`configure/RELEASE.local` file** with the correct `opt_prefix` paths rather than
patching `configure/RELEASE` directly.

Most EPICS modules end their `configure/RELEASE` with:

```makefile
-include $(TOP)/configure/RELEASE.local
```

Variables in `RELEASE.local` override the defaults because the file is included last.
For modules that do not include `RELEASE.local`, the formula appends the include
directive before invoking `make`.

### Basic structure

```ruby
def install
  # Write configure/RELEASE.local with Homebrew-specific dependency paths.
  # This leaves configure/RELEASE untouched.
  (buildpath/"configure/RELEASE.local").write <<~EOS
    EPICS_BASE=#{Formula["epics-base"].opt_prefix}
    ASYN=#{Formula["epics-asyn"].opt_prefix}
  EOS

  # Append the include directive if the module's configure/RELEASE lacks it.
  release = buildpath/"configure/RELEASE"
  unless release.read.include?("RELEASE.local")
    release.open("a") { |f| f.puts "\n-include $(TOP)/configure/RELEASE.local" }
  end

  system "make", "INSTALL_LOCATION=#{prefix}"
end
```

### Key rules

1. **Use `opt_prefix`, never `prefix`** for formulae other than the one being built.
   `opt_prefix` resolves to the stable `/opt/homebrew/opt/<formula>` symlink;
   `prefix` resolves to the versioned Cellar path and becomes stale after upgrades.

2. **Read `configure/RELEASE` first** — run `cat configure/RELEASE` in a
   `brew install --interactive` session to identify which variables the module uses
   and whether `RELEASE.local` is already included.

3. **Define each module path directly** — do not set `SUPPORT`. Even if
   `configure/RELEASE` derives paths from `SUPPORT=$(SUPPORT)/asyn-...`, a direct
   `ASYN=<opt_prefix>` in `RELEASE.local` overrides it.

4. **Use the canonical variable names** — `STREAM` is always used for StreamDevice
   in this tap. If the upstream `configure/RELEASE` defines `STREAMDEVICE` instead,
   comment that line out with `inreplace` before building (see
   [configure-release.md](configure-release.md) for the pattern). For all other
   modules, check the variable name table in that file.

---

## 2. The `revision` field: when and how

Homebrew tracks formula builds with a `revision` counter. When the version number
stays the same but the binary must be rebuilt, increment `revision`.

### When to use `revision`

| Trigger | Action |
|---------|--------|
| `epics-base` version bump | Increment `revision` in all dependent formulae |
| Formula bug fix (same source tarball) | Increment `revision` |
| New bottle platform added | Increment `revision` |
| Compiler or build flags change that affects the ABI | Increment `revision` |
| New upstream release | Reset `revision` to 0 (remove the line) and bump `version` |

### Syntax

```ruby
class EpicsAsyn < Formula
  desc "..."
  homepage "..."
  url "..."
  sha256 "..."
  version "4.44.2"
  revision 2      # ← increment this; remove when version bumps

  bottle do
    # ...
  end
```

### Cascading revision bumps

When `epics-base` is updated, **every formula that depends on it** must have its
`revision` incremented, even indirect dependents. The dependency chain means:

```
epics-base bumped
  → epics-asyn revision++
  → epics-busy revision++ (depends on asyn, which was rebuilt)
  → epics-motor revision++ (depends on asyn and busy)
  ... etc.
```

The `bump-dependents.yml` workflow handles this automatically by opening separate PRs
for each dependent. Merge them in topological order (most fundamental first).

---

## 3. Bottle rebuild workflow when `epics-base` updates

The full sequence when a new `epics-base` version lands:

1. **PR opened** by `autobump.yml` for `epics-base` version bump.
2. **CI builds bottles** for all platforms via `tests.yml` (uses `brew test-bot`).
3. **PR merged** — the `bump-dependents.yml` workflow triggers on merge.
4. `bump-dependents.yml` opens revision-bump PRs for each dependent formula in
   dependency order (asyn first, then busy/calc/seq/sscan, then motor).
5. Each dependent PR triggers `tests.yml` which rebuilds and uploads its bottles.
6. Merge dependent PRs in dependency order.

### Triggering a manual rebuild

If a bottle rebuild is needed for a formula without a version change (e.g., a new
platform was added to the bottle block):

```sh
# Increment revision locally
brew bump-revision Formula/epics-asyn.rb

# Or edit manually: add/increment the revision line
# Then open a PR — CI will build new bottles
```

---

## 4. `brew livecheck` and autobump integration

The `livecheck` block in each formula tells `brew livecheck` (and the `autobump.yml`
workflow) how to detect new upstream versions.

### How livecheck works for EPICS modules

```ruby
livecheck do
  url :stable           # use the stable URL's GitHub repo
  strategy :github_latest  # check the "Latest" release tag on GitHub
  regex(/^R(\d+(?:-\d+)+)$/i)  # capture the numeric part of the tag
end
```

The `:github_latest` strategy calls the GitHub API for the latest release tag.
It applies the regex and returns the captured group as the version string.
Homebrew then compares `7-0-10` (captured) with `7.0.10` (formula version) using
its version normalisation logic, which treats `.` and `-` as equivalent separators.

### Checking livecheck locally

```sh
brew livecheck --tap <org>/epics
brew livecheck Formula/epics-base.rb --verbose
```

### autobump integration

The `autobump.yml` workflow runs `brew livecheck` on a schedule and uses
`dawidd6/action-homebrew-bump-formula` to open PRs when a new version is found.
This requires a GitHub token with `workflow` scope stored as the `HOMEBREW_GITHUB_API_TOKEN`
secret. The formula's `livecheck` block must be correct for this to work — a wrong
regex will result in false positives or missed updates.

---

## 5. `brew audit --strict` checklist

Before declaring any formula done, run:

```sh
brew audit --strict Formula/epics-<name>.rb
```

Common audit failures in EPICS formulae and how to fix them:

| Audit error | Fix |
|-------------|-----|
| `Livecheck block is missing` | Add a `livecheck do ... end` block |
| `"keg_only" reason is not `:versioned_formula`` | Change reason to `:versioned_formula` |
| `Bottle block is missing` | Add a `bottle do ... end` block |
| `cellar: :any_skip_relocation` on a dylib | Change to `cellar: :any` |
| `Depends on formula in same tap without tap name` | Use `depends_on "epics-asyn"` (no tap prefix needed within the tap) |
| `test block does not compile or run code` | Replace `--version` check with a compiled C test |
| `URL not using HTTPS` | Fix the `url` and `homepage` to use `https://` |
| `Formula class name does not match filename` | Rename class to match: `epics-asyn.rb` → `class EpicsAsyn` |
| `Hardcoded path in formula` | Replace with `opt_prefix` or `Formula[...].opt_prefix` |

The `--new` flag adds extra checks for new formulae (unique description, etc.):

```sh
brew audit --strict --new Formula/epics-asyn.rb
```

---

## 6. Shared library annotations: `cellar: :any` vs `:any_skip_relocation`

Homebrew bottle annotations control whether a bottle can be relocated to a different
Cellar path without modification.

- **`cellar: :any`**: The bottle contains absolute paths to shared libraries that
  `brew bottle` has rewritten to use `@rpath` or `@loader_path`. The bottle works
  anywhere Homebrew is installed, but the `.dylib` files must stay in the Cellar.
  Use this for all formulae that install `.dylib` files.

- **`cellar: :any_skip_relocation`**: The bottle contains no absolute Cellar paths.
  It can be unzipped anywhere and will work. Use this only for formulae that install
  only static libraries, headers, or scripts with no compiled binaries.

All EPICS formulae that build shared libraries (virtually all of them) must use
`cellar: :any`. If a formula genuinely only installs headers and static `.a` files,
use `cellar: :any_skip_relocation`, but verify with `otool -L` (macOS) or `ldd` (Linux).

---

## 7. Architecture-specific EPICS paths

EPICS installs binaries and libraries under arch-specific subdirectories:

| Platform | EPICS arch string | Path |
|----------|-------------------|------|
| macOS, Apple Silicon | `darwin-aarch64` | `lib/darwin-aarch64/`, `bin/darwin-aarch64/` |
| macOS, Intel | `darwin-x86_64` | `lib/darwin-x86_64/`, `bin/darwin-x86_64/` |
| Linux, ARM64 | `linux-aarch64` | `lib/linux-aarch64/`, `bin/linux-aarch64/` |
| Linux, x86_64 | `linux-x86_64` | `lib/linux-x86_64/`, `bin/linux-x86_64/` |

In formulae, use `EPICS.host_arch` (a helper you may need to define) or construct
the path at install time:

```ruby
# Determine EPICS host arch from the build environment
epics_arch = if OS.mac?
  Hardware::CPU.arm? ? "darwin-aarch64" : "darwin-x86_64"
else
  Hardware::CPU.arm? ? "linux-aarch64" : "linux-x86_64"
end

# Use in test do to find binaries
bin_dir = opt_prefix/"bin"/epics_arch
```

For `test do` blocks, use the same logic to locate installed binaries when compiling
test programs.
