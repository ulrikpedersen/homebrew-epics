# typed: strict
# frozen_string_literal: true

class EpicsCalc < Formula
  desc "EPICS calculation records (calc, calcout, sCalc, etc.)"
  homepage "https://epics-modules.github.io/calc/"
  url "https://github.com/epics-modules/calc/archive/refs/tags/R3-7-5.tar.gz"
  sha256 "5cf1a7b3d444e763eb96ca5b9cdbcb9c29f5a6f9ac2b8d9cdb17a007d3fa8347"

  livecheck do
    url :stable
    strategy :github_latest
    regex(/^R(\d+(?:[.-]\d+)+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/ulrikpedersen/epics"
    sha256 cellar: :any, arm64_sequoia: "33d00729ffa64b4196ce2ff241779cd5e5690d11082baac2efcfebd4f2f0ebd0"
  end

  keg_only :versioned_formula

  depends_on "epics-base"

  def install
    (buildpath/"configure/RELEASE.local").write <<~EOS
      EPICS_BASE=#{Formula["epics-base"].opt_prefix}
      SSCAN=
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

    assert_path_exists lib/epics_arch.to_s/shared_library("libcalc")
  end
end
