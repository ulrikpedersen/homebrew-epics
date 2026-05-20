# Project Context — homebrew-epics

## What is EPICS?

EPICS (Experimental Physics and Industrial Control System) is a set of open-source
software tools, libraries, and applications used to build distributed control systems
for scientific equipment such as particle accelerators, telescopes, and X-ray beam
lines. It was jointly developed by Argonne National Laboratory and Los Alamos National
Laboratory and is now maintained by the EPICS collaboration worldwide.

The core runtime library is **EPICS Base**, which provides:
- The Channel Access (CA) and PVAccess (PVA) network protocols for real-time data
  exchange between process variables (PVs)
- A portable OS abstraction layer (OSI) that targets macOS, Linux, Windows, and VxWorks
- The IOC (Input/Output Controller) application framework
- A build system based on GNU Make with per-platform `configure/os/` files

Around Base sits an ecosystem of **support modules** — self-contained libraries that
add device driver support, sequencing, scanning, archiving, and other functionality.
Each module ships its own `configure/RELEASE` file that records the absolute paths to
EPICS Base and any other modules it depends on.

## What this tap is for

This Homebrew tap packages EPICS Base and the most commonly used support modules so
that macOS developers and CI pipelines can install them with a single `brew install`
command and receive pre-built binaries rather than spending 10–20 minutes compiling.

Target users are scientists and engineers developing EPICS IOC applications on macOS laptops. Production control systems at facilities are out of scope.

## Why `keg_only` for Base and support modules?

EPICS modules embed their own installation directory into compiled `configure/RELEASE`
files and occasionally `.dbd` database files. If two
different versions of `epics-base` were both symlinked into `/opt/homebrew`, the
paths would collide. `keg_only :versioned_formula` keeps each version isolated in
`/opt/homebrew/Cellar/<formula>/<version>/` and exposes a stable
`/opt/homebrew/opt/<formula>` symlink that points to whichever version is currently
active. IOC `configure/RELEASE` files should point at the `opt/` symlink path.

This rationale does **not** apply to standalone GUI applications (Phoebus, EDM, MEDM,
etc.). Those formulae install apps rather than linkable libraries, are not referenced
by other formulae's `configure/RELEASE` files, and typically have only one version
installed at a time. They should be authored as normal (non-keg-only) formulae.

## Why GHCR for bottle storage?

GitHub Container Registry (GHCR) allows bottle storage in the same organisation that
hosts the tap's source code without requiring a separate S3 bucket or Bintray account.
GHCR supports anonymous pull for public repositories, so users do not need to
authenticate to download bottles. Homebrew's bottle mechanism fetches from the
`root_url` in the formula's `bottle do` block; GHCR is directly supported.

Bottle images are stored at:
```
ghcr.io/<org>/homebrew-epics/<formula-name>:<version>
```

For module dependency information, see [EPICS_VERSIONS.md](EPICS_VERSIONS.md).

## Compiler decision: Apple Clang only

EPICS Base 7.x ships `configure/os/CONFIG.darwin` files that already target Apple
Clang. The darwin configuration sets `-std=c++17` and uses `clang++` as the C++
compiler. Switching to GCC on macOS would require patching these files and introduces
ABI incompatibilities between Clang- and GCC-built `.dylib` files.

Decision: **do not add `depends_on "gcc"`** to any formula in this tap. If upstream
adds GCC-specific code that breaks Apple Clang, report it to the upstream module.

## Known gotchas and technical notes

### RPATH / dylib path baking

EPICS Build System links shared libraries with absolute paths baked into the
`LC_RPATH` and `LC_ID_DYLIB` fields of the Mach-O binary (on macOS) or the `RPATH`
ELF section (on Linux). When building a bottle, `brew bottle` rewrites these paths so
they use `@rpath` or `@loader_path` relative references, enabling relocation. However,
three places still record absolute Cellar paths that `brew bottle` does **not** fix:

1. `configure/RELEASE` files installed into `share/` — must use `opt_prefix` in the
   formula so the installed file already contains the stable `opt/` path.
2. `.dbd` database files that embed `dbLoadRecords` paths — rare, but check if the
   module's Makefile installs any.

See [.github/skills/brew-formula/rpath-notes.md](.github/skills/brew-formula/rpath-notes.md)
for diagnostic commands and fixes.

### EPICS tag regex

Upstream EPICS modules use two tag conventions:
- EPICS-style: `R7-0-10`, `R4-44-2`, `R1-7-4` — prefix `R`, dashes as separators
- Plain semver: `2.8.24` (StreamDevice), `2.2.9` (seq) — no prefix

The livecheck regex must match the actual tag format used by each module's GitHub
releases. Check the "Latest" release tag on GitHub before writing the regex.

Some modules (e.g., autosave) have only two numeric components: `R5-11`. The regex
`/^R(\d+(?:[.-]\d+)+)$/i` handles both two- and three-component versions.

### `configure/RELEASE` dependency injection

EPICS modules ship a `configure/RELEASE` file containing placeholder dependency paths.
The preferred approach in Homebrew formulae is to write a `configure/RELEASE.local`
file alongside it, defining `EPICS_BASE` and any module paths using `opt_prefix`.
Most EPICS modules already include `RELEASE.local` at the end of their
`configure/RELEASE`; for those that don't, the formula appends the include directive
before invoking `make`. See
[.github/skills/brew-formula/configure-release.md](.github/skills/brew-formula/configure-release.md).

