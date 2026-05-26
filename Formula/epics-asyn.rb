# typed: strict
# frozen_string_literal: true

class EpicsAsyn < Formula
  desc "EPICS module for interfacing to synchronous and asynchronous devices"
  homepage "https://epics-modules.github.io/asyn/"
  url "https://github.com/epics-modules/asyn/archive/refs/tags/R4-45.tar.gz"
  version "4.45"
  sha256 "1a0c304310709a32c52ba2cfe80976fb0ca9f33c284383eab173329bf5ddf292"

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
  depends_on "epics-calc"
  depends_on "epics-seq"
  depends_on "epics-sscan"
  depends_on "libftdi"
  depends_on "libtirpc"
  depends_on "libusb"
  depends_on "libusb-compat"

  def install
    (buildpath/"configure/RELEASE.local").write <<~EOS
      EPICS_BASE=#{Formula["epics-base"].opt_prefix}
      SNCSEQ=#{Formula["epics-seq"].opt_prefix}
      CALC=#{Formula["epics-calc"].opt_prefix}
      SSCAN=#{Formula["epics-sscan"].opt_prefix}
    EOS

    (buildpath/"configure/CONFIG_SITE.local").write <<~EOS
      LINUX_GPIB=NO
      DRV_VXI11=NO
      DRV_USBTMC=YES
      DRV_FTDI=YES
      DRV_FTDI_USE_LIBFTDI1=NO
      TIRPC=YES
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

    assert_path_exists lib/epics_arch.to_s/shared_library("libasyn")
  end
end
