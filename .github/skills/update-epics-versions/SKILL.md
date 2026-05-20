---
name: update-epics-versions
description: >
  Activates when asked to add a new EPICS module or update an existing module's version
  in the local documentation. Covers fetching upstream release information, computing
  sha256, updating EPICS_VERSIONS.md and the dependency graph, and flagging when
  dependent formulae need a revision bump. Run this skill BEFORE the brew-formula skill
  when the local docs do not yet reflect the target version.
applyTo: "docs/EPICS_VERSIONS.md"
---

# Update EPICS Versions Skill

Use this skill before writing or updating a formula whenever:

- A module is not yet listed in `docs/EPICS_VERSIONS.md`, or
- The recorded version is older than the release you want to package, or
- You are unsure whether the local docs are current.

The output of this skill is a fully up-to-date `docs/EPICS_VERSIONS.md`. Once that
file is correct, hand off to the **brew-formula** skill to write or update the formula.

---

## Step 1 — Identify the target module and release

1. Confirm the formula name (`epics-<module>`) and the desired version. If the user
   has not specified a version, use the latest stable release (see Step 2).

2. Identify the upstream repository:
   - **GitHub**: note the full URL (e.g. `https://github.com/epics-modules/asyn`).
     Parse `owner` and `repo` from it — these are required for the MCP GitHub tools
     used in Steps 2 and 3.
   - **Non-GitHub**: the user must provide the repository URL directly as an argument
     when calling this skill. Version discovery (Step 2) and source file inspection
     (Step 3) must be done manually using the information they supply.

3. Open `docs/EPICS_VERSIONS.md` and locate the module's row in the package table.
   Note the currently recorded version and URL.

4. If the module has no entry yet, this is a **new module** — follow the new-module
   path in Step 4; otherwise follow the version-bump path.

---

## Step 2 — Fetch the upstream release

### GitHub modules

Use the MCP GitHub tools to query the repository.

**Get the latest release** with `mcp_github_get_latest_release` (`owner`, `repo`).
This returns the tag name, release notes, and asset list.

If the module does not publish GitHub Releases (only tags), fall back to
`mcp_github_list_tags` and take the first result (see archive URL rule below).

Record the **exact tag string** and derive the Homebrew dotted version:

| Tag format | Homebrew version | Example |
|-----------|-----------------|---------|
| `R7-0-10` | `7.0.10` | EPICS Base |
| `R4-44-2` | `4.44.2` | asyn, busy, motor, … |
| `R5-11` | `5.11` | autosave (two components — do **not** append `.0`) |
| `2.8.24` | `2.8.24` | StreamDevice (plain semver, no prefix) |

**Determine the archive URL** using this priority order:

1. **GitHub Release with assets** — if `mcp_github_get_latest_release` returned assets,
   use the `.tar.gz` asset URL attached to that release. This is the preferred source
   because it is an explicitly published artifact (not an auto-generated archive).
2. **Tag only (no Release or no assets)** — use the auto-generated GitHub source archive:
   ```
   https://github.com/<owner>/<repo>/archive/refs/tags/<tag>.tar.gz
   ```

Record the URL in `EPICS_VERSIONS.md` per-package section so future agents use the
correct pattern for this module.

**Compute the sha256** (still requires a download):
```sh
curl -fsSL <archive-url> | shasum -a 256
```

### Non-GitHub modules

The user has provided the repository URL directly. Ask for or confirm:
- The target version tag and its human-readable version string
- The archive URL for that release

Then compute the sha256:
```sh
curl -fsSL <archive-url> | shasum -a 256
```

Record the URL and sha256 ready for the formula step.

---

## Step 3 — Check for dependency changes

Before updating any file, read the release notes or `CHANGES` file for the new
release and look for:

1. **New required dependencies** — a new module added to `configure/RELEASE`
2. **Removed dependencies** — a previously required module dropped
3. **Renamed RELEASE variables** — e.g. a variable renamed between versions
4. **New build-time tools** — e.g. a new `cmake` or `re2c` requirement
5. **Build system changes** — e.g. switched from `make` to `cmake`

Inspect `configure/RELEASE` at the new tag:

**GitHub modules**: use `mcp_github_get_file_contents` with `owner`, `repo`,
`path: "configure/RELEASE"`, and `ref: <tag>`.

**Non-GitHub modules**:
```sh
curl -fsSL <repo-base-url>/raw/<tag>/configure/RELEASE
```
(adjust the URL scheme for the specific hosting platform)

If any dependency changed, the dependency graph in `EPICS_VERSIONS.md` and the
formula's `depends_on` lines will both need updating.

---

## Step 4 — Update `docs/EPICS_VERSIONS.md`

### Version bump for an existing module

Make the following edits to `EPICS_VERSIONS.md`:

1. **Package table row** — update the `Version` column to `X.Y.Z (TAG)` format,
   e.g. `4.45.0 (R4-45-0)`.

2. **Dependency graph** — update the version shown next to the module name.

3. **Per-package section** — update:
   - Tag format example if the pattern changed
   - Build quirks if release notes mention changes
   - Dependencies (build/runtime) if they changed

Do not change the GitHub URL unless the repository was moved upstream.

### New module

Add a row to the **package table**:

```markdown
| `epics-<name>` | X.Y.Z (`TAG`) | https://github.com/<org>/<repo> |
```

Add a leaf entry to the **dependency graph** under the appropriate parent node.

Add a **per-package section** at the end of the file following this template:

```markdown
### `epics-<name>`

- **Formula class**: `Epics<Name>` (CamelCase, strip hyphens)
- **GitHub**: https://github.com/<org>/<repo>
- **Homepage**: <project docs URL>
- **Description**: <one sentence, matching what will go in the formula desc field>
- **Tag format**: `R<major>-<minor>-<patch>` (e.g. `R1-2-3`)
- **Livecheck regex**: `/^R(\d+(?:-\d+)+)$/i`
- **Dependencies (build)**: `epics-base`[, `epics-asyn`, …]
- **Dependencies (runtime)**: `epics-base`[, `epics-asyn`, …]
- **Installs**: shared lib (lib<name>), headers, `.dbd` files
- **Build quirks**: <any non-standard configure flags, variable names, build tools>
```

For modules with plain semver tags (no `R` prefix), use:

```markdown
- **Tag format**: Plain semver `X.Y.Z` (no `R` prefix)
- **Livecheck regex**: `/^v?(\d+(?:\.\d+)+)$/i`
```

#### Check that all dependencies are already in the tap

For each dependency listed in `configure/RELEASE`, verify it has an entry in the
package table and a formula in `Formula/`. If a dependency is **not yet packaged**:

1. It must be added to the tap first — recursively apply this skill to that module
   before continuing with the current one.
2. Add it to the package table, dependency graph, and per-package sections in the
   correct dependency order (deepest dependency first).
3. Do not write the formula for the new module until all its dependencies have
   formulae that pass `brew audit --strict`.

Consult the dependency graph to confirm the insertion point. Never add a module
whose dependencies are only partially present in the tap.

---

## Step 5 — Flag dependent formulae for revision bumps

If the updated module is **`epics-base`**, every formula in this tap that depends on
it must have its `revision` incremented. Consult the dependency graph and list all
affected formulae.

For any **other** module version bump, only formulae that directly depend on it need
a `revision` bump — but only if the binary ABI changed (a shared library was
recompiled). A header-only or `.dbd`-only change does not require a revision bump.

Document which formulae need attention and pass this list to whoever will run the
formula updates.

---

## Step 6 — Verify and hand off

Before handing off to the **brew-formula** skill:

- [ ] Package table row is updated with the new version and tag
- [ ] Dependency graph shows the new version
- [ ] Per-package section reflects any changed dependencies or build quirks
- [ ] Archive URL and sha256 are noted (ready for the formula `url` and `sha256` fields)
- [ ] List of formulae requiring a `revision` bump is documented (if applicable)

The **brew-formula** skill's Step 1 can now be executed against accurate local docs.
