#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"; R="$BUILD/rootfs"
mkdir -p "$R"/{bin,sbin,proc,sys,dev,tmp,opt/chromium,etc}
if command -v busybox >/dev/null 2>&1; then
  cp "$(command -v busybox)" "$R/bin/busybox"
  (cd "$R/bin" && ./busybox --install -s .)
else
  cat > "$R/bin/sh" <<'SH'
#!/bin/sh
echo "busybox missing on host"; exec /bin/sh
SH
  chmod +x "$R/bin/sh"
fi
cat > "$R/init" <<'SH'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev || true
mount -t tmpfs tmp /tmp
ip link set lo up || true
if [ -x /opt/chromium/chrome ]; then
  exec /opt/chromium/chrome --no-sandbox --disable-gpu --remote-debugging-port=9222
fi
echo "Chromium not found, fallback shell"
exec /bin/sh
SH
chmod +x "$R/init"
mkdir -p "$BUILD"
( cd "$R" && find . -print0 | cpio --null -o -H newc | gzip -9 ) > "$BUILD/initramfs.gz"
echo "built $BUILD/initramfs.gz"
