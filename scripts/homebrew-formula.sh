#!/usr/bin/env bash
# Prints the Homebrew formula for a release made by scripts/package.sh.
set -euo pipefail

version="${1:?usage: scripts/homebrew-formula.sh <version> [dist-dir]}"
dist="${2:-dist}"
base_url="https://github.com/raisiqueira/simlet-cli/releases/download/v$version"

checksum() {
  local file="simlet-$version-macos-$1.tar.gz"
  local sum
  sum="$(awk -v file="$file" '$2 == file { print $1 }' "$dist/simlet-$version-checksums.txt")"
  [[ -n "$sum" ]] || { echo "error: no checksum for $file" >&2; exit 1; }
  echo "$sum"
}

arm64_sha="$(checksum arm64)"
x86_64_sha="$(checksum x86_64)"

cat <<EOF
class Simlet < Formula
  desc "Friendly commands for iOS Simulator, on top of xcrun simctl"
  homepage "https://github.com/raisiqueira/simlet-cli"
  version "$version"
  license "MIT"

  depends_on macos: :ventura

  on_arm do
    url "$base_url/simlet-$version-macos-arm64.tar.gz"
    sha256 "$arm64_sha"
  end

  on_intel do
    url "$base_url/simlet-$version-macos-x86_64.tar.gz"
    sha256 "$x86_64_sha"
  end

  def install
    bin.install "simlet"
    generate_completions_from_executable(bin/"simlet", "--generate-completion-script")
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/simlet --version").strip
  end
end
EOF
