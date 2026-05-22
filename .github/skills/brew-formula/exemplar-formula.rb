# typed: strict
# frozen_string_literal: true

# =============================================================================
# ANNOTATED EXEMPLAR FORMULA — epics-asyn
# =============================================================================
# This file is a teaching example. Every section is annotated with Ruby
# comments explaining the intent and the rule it demonstrates. Copy this
# file and adapt it when writing a new EPICS support module formula.
#
# Modelled structurally on homebrew-core C library formulae (e.g. libmodbus).
# =============================================================================

class EpicsAsyn < Formula
  # ---------------------------------------------------------------------------
  # Package metadata
  # Rule: desc must be a single sentence, no trailing period, ≤ 80 characters.
  # Rule: Write natural user-facing phrasing (good: "EPICS module for ..."),
  #       avoid awkward module-name phrasing.
  # Rule: homepage must be HTTPS and point to the module's documentation page.
  # ---------------------------------------------------------------------------
  desc "EPICS module for interfacing to synchronous and asynchronous devices"
  homepage "https://epics-modules.github.io/asyn/"

  # ---------------------------------------------------------------------------
  # Source URL, version override, and integrity
  # Rule: Always use the GitHub archive URL derived from the exact release tag.
  #       The tag format for most EPICS modules is R<major>-<minor>-<patch>.
  # Rule: When the tag uses dash-separated numbers, add an explicit `version`
  #       IMMEDIATELY AFTER `url` and BEFORE `sha256`. This is the only accepted
  #       position: `brew bump-formula-pr` substitutes url + version as a pair.
  #       Omit when the URL already contains a dot-separated version string.
  # Rule: sha256 must be the checksum of the tarball at this exact URL.
  #       Compute with: curl -sL <url> | sha256sum
  # ---------------------------------------------------------------------------
  url "https://github.com/epics-modules/asyn/archive/refs/tags/R4-44-2.tar.gz"
  # version must appear BETWEEN url and sha256 when the source tag uses
  # dash-separated version numbers (R4-44-2, R3-7-5, seq-2-2-1, etc.).
  # Homebrew auto-detection stops at the first ambiguous dash and produces a
  # truncated result (e.g. "4" from "R4-44-2"), causing livecheck false positives.
  # Place version immediately after url so `brew bump-formula-pr` can substitute
  # both fields in one atomic edit.
  # Omit this line only when the URL already contains a dot-separated version
  # (e.g. base-7.0.10.tar.gz); including it then triggers `brew audit --strict`
  # warning: "version X.Y.Z is redundant with version scanned from URL".
  version "4.44.2"
  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"  # replace with real hash

  # ---------------------------------------------------------------------------
  # Livecheck — tells `brew livecheck` and autobump how to find new versions.
  # Rule: Always use :github_latest strategy for EPICS modules on GitHub.
  # Rule: The regex must capture ONLY the numeric portion of the tag so that
  #       Homebrew can compare "4-44-2" (captured) with "4.44.2" (formula
  #       version). Homebrew normalises . and - as equivalent separators.
  # ---------------------------------------------------------------------------
  livecheck do
    url :stable
    strategy :github_latest
    regex(/^R(\d+(?:-\d+)+)$/i)
  end

  # ---------------------------------------------------------------------------
  # Bottle block — pre-built binaries distributed via GHCR.
  # Rule: root_url must point to the organisation's GHCR namespace.
  # Rule: Do NOT include a `cellar` line. The cellar annotation was removed in
  #       Homebrew 4.x; including it causes `brew audit` to error with
  #       `undefined method 'cellar'`. Homebrew now infers relocatability
  #       automatically during `brew test-bot` bottling.
  # Rule: All six platform sha256 entries are required. CI fills in real hashes.
  #       Placeholders must be valid 64-character hex strings (e.g. all-zeros);
  #       text like "placeholder_until_ci_runs" fails audit.
  # ---------------------------------------------------------------------------
  bottle do
    root_url "https://ghcr.io/v2/<org>/epics"
    sha256 arm64_tahoe:   "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 arm64_sequoia: "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 arm64_sonoma:  "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 sonoma:        "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 arm64_linux:   "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 x86_64_linux:  "0000000000000000000000000000000000000000000000000000000000000000"
  end

  # ---------------------------------------------------------------------------
  # revision — increment this (not version) when rebuilding against a new
  # epics-base without a new asyn release. Omit the line when revision is 0.
  # Example: revision 1
  # ---------------------------------------------------------------------------
  # (no revision line here — this is a fresh formula at revision 0)

  # ---------------------------------------------------------------------------
  # keg_only — required for epics-base and all support module formulae.
  # Rule: Always use :versioned_formula. Do not use a custom string.
  # This prevents Homebrew from symlinking into /opt/homebrew/{bin,lib,include}.
  # IOC configure/RELEASE files should reference $(brew --prefix epics-asyn).
  # Exception: omit keg_only for standalone GUI app formulae (Phoebus, EDM, etc.).
  # ---------------------------------------------------------------------------
  keg_only :versioned_formula

  # ---------------------------------------------------------------------------
  # Dependencies
  # Rule: EPICS module dependencies are both build-time and runtime.
  #       Do NOT mark them => :build.
  # Rule: Native build tools (cmake, perl for EPICS, etc.) that are only needed
  #       during compilation get => :build.
  # Rule: Never add depends_on "gcc" — use Apple Clang on macOS.
  # Rule: Keep dependency ordering consistent to avoid style churn.
  #       Preferred order in this tap: build tools first, then runtime EPICS deps.
  # ---------------------------------------------------------------------------
  # Example ordering:
  #   depends_on "re2c" => :build
  #   depends_on "epics-base"
  depends_on "epics-base"  # required at build time (headers, build system) and runtime (shared libs)

  # ---------------------------------------------------------------------------
  # install — build and install the module.
  # The EPICS build system is plain GNU Make with per-platform configuration.
  # ---------------------------------------------------------------------------
  def install
    # -------------------------------------------------------------------------
    # Write configure/RELEASE.local with Homebrew-specific dependency paths.
    # Rule: Always use Formula["..."].opt_prefix, never .prefix.
    #       .prefix resolves to the Cellar path and becomes stale after upgrades.
    #       .opt_prefix resolves to /opt/homebrew/opt/epics-base (stable symlink).
    # Rule: Define each module path directly. Do not set SUPPORT — individual
    #       module variables override any SUPPORT-derived paths.
    # -------------------------------------------------------------------------
    (buildpath/"configure/RELEASE.local").write <<~EOS
      EPICS_BASE=#{Formula["epics-base"].opt_prefix}
    EOS

    # -------------------------------------------------------------------------
    # Ensure configure/RELEASE includes RELEASE.local.
    # Most EPICS modules already end with: -include $(TOP)/configure/RELEASE.local
    # Append the directive only when it is absent.
    # -------------------------------------------------------------------------
    release = buildpath/"configure/RELEASE"
    unless release.read.include?("RELEASE.local")
      release.open("a") { |f| f.puts "\n-include $(TOP)/configure/RELEASE.local" }
    end

    # -------------------------------------------------------------------------
    # Build and install.
    # INSTALL_LOCATION tells the EPICS build system where to put installed files.
    # Do NOT use DESTDIR — EPICS does not honour it; use INSTALL_LOCATION.
    # -------------------------------------------------------------------------
    system "make", "INSTALL_LOCATION=#{prefix}"
  end

  # ---------------------------------------------------------------------------
  # test do — verify the installation by compiling and running real C code.
  # Rule: Must compile and run code that exercises the installed headers.
  #       Running --version or checking a string is NOT acceptable.
  # Rule: The block must not start an IOC or require network access.
  # ---------------------------------------------------------------------------
  test do
    # Determine the EPICS host architecture string so we can find installed libs.
    # EPICS places binaries and libraries under arch-specific subdirectories:
    #   darwin-aarch64, darwin-x86_64, linux-aarch64, linux-x86_64
    epics_arch = if OS.mac?
      Hardware::CPU.arm? ? "darwin-aarch64" : "darwin-x86_64"
    else
      Hardware::CPU.arm? ? "linux-aarch64" : "linux-x86_64"
    end

    epics_base = Formula["epics-base"].opt_prefix

    # Write a minimal C source file that includes asynDriver.h and calls the
    # pasynManager singleton to verify linkage against libasyn.
    (testpath/"test_asyn.c").write <<~C
      #include <asynDriver.h>
      #include <stdio.h>

      int main(void) {
        /* pasynManager is a global pointer set up by asyn at load time.
           Checking it is non-NULL after asynRegisterInterruptSource is a
           minimal verification that the library initialised correctly. */
        if (pasynManager == NULL) {
          fprintf(stderr, "pasynManager is NULL\\n");
          return 1;
        }
        printf("asyn pasynManager OK\\n");
        return 0;
      }
    C

    # Compile the test program.
    # Include paths:
    #   epics-base headers (generic + OS-specific)
    #   asyn headers (this formula's opt_prefix)
    # Library paths:
    #   epics-base libs (libca, libCom)
    #   asyn libs (libasyn)
    os_include = OS.mac? ? "os/Darwin" : "os/Linux"
    system ENV.cc, "test_asyn.c",
           "-I#{epics_base}/include",
           "-I#{epics_base}/include/#{os_include}",
           "-I#{opt_include}",
           "-L#{epics_base}/lib/#{epics_arch}",
           "-L#{opt_lib}/#{epics_arch}",
           "-lasyn", "-lca", "-lCom",
           "-o", "test_asyn"

    # Run the compiled binary and verify it exits cleanly.
    assert_match "pasynManager OK", shell_output("./test_asyn")
  end
end
