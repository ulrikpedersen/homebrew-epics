# typed: strict
# frozen_string_literal: true

class EpicsSeq < Formula
  desc "EPICS State Notation Language (SNL) sequencer"
  homepage "https://epics-modules.github.io/sequencer/"
  url "https://github.com/epics-modules/sequencer/archive/refs/tags/seq-2-2-1.tar.gz"
  sha256 "6e5b6774e341683fc0405d41abe7eee565f8d4c199e6cd775db391c24bc5c93f"

  livecheck do
    url "https://github.com/epics-modules/sequencer/tags"
    regex(/^seq-(\d+(?:-\d+)+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/ulrikpedersen/epics"
    sha256 arm64_sequoia: "0000000000000000000000000000000000000000000000000000000000000000"
  end

  keg_only :versioned_formula

  depends_on "epics-base"
  depends_on "re2c" => :build

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

  test do
    epics_arch = if OS.mac?
      Hardware::CPU.arm? ? "darwin-aarch64" : "darwin-x86_64"
    else
      Hardware::CPU.arm? ? "linux-aarch64" : "linux-x86_64"
    end

    assert_path_exists lib/epics_arch.to_s/shared_library("libseq")
  end
end
