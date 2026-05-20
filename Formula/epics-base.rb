# typed: strict
# frozen_string_literal: true

class EpicsBase < Formula
  desc "Core libraries and build system for EPICS control systems"
  homepage "https://epics-controls.org/"

  # Use the official release asset, not the GitHub-generated archive.
  # The GitHub archive omits the PVA submodules and must not be used.
  url "https://github.com/epics-base/epics-base/releases/download/R7.0.10/base-7.0.10.tar.gz"
  sha256 "44193e962793de514ead442e9b5096a13109f1ee275f131995826468aa89b839"
  version "7.0.10"

  livecheck do
    url :stable
    strategy :github_latest
    regex(/^R(\d+(?:[.-]\d+)+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/ulrikpedersen/homebrew-epics"
    cellar :any
    sha256 arm64_tahoe:   "placeholder_until_ci_runs"
    sha256 arm64_sequoia: "placeholder_until_ci_runs"
    sha256 arm64_sonoma:  "placeholder_until_ci_runs"
    sha256 sonoma:        "placeholder_until_ci_runs"
    sha256 arm64_linux:   "placeholder_until_ci_runs"
    sha256 x86_64_linux:  "placeholder_until_ci_runs"
  end

  keg_only :versioned_formula

  def install
    system "make", "INSTALL_LOCATION=#{prefix}"
  end

  test do
    epics_arch = if OS.mac?
      Hardware::CPU.arm? ? "darwin-aarch64" : "darwin-x86_64"
    else
      Hardware::CPU.arm? ? "linux-aarch64" : "linux-x86_64"
    end

    (testpath/"test_epics.c").write <<~C
      #include <epicsVersion.h>
      #include <stdio.h>
      int main(void) {
        printf("%s\\n", EPICS_VERSION_STRING);
        return 0;
      }
    C

    os_include = OS.mac? ? "os/Darwin" : "os/Linux"
    system ENV.cc, "test_epics.c",
           "-I#{opt_include}",
           "-I#{opt_include}/#{os_include}",
           "-L#{opt_lib}/#{epics_arch}",
           "-lCom",
           "-o", "test_epics"

    assert_match "7.", shell_output("./test_epics")
  end
end
