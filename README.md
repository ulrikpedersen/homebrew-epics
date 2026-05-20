# EPICS Homebrew Tap 🍺

This is a [Homebrew tap](https://docs.brew.sh/Taps) providing formulae and pre-built bottles for
[EPICS Base](https://epics-controls.org/) and a set of commonly used EPICS support modules, for macOS (Apple Silicon).

## Tap and install

```sh
# Add the tap
brew tap <org>/epics

# Install EPICS Base
brew install epics-base

# Install support modules
brew install epics-asyn
brew install epics-autosave
brew install epics-busy
brew install epics-calc
brew install epics-seq
brew install epics-sscan
brew install epics-std
brew install epics-streamdevice
brew install epics-motor
```

## About `keg_only`

EPICS Base and support module formulae in this tap are **`keg_only`**. Homebrew will
not create symlinks in `/opt/homebrew/bin`, `/opt/homebrew/lib`, etc. This is
intentional: it prevents conflicts between EPICS versions and between EPICS and other
system libraries.

Standalone GUI application formulae (such as Phoebus, EDM, or MEDM) are **not**
`keg_only` — they are apps rather than libraries, and users typically install only one
version at a time.

### What this means in practice

Your IOC application's `configure/RELEASE` file is where you configure support module dependency paths. Point it at the `opt_prefix` which Homebrew maintains for each package:

```
# configure/RELEASE in your IOC
EPICS_BASE=/opt/homebrew/opt/epics-base
ASYN=/opt/homebrew/opt/epics-asyn
MOTOR=/opt/homebrew/opt/epics-motor
# ... etc.
```

On Intel Macs, replace `/opt/homebrew` with `/usr/local`. On Linux with Linuxbrew,
use `/home/linuxbrew/.linuxbrew`. The portable way to find the prefix for any formula
is `brew --prefix <formula>`:

```sh
brew --prefix epics-base
# /opt/homebrew/opt/epics-base
```

## Pre-built bottles

Binary bottles are available from the GitHub Container Registry (GHCR) and will be
downloaded automatically by `brew install`. Supported platforms:

| Bottle tag | Platform |
|------------|---------|
| `arm64_sequoia` | macOS 15 Sequoia, Apple Silicon |

If no bottle matches your platform, `brew install` will fall back to building from
source. Apple Clang is the required compiler; GCC is not supported.

## Licence

The Homebrew formulae in this tap are released under the Apache License 2.0.
EPICS Base and the support modules are separately licenced by their respective
upstream projects; see each module's repository for details.
