# Copilot Instructions — homebrew-epics

This is a Homebrew tap providing formulae and pre-built bottles for **EPICS Base** and
EPICS support modules. Bottles are hosted on GHCR.

Formulae follow the naming pattern `epics-<module>` (e.g. `epics-base`, `epics-asyn`,
`epics-motor`).

**Before working on any formula, read [AGENTS.md](../AGENTS.md).** It contains all
authoring rules, quality gates, and the commit message format.

## References

| Resource | Path |
|----------|------|
| Authoring rules & quality gates | [AGENTS.md](../AGENTS.md) |
| Canonical versions, URLs, dep graph | [docs/EPICS_VERSIONS.md](../docs/EPICS_VERSIONS.md) |
| Homebrew packaging patterns | [docs/HOMEBREW_PATTERNS.md](../docs/HOMEBREW_PATTERNS.md) |
| Project background & rationale | [docs/CONTEXT.md](../docs/CONTEXT.md) |
| Formula authoring skill (step-by-step) | [skills/brew-formula/SKILL.md](skills/brew-formula/SKILL.md) |
| Update versions skill | [skills/update-epics-versions/SKILL.md](skills/update-epics-versions/SKILL.md) |
| configure/RELEASE reference | [skills/brew-formula/configure-release.md](skills/brew-formula/configure-release.md) |
| RPATH / dylib notes | [skills/brew-formula/rpath-notes.md](skills/brew-formula/rpath-notes.md) |
| Annotated example formula | [skills/brew-formula/exemplar-formula.rb](skills/brew-formula/exemplar-formula.rb) |
| Homebrew documentation | https://docs.brew.sh/ |
| Homebrew Formula Cookbook | https://docs.brew.sh/Formula-Cookbook |
