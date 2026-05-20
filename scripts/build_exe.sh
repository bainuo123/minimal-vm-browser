#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
mkdir -p "$BUILD"
gcc -O2 "$ROOT/src/launcher.c" -o "$BUILD/vm_launcher"
cat > "$BUILD/run.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/vm_launcher"
SH
chmod +x "$BUILD/run.sh"
echo "built $BUILD/vm_launcher"
