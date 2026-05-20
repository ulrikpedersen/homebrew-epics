# configure/RELEASE Dependency Injection Reference

Every EPICS support module contains a `configure/RELEASE` file that records the
absolute paths of EPICS Base and any module dependencies. The preferred approach in
Homebrew formulae is **not** to patch `configure/RELEASE` directly, but instead to
write a `configure/RELEASE.local` file alongside it.

Most EPICS modules already end their `configure/RELEASE` with an optional make include:

```makefile
-include $(TOP)/configure/RELEASE.local
```

Variables defined in `RELEASE.local` override the placeholder defaults in
`configure/RELEASE`. The original file is left untouched, and the formula's intent
is explicit and easy to read. For modules that do not include `RELEASE.local`, the
formula appends the include directive before building.


---

## Standard pattern

```ruby
def install
  # Write configure/RELEASE.local with Homebrew-specific dependency paths.
  # Variables defined here override the placeholder paths in configure/RELEASE.
  # Always use opt_prefix, never prefix — see opt_prefix vs prefix below.
  (buildpath/"configure/RELEASE.local").write <<~EOS
    EPICS_BASE=#{Formula["epics-base"].opt_prefix}
    ASYN=#{Formula["epics-asyn"].opt_prefix}
  EOS

  # Ensure configure/RELEASE includes RELEASE.local.
  # Most EPICS modules already have this; append it only when absent.
  release = buildpath/"configure/RELEASE"
  unless release.read.include?("RELEASE.local")
    release.open("a") { |f| f.puts "\n-include $(TOP)/configure/RELEASE.local" }
  end

  system "make", "INSTALL_LOCATION=#{prefix}"
end
```

---

## How to determine which variables to set

1. Open an interactive build session or download and extract the source tarball:
   ```sh
   brew install --interactive Formula/epics-<name>.rb
   cat configure/RELEASE
   ```
2. Look for every path variable that is not derived from `$(EPICS_BASE)`. Those
   need to be defined in `RELEASE.local`.
3. Read the module's `README` for documented dependencies.
4. Use the per-module variable name table below as a cross-reference.
5. Check whether `configure/RELEASE` ends with an include of `RELEASE.local`.
   If it does not, the formula must append the include (see standard pattern above).

### Handling `SUPPORT`-relative paths

Many modules derive sibling module paths from a `SUPPORT` umbrella variable:

```makefile
SUPPORT=/some/path
ASYN=$(SUPPORT)/asyn-4-44-2
```

In `RELEASE.local`, define each module path directly. The direct definition overrides
the derived one because `RELEASE.local` is included after the defaults:

```
ASYN=#{Formula["epics-asyn"].opt_prefix}
```

You do **not** need to define `SUPPORT` — just set each module variable individually.

---

## `opt_prefix` vs `prefix`

Always use `Formula["..."].opt_prefix`, never `Formula["..."].prefix`:

| Method | Resolves to | Problem |
|--------|-------------|--------|
| `opt_prefix` | `/opt/homebrew/opt/epics-base` | Stable symlink — correct |
| `prefix` | `/opt/homebrew/Cellar/epics-base/7.0.10` | Baked-in Cellar path — breaks after upgrade |

---

## Per-module variable names

Different modules use different variable names in `configure/RELEASE`. This table
shows the canonical variable name as it appears in each module's template file.

| Module dependency | Variable name in configure/RELEASE |
|-------------------|-----------------------------------|
| EPICS Base | `EPICS_BASE` |
| asyn | `ASYN` |
| autosave | `AUTOSAVE` |
| busy | `BUSY` |
| calc | `CALC` |
| seq | `SEQ` |
| sscan | `SSCAN` |
| std | `STD` |
| streamdevice | `STREAM` |
| motor | `MOTOR` |

The variable name `STREAM` is the canonical name for StreamDevice across this tap.
Some upstream modules define `STREAMDEVICE` instead. When that happens, comment the
`STREAMDEVICE` line out of `configure/RELEASE` so it does not shadow the `STREAM`
variable defined in `RELEASE.local`:

```ruby
inreplace buildpath/"configure/RELEASE", /^(STREAMDEVICE\s*=.*)$/, "# \\1"
```

Always verify against the actual `configure/RELEASE` from the source tarball.
Some modules use non-standard names or derive paths from `SUPPORT`.

---

## Complete examples

### epics-asyn (depends on epics-base only)

```ruby
def install
  (buildpath/"configure/RELEASE.local").write <<~EOS
    EPICS_BASE=#{Formula["epics-base"].opt_prefix}
  EOS

  release = buildpath/"configure/RELEASE"
  unless release.read.include?("RELEASE.local")
    release.open("a") { |f| f.puts "\n-include $(TOP)/configure/RELEASE.local" }
  end

  system "make", "INSTALL_LOCATION=#{prefix}"
end
```

### epics-busy (depends on epics-base and epics-asyn)

```ruby
def install
  (buildpath/"configure/RELEASE.local").write <<~EOS
    EPICS_BASE=#{Formula["epics-base"].opt_prefix}
    ASYN=#{Formula["epics-asyn"].opt_prefix}
  EOS

  release = buildpath/"configure/RELEASE"
  unless release.read.include?("RELEASE.local")
    release.open("a") { |f| f.puts "\n-include $(TOP)/configure/RELEASE.local" }
  end

  system "make", "INSTALL_LOCATION=#{prefix}"
end
```

### epics-motor (depends on epics-base, asyn, busy, calc, sscan)

```ruby
def install
  (buildpath/"configure/RELEASE.local").write <<~EOS
    EPICS_BASE=#{Formula["epics-base"].opt_prefix}
    ASYN=#{Formula["epics-asyn"].opt_prefix}
    BUSY=#{Formula["epics-busy"].opt_prefix}
    CALC=#{Formula["epics-calc"].opt_prefix}
    SSCAN=#{Formula["epics-sscan"].opt_prefix}
  EOS

  release = buildpath/"configure/RELEASE"
  unless release.read.include?("RELEASE.local")
    release.open("a") { |f| f.puts "\n-include $(TOP)/configure/RELEASE.local" }
  end

  system "make", "INSTALL_LOCATION=#{prefix}"
end
```

---

## Troubleshooting

### Build fails with missing path or "No rule to make target"

1. Open a shell in the build directory and inspect both files:
   ```sh
   brew install --interactive Formula/epics-<name>.rb
   cat configure/RELEASE
   cat configure/RELEASE.local   # should exist and contain the paths you wrote
   ```
2. Check that `configure/RELEASE` ends with an include of `RELEASE.local`. If not,
   verify the append logic ran.
3. Check that the variable name in `RELEASE.local` exactly matches the name used
   by the module's Makefiles. StreamDevice is always `STREAM` in this tap; if the
   upstream `configure/RELEASE` defines `STREAMDEVICE`, comment it out (see
   Per-module variable names above).

### Module uses `SUPPORT`-relative paths and still fails

If `configure/RELEASE` includes `RELEASE.local` in the **middle** rather than at the
end, a later line may re-derive a path from `SUPPORT`. In that case, also define
`SUPPORT` in `RELEASE.local`:

```
SUPPORT=#{Formula["epics-base"].opt_prefix.parent}
ASYN=#{Formula["epics-asyn"].opt_prefix}
```
