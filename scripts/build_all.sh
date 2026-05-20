#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NO_CHROMIUM=0
for a in "$@"; do
  [[ "$a" == "--no-chromium" ]] && NO_CHROMIUM=1
  [[ "$a" == "--clean" ]] && rm -rf "$ROOT/build"
done
"$ROOT/scripts/check_deps.sh"
"$ROOT/scripts/build_kernel.sh"
if [[ $NO_CHROMIUM -eq 1 ]]; then NO_CHROMIUM=1 "$ROOT/scripts/build_initramfs.sh"; else "$ROOT/scripts/build_initramfs.sh"; fi
"$ROOT/scripts/build_qemu.sh"
"$ROOT/scripts/build_exe.sh"
echo "Done. artifacts in build/"
