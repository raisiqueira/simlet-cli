#!/usr/bin/env bash
# Builds one release archive per architecture, plus a checksum file.
set -euo pipefail

version="${1:?usage: scripts/package.sh <version> [output-dir]}"
dist="${2:-dist}"
build_flags=(-c release --arch arm64 --arch x86_64)

swift build "${build_flags[@]}"
bin_path="$(swift build "${build_flags[@]}" --show-bin-path)"

built_version="$("$bin_path/simlet" --version)"
if [[ "$built_version" != "$version" ]]; then
  echo "error: simlet --version prints $built_version, but the release is $version." >&2
  echo "Update the version in Sources/simlet/Simlet.swift." >&2
  exit 1
fi

rm -rf "$dist"
mkdir -p "$dist"

# Separate archives per architecture, because mise picks release files by arch name.
for arch in arm64 x86_64; do
  staging="$(mktemp -d)"
  lipo "$bin_path/simlet" -thin "$arch" -output "$staging/simlet"
  codesign --force --sign - "$staging/simlet"
  tar --no-mac-metadata -czf "$dist/simlet-$version-macos-$arch.tar.gz" -C "$staging" simlet
  rm -rf "$staging"
done

(cd "$dist" && shasum -a 256 ./*.tar.gz | sed 's| \./| |' > "simlet-$version-checksums.txt")
ls -l "$dist"
