# typed: strict
# frozen_string_literal: true

class EpicsBase < Formula
  desc "Core libraries and build system for EPICS control systems"
  homepage "https://epics-controls.org/"

  # Use the release asset tarball, not the GitHub-generated archive.
  # GitHub-generated archives omit the PVA submodules and must not be used.
  url "https://github.com/epics-base/epics-base/releases/download/R7.0.10/base-7.0.10.tar.gz"
  sha256 "44193e962793de514ead442e9b5096a13109f1ee275f131995826468aa89b839"

  livecheck do
    url :stable
    strategy :github_latest
    regex(/^R(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/<org>/homebrew-epics"
    sha256 arm64_tahoe:   "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 arm64_sequoia: "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 arm64_sonoma:  "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 sonoma:        "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 arm64_linux:   "0000000000000000000000000000000000000000000000000000000000000000"
    sha256 x86_64_linux:  "0000000000000000000000000000000000000000000000000000000000000000"
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

    assert_path_exists lib/epics_arch.to_s/shared_library("libCom")
    assert_path_exists lib/epics_arch.to_s/shared_library("libca")
  end
end
