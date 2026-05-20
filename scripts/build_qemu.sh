#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
mkdir -p "$BUILD"
if command -v qemu-system-x86_64 >/dev/null 2>&1; then
  ln -sf "$(command -v qemu-system-x86_64)" "$BUILD/qemu-system-x86_64"
  echo "using host qemu-system-x86_64"
else
  echo "qemu-system-x86_64 not found; install qemu-system-x86"
  exit 1
fi
