# typed: strict
# frozen_string_literal: true

class EpicsAutosave < Formula
  desc "EPICS support module for automatically saving and restoring PV values"
  homepage "https://epics-modules.github.io/autosave/"
  url "https://github.com/epics-modules/autosave/archive/refs/tags/R6-0.tar.gz"
  sha256 "73b00123790e813b413dd87f573f9806be1fd36a66c0014cee85a75b6f62cc7c"

  livecheck do
    url :stable
    strategy :github_latest
    regex(/^R(\d+(?:-\d+)+)$/i)
  end

  bottle do
    root_url "https://ghcr.io/v2/ulrikpedersen/epics"
    sha256 cellar: :any, arm64_sequoia: "27666d8a8e1939aac49ed1a79325f05036d3063e5ddb69685279c0c064d802d1"
  end

  keg_only :versioned_formula

  depends_on "epics-base"

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

    assert_path_exists lib/epics_arch.to_s/shared_library("libautosave")
  end
end
