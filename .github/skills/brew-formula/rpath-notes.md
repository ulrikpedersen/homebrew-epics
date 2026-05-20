# RPATH and Shared Library Handling for EPICS Formulae

This document explains the EPICS shared library path problem, how Homebrew's bottle
mechanism handles it, what it does **not** handle automatically, and how to verify
that an installed formula is correctly relocatable.

---

## The EPICS RPATH problem

When the EPICS build system compiles a shared library (e.g. `libasyn.dylib`), it
links it with absolute paths to its own dependencies baked directly into the binary.
On macOS this means:

- The library's `LC_ID_DYLIB` field contains the full Cellar path:
  `/opt/homebrew/Cellar/epics-asyn/4.44.2/lib/darwin-aarch64/libasyn.dylib`
- The `LC_RPATH` entries (used to find dependencies at load time) point at other
  Cellar paths like `/opt/homebrew/Cellar/epics-base/7.0.10/lib/darwin-aarch64/`

On Linux, the equivalent is the `RPATH` ELF section baked into `.so` files.

These Cellar paths become stale the moment a formula is upgraded (the Cellar path
includes the version number). Any binary that loads a stale path fails at runtime.

---

## What `brew bottle` does automatically

When `brew test-bot` builds a bottle, it runs `brew bottle <formula>` which performs
Mach-O (macOS) or ELF (Linux) rewriting:

### macOS

`brew bottle` calls `install_name_tool` to:
1. Change `LC_ID_DYLIB` from the absolute Cellar path to an `@rpath`-relative path:
   - Before: `/opt/homebrew/Cellar/epics-asyn/4.44.2/lib/darwin-aarch64/libasyn.dylib`
   - After: `libasyn.dylib` (referenced via `@rpath`)
2. Rewrite `LC_LOAD_DYLIB` entries (dynamic library loads) from absolute Cellar paths
   to `@rpath`-relative paths.
3. Set `LC_RPATH` entries to `@loader_path/../../..` style relative paths that resolve
   correctly after Homebrew installs the bottle into the Cellar.

### Linux

`brew bottle` uses `patchelf` to rewrite `RPATH` from absolute Linuxbrew paths to
`$ORIGIN`-relative paths.

**Result**: after bottling, the shared libraries in the `.tar.gz` bottle archive
use relative paths and will resolve correctly regardless of where Homebrew is installed
(`/opt/homebrew`, `/usr/local`, or `/home/linuxbrew/.linuxbrew`).

---

## What `brew bottle` does NOT fix

Three categories of files still contain absolute Cellar paths after bottling and
must be handled by the formula itself:

### 1. Installed `configure/RELEASE` files

If your `install do` method copies `configure/RELEASE` to the formula prefix (many
EPICS modules do this so that other modules can use them as a dependency), and you
used `Formula["epics-base"].prefix` instead of `opt_prefix`, the installed
`configure/RELEASE` will contain:
```
EPICS_BASE=/opt/homebrew/Cellar/epics-base/7.0.10
```
This path becomes invalid after any upgrade of epics-base.

**Fix**: always use `opt_prefix` in `inreplace` before building. The installed
`configure/RELEASE` will then contain the stable `opt/` symlink path:
```
EPICS_BASE=/opt/homebrew/opt/epics-base
```

### 2. Embedded paths in `.dbd` database files

Very occasionally, EPICS `.dbd` files include `dbLoadRecords` calls with embedded
paths. This is unusual for library formulae (it is more common in IOC applications)
but worth checking if the module's Makefile installs any `.dbd` files with path content.

---

## Verifying correct RPATH after install

### macOS — `otool -L`

```sh
# Inspect the dynamic library dependencies of an installed EPICS library
otool -L $(brew --prefix epics-asyn)/lib/darwin-aarch64/libasyn.dylib
```

**Good output** — all paths use `@rpath` or `@loader_path`:
```
/opt/homebrew/opt/epics-asyn/lib/darwin-aarch64/libasyn.dylib:
        @rpath/libasyn.dylib (compatibility version 0.0.0, current version 0.0.0)
        @rpath/libca.dylib (compatibility version 0.0.0, current version 0.0.0)
        @rpath/libCom.dylib (compatibility version 0.0.0, current version 0.0.0)
        /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version ...)
```

**Bad output** — absolute Cellar paths remain:
```
/opt/homebrew/opt/epics-asyn/lib/darwin-aarch64/libasyn.dylib:
        /opt/homebrew/Cellar/epics-asyn/4.44.2/lib/darwin-aarch64/libasyn.dylib
        /opt/homebrew/Cellar/epics-base/7.0.10/lib/darwin-aarch64/libca.dylib
```
If you see Cellar paths, the bottle was not correctly processed by `brew bottle`.
This usually means the formula was installed without `--build-bottle`, so `brew bottle`
did not run. Re-build with `brew install --build-bottle` and then run `brew bottle`.

### macOS — `otool -l` for RPATH entries

```sh
otool -l $(brew --prefix epics-asyn)/lib/darwin-aarch64/libasyn.dylib | grep -A 3 LC_RPATH
```

### Linux — `objdump -p` or `readelf -d`

```sh
objdump -p $(brew --prefix epics-asyn)/lib/linux-x86_64/libasyn.so | grep RPATH
# or
readelf -d $(brew --prefix epics-asyn)/lib/linux-x86_64/libasyn.so | grep -i rpath
```

**Good output** — uses `$ORIGIN`:
```
0x000000000000001d (RPATH)  Library rpath: [$ORIGIN/../../lib/linux-x86_64]
```

---

## The `cellar: :any` annotation explained

When a formula bottle is annotated with `cellar: :any`, Homebrew knows that the
binary files in the bottle reference other shared libraries in the Cellar. Homebrew
will:
- Ensure the bottle is unpacked into the correct Cellar location
- Maintain the `opt/` symlinks so that `@rpath` entries resolve correctly

When a formula bottle is annotated with `cellar: :any_skip_relocation`, Homebrew
treats the bottle as fully relocatable — it can be moved anywhere and will work.
This is only correct for formulae with no shared library files (static libs only,
or pure scripts).

Using `cellar: :any_skip_relocation` on a formula that installs `.dylib` files is
an audit error and will cause `brew audit --strict` to fail. Always verify with
`otool -L` before choosing the annotation.

---

## Quick reference

```sh
# Check dynamic dependencies of an installed EPICS library (macOS)
otool -L "$(brew --prefix epics-asyn)/lib/darwin-aarch64/libasyn.dylib"

# Check RPATH entries (macOS)
otool -l "$(brew --prefix epics-asyn)/lib/darwin-aarch64/libasyn.dylib" | grep -A3 RPATH

# Check all .dylib files installed by a formula (macOS)
find "$(brew --prefix epics-asyn)" -name "*.dylib" -exec otool -L {} \;

# Check installed configure/RELEASE for stale Cellar paths
grep -r 'Cellar' "$(brew --prefix epics-asyn)/configure/" 2>/dev/null

# Linux equivalents
objdump -p "$(brew --prefix epics-asyn)/lib/linux-x86_64/libasyn.so" | grep RPATH
find "$(brew --prefix epics-asyn)" -name "*.so" -exec objdump -p {} \; | grep RPATH
```
