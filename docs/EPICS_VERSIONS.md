# EPICS Package Versions — Canonical Reference

This file is the single source of truth for target versions, upstream URLs, and tag
formats for all formulae in this tap. When writing or updating a formula, take the
version and URL from this table, not from memory.

Update this file whenever a formula version is bumped.

---

## Package table

| Formula | Version | Upstream GitHub URL |
|---------|---------|---------------------|
| `epics-base` | 7.0.10 (`R7.0.10`) | https://github.com/epics-base/epics-base |
| `epics-asyn` | 4.44.2 (`R4-44-2`) | https://github.com/epics-modules/asyn |
| `epics-autosave` | 6.0 (`R6-0`) | https://github.com/epics-modules/autosave |
| `epics-busy` | 1.7.4 (`R1-7-4`) | https://github.com/epics-modules/busy |
| `epics-calc` | 3.7.5 (`R3-7-5`) | https://github.com/epics-modules/calc |
| `epics-seq` | 2.2.9 (`R2-2-9`) | https://github.com/epics-modules/sequencer |
| `epics-sscan` | 2.12 (`R2-12`) | https://github.com/epics-modules/sscan |
| `epics-std` | 3.6.2 (`R3-6-2`) | https://github.com/epics-modules/std |
| `epics-streamdevice` | 2.8.24 (`2.8.24`) | https://github.com/paulscherrerinstitute/StreamDevice |
| `epics-motor` | 7.3.1 (`R7-3-1`) | https://github.com/epics-modules/motor |

---

## Module dependency graph

```
epics-base 7.0.10 (R7.0.10)
│
├── epics-asyn 4.44.2 (R4-44-2)
│   ├── epics-busy 1.7.4 (R1-7-4)              [also: epics-base]
│   └── epics-streamdevice 2.8.24 (2.8.24)     [also: epics-base]
│
├── epics-autosave 6.0 (R6-0)                  [only: epics-base]
│
├── epics-calc 3.7.5 (R3-7-5)                  [only: epics-base]
│
├── epics-seq 2.2.9 (R2-2-9)                  [only: epics-base]
│
├── epics-sscan 2.12 (R2-12)                   [also: epics-seq]
│
├── epics-std 3.6.2 (R3-6-2)                   [also: epics-asyn, epics-calc, epics-sscan]
│
└── epics-motor 7.3.1 (R7-3-1)                 [also: epics-asyn, epics-busy, epics-calc, epics-sscan]
```

### Notes on graph interpretation

- All edges shown are build-time AND run-time dependencies unless noted.
- `epics-calc` can optionally use `sscan`/`sncseq` helpers; in Homebrew it is built
  standalone by setting `SSCAN=` empty in `configure/RELEASE.local`.

---

## Per-package details

### `epics-base`

- **Formula class**: `EpicsBase`
- **GitHub**: https://github.com/epics-base/epics-base
- **Homepage**: https://epics-controls.org/
- **Description**: Core libraries and build system for EPICS control systems
- **Tag format**: `R<major>.<minor>.<patch>` using dots (e.g. `R7.0.10`) — note: dots, not dashes
- **Livecheck regex**: `/^R(\d+(?:\.\d+)+)$/i`
- **Dependencies (build)**: none beyond Xcode Command Line Tools
- **Dependencies (runtime)**: none
- **Installs**: headers, shared libs (libca, libCom, libpvData, libpvAccess, etc.),
  EPICS build system makefiles, `bin/darwin-aarch64/` tools
- **Build quirks**:
  - **Use the release asset URL, not the GitHub archive URL.** The GitHub-generated
    archive tarballs omit the PVA submodules entirely and must not be used. The correct
    URL pattern is: `https://github.com/epics-base/epics-base/releases/download/<tag>/base-<version>.tar.gz`
  - The build system requires GNU Make ≥ 3.82 (macOS ships ≥ 3.81; use `brew install make` if needed)
  - Set `INSTALL_LOCATION=$(prefix)` on the make command line; do not rely on `configure/RELEASE`
  - EPICS host arch is auto-detected; `EPICS_HOST_ARCH=darwin-aarch64` on Apple Silicon
  - Headers are installed under `include/` with a subdirectory per OS: `include/os/Darwin/`

---

### `epics-asyn`

- **Formula class**: `EpicsAsyn`
- **GitHub**: https://github.com/epics-modules/asyn
- **Homepage**: https://epics-modules.github.io/asyn/
- **Description**: EPICS module for interfacing to synchronous and asynchronous devices
- **Tag format**: `R<major>-<minor>-<patch>` (e.g. `R4-44-2`)
- **Livecheck regex**: `/^R(\d+(?:-\d+)+)$/i`
- **Dependencies (build)**: `epics-base`
- **Dependencies (runtime)**: `epics-base`
- **Installs**: shared libs (libasyn), headers, `.dbd` database files
- **Build quirks**:
  - Requires patching `configure/RELEASE` to set `EPICS_BASE`
  - Optional RCSID support (VxWorks only); disable with `RCSID=NO` in configure

---

### `epics-autosave`

- **Formula class**: `EpicsAutosave`
- **GitHub**: https://github.com/epics-modules/autosave
- **Homepage**: https://epics-modules.github.io/autosave/
- **Description**: EPICS support module for automatically saving and restoring PV values
- **Tag format**: `R<major>-<minor>` (two components only, e.g. `R6-0`)
- **Archive URL**: `https://github.com/epics-modules/autosave/archive/refs/tags/R6-0.tar.gz`
- **Livecheck regex**: `/^R(\d+(?:-\d+)+)$/i`
- **Dependencies (build)**: `epics-base`
- **Dependencies (runtime)**: `epics-base`
- **Installs**: shared lib (libautosave), headers, `.dbd` files
- **Build quirks**: The two-component version `6.0` is correct; do not invent a `.0`
  patch component. The R6-0 release includes breaking changes to `set_savefile_path`
  NFS handling — the third argument (mountpoint) must be specified before calling
  `save_restoreSet_NFSHost` if NFS is used.

---

### `epics-busy`

- **Formula class**: `EpicsBusy`
- **GitHub**: https://github.com/epics-modules/busy
- **Homepage**: https://epics-modules.github.io/busy/
- **Description**: EPICS busy record support
- **Tag format**: `R<major>-<minor>-<patch>`
- **Livecheck regex**: `/^R(\d+(?:-\d+)+)$/i`
- **Dependencies (build)**: `epics-base`, `epics-asyn`
- **Dependencies (runtime)**: `epics-base`, `epics-asyn`
- **Installs**: shared lib (libbusy), headers, `.dbd` files
- **Build quirks**:
  - Patch `configure/RELEASE` for both `EPICS_BASE` and `ASYN`
  - The `ASYN` variable in `configure/RELEASE` must point to the asyn installation root

---

### `epics-calc`

- **Formula class**: `EpicsCalc`
- **GitHub**: https://github.com/epics-modules/calc
- **Homepage**: https://epics-modules.github.io/calc/
- **Description**: EPICS calculation records (calc, calcout, sCalc, etc.)
- **Tag format**: `R<major>-<minor>-<patch>`
- **Livecheck regex**: `/^R(\d+(?:-\d+)+)$/i`
- **Dependencies (build)**: `epics-base`
- **Dependencies (runtime)**: `epics-base`
- **Notes**: Build standalone by setting `SSCAN=` empty in `configure/RELEASE.local`.
- **Installs**: shared lib (libcalc), headers, `.dbd` files

---

### `epics-seq`

- **Formula class**: `EpicsSeq`
- **GitHub**: https://github.com/epics-modules/sequencer
- **Homepage**: https://epics-modules.github.io/sequencer/
- **Description**: EPICS State Notation Language (SNL) sequencer
- **Tag format**: `R<major>-<minor>-<patch>` (e.g. `R2-2-9`)
- **Livecheck regex**: `/^R(\d+(?:-\d+)+)$/i`
- **Dependencies (build)**: `epics-base`
- **Dependencies (runtime)**: `epics-base`
- **Installs**: `snc` compiler binary, shared libs (libseq, libpv), headers
- **Build quirks**:
  - The SNC (State Notation Compiler) binary is installed in `bin/<arch>/snc`
  - Uses `re2c` as a build-time tokeniser generator; add `depends_on "re2c" => :build`

---

### `epics-sscan`

- **Formula class**: `EpicsSscan`
- **GitHub**: https://github.com/epics-modules/sscan
- **Homepage**: https://epics-modules.github.io/sscan/
- **Description**: EPICS sscan record and associated software
- **Tag format**: `R<major>-<minor>` (e.g. `R2-12`)
- **Livecheck regex**: `/^R(\d+(?:-\d+)+)$/i`
- **Dependencies (build)**: `epics-base`, `epics-seq`
- **Dependencies (runtime)**: `epics-base`, `epics-seq`
- **Installs**: shared lib (libsscan), headers, `.dbd` files
- **Build quirks**:
  - Set `SNCSEQ` in `configure/RELEASE.local` to `epics-seq`'s `opt_prefix`

---

### `epics-std`

- **Formula class**: `EpicsStd`
- **GitHub**: https://github.com/epics-modules/std
- **Homepage**: https://epics-modules.github.io/std/
- **Description**: EPICS standard records and support
- **Tag format**: `R<major>-<minor>-<patch>`
- **Livecheck regex**: `/^R(\d+(?:-\d+)+)$/i`
- **Dependencies (build)**: `epics-base`, `epics-asyn`, `epics-calc`, `epics-sscan`
- **Dependencies (runtime)**: `epics-base`, `epics-asyn`, `epics-calc`, `epics-sscan`
- **Installs**: shared lib (libstd), headers, `.dbd` files

---

### `epics-streamdevice`

- **Formula class**: `EpicsStreamdevice`
- **GitHub**: https://github.com/paulscherrerinstitute/StreamDevice
- **Homepage**: https://paulscherrerinstitute.github.io/StreamDevice/
- **Description**: EPICS stream device support for serial and network devices
- **Tag format**: Plain semver `2.8.24` (no `R` prefix, no dashes)
- **Livecheck regex**: `/^v?(\d+(?:\.\d+)+)$/i`
- **Dependencies (build)**: `epics-base`, `epics-asyn`
- **Dependencies (runtime)**: `epics-base`, `epics-asyn`
- **Installs**: shared lib (libstream), headers, `.dbd` files
- **Build quirks**:
  - StreamDevice uses a non-standard `GNUmakefile` build; set `STREAM_PROTOCOL_PATH`
    if protocol files are needed at runtime
  - Tag format differs from EPICS convention — use a distinct livecheck regex

---

### `epics-motor`

- **Formula class**: `EpicsMotor`
- **GitHub**: https://github.com/epics-modules/motor
- **Homepage**: https://epics-modules.github.io/motor/
- **Description**: EPICS motor record support
- **Tag format**: `R<major>-<minor>-<patch>`
- **Livecheck regex**: `/^R(\d+(?:-\d+)+)$/i`
- **Dependencies (build)**: `epics-base`, `epics-asyn`, `epics-busy`, `epics-calc`, `epics-sscan`
- **Dependencies (runtime)**: `epics-base`, `epics-asyn`, `epics-busy`, `epics-calc`, `epics-sscan`
- **Installs**: shared lib (libmotor), headers, `.dbd` files
- **Build quirks**:
  - Patch `configure/RELEASE` for all five dependencies
  - Motor's `configure/RELEASE` uses `MOTOR` as a self-referential variable; do not
    accidentally overwrite it

