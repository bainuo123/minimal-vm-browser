#!/usr/bin/env bash
set -euo pipefail
req=(bash gcc make curl xz cpio gzip tar)
miss=()
for b in "${req[@]}"; do command -v "$b" >/dev/null 2>&1 || miss+=("$b"); done
if ((${#miss[@]})); then
  echo "Missing deps: ${miss[*]}"; exit 1
fi
echo "All required deps exist."
