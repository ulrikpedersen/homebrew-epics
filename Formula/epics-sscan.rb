# typed: strict
# frozen_string_literal: true

class EpicsSscan < Formula
  desc "Scan record and associated software for EPICS"
  homepage "https://epics-modules.github.io/sscan/"
  url "https://github.com/epics-modules/sscan/archive/refs/tags/R2-12.tar.gz"
  sha256 "c6b72b2854f15292f9094375aa9898b711e8d96484dcf2502de854638efe058d"

  livecheck do
    url :stable
    strategy :github_latest
    regex(/^R(\d+(?:[.-]\d+)+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/ulrikpedersen/epics"
    sha256 arm64_sequoia: "0000000000000000000000000000000000000000000000000000000000000000"
  end

  keg_only :versioned_formula

  depends_on "epics-base"
  depends_on "epics-seq"

  def install
    (buildpath/"configure/RELEASE.local").write <<~EOS
      EPICS_BASE=#{Formula["epics-base"].opt_prefix}
      SNCSEQ=#{Formula["epics-seq"].opt_prefix}
    EOS

    release = buildpath/"configure/RELEASE"
    unless release.read.include?("RELEASE.local")
      release.open("a") { |f| f.puts "\n-include $(TOP)/configure/RELEASE.local" }
    end

    system "make", "INSTALL_LOCATION=#{prefix}"
  end

  test do
    epics_arch = if OS.mac?
      Hardware::CPU.arm? ? "darwin-aarch64" : "darwin-x86_64"
    else
      Hardware::CPU.arm? ? "linux-aarch64" : "linux-x86_64"
    end

    assert_path_exists lib/epics_arch.to_s/shared_library("libsscan")
  end
end
