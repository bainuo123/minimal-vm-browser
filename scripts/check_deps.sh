#!/bin/bash
# ==============================================================================
# scripts/check_deps.sh - 宿主机编译环境与依赖链检测脚本
# ==============================================================================

set -e

# 定义必需的命令列表
REQUIRED_CMDS=(
    "make" "gcc" "x86_64-w64-mingw32-gcc" "x86_64-w64-mingw32-objcopy"
    "wget" "tar" "cpio" "gzip" "patch" "bc" "flex" "bison" "git"
)

MISSING_DEPS=0

echo "[*] Initializing compiler and toolchain dependency verification..."

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "[-] ERROR: Missing required command/tool: '$cmd'"
        MISSING_DEPS=$((MISSING_DEPS + 1))
    else
        echo "[+] Found: $cmd"
    fi
done

# 如果检测到缺失依赖，输出安装指导并退出
if [ $MISSING_DEPS -ne 0 ]; then
    echo "=================================================================="
    echo "[-] Verification Failed. Total missing dependencies: $MISSING_DEPS"
    echo "[*] Please run the following command to install required software (Debian/Ubuntu):"
    echo "    sudo apt-get update && sudo apt-get install -y \\"
    echo "        build-essential gcc-mingw-w64-x86-64 binutils-mingw-w64-x86-64 \\"
    echo "        wget cpio gzip patch bc flex bison git libglib2.0-dev libpixman-1-dev"
    echo "=================================================================="
    exit 1
fi

echo "[===] Environment check passed successfully. Ready to build. [===]"
exit 0