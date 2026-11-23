#!/usr/bin/env bash
# Installs Debian packages on a Linux runner without the package archive when it can:
#   scripts/apt-install.sh <cache folder of .deb files> <package...>
# Packages already installed are skipped. When every missing package has a cached .deb, dpkg installs those
# alone. Only otherwise does apt-get update the index and download, keeping what it fetches in the folder. Some
# runner images ship no apt index, so a slow archive once ran a check job out of time before it reached a check
# (zeist, 23 November 2026).
set -euo pipefail
archives=$1
shift
missing=()
for package in "$@"; do
  [ "$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)" = installed ] || missing+=("$package")
done
if [ ${#missing[@]} -eq 0 ]; then
  echo "Already installed: $*"
  exit 0
fi
debs=()
for package in "${missing[@]}"; do
  deb=$(find "$archives" -maxdepth 1 -name "${package}_*.deb" 2>/dev/null | sort -V | tail -1)
  [ -n "$deb" ] && debs+=("$deb")
done
if [ ${#debs[@]} -eq ${#missing[@]} ] && sudo dpkg -i "${debs[@]}"; then
  echo "Installed from the cache: ${missing[*]}"
  exit 0
fi
sudo apt-get update
sudo apt-get install --yes --no-install-recommends --fix-broken -o Dir::Cache::Archives="$archives" "${missing[@]}"
