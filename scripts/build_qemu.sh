#!/bin/bash
# ==============================================================================
# scripts/build_qemu.sh - Windows (MinGW64) 平台精简 QEMU 交叉编译脚本
# ==============================================================================

set -e

QEMU_VER="8.2.2"
QEMU_DIR="qemu-${QEMU_VER}"
QEMU_TAR="${QEMU_DIR}.tar.xz"
QEMU_URL="https://download.qemu.org/${QEMU_TAR}"

OUTPUT_DIR="$(pwd)/src"
BUILD_DIR="$(pwd)/build"

mkdir -p downloads build

cd downloads

# 1. 下载 QEMU 源码
if [ ! -f "${QEMU_TAR}" ]; then
    echo "[+] Downloading QEMU source v${QEMU_VER}..."
    wget -c "${QEMU_URL}"
fi

# 2. 解压源码
if [ ! -d "${BUILD_DIR}/${QEMU_DIR}" ]; then
    echo "[+] Extracting QEMU source..."
    tar -xf "${QEMU_TAR}" -C "${BUILD_DIR}/"
fi

cd "${BUILD_DIR}/${QEMU_DIR}"

echo "[+] Configuring QEMU for Windows target (Cross-compilation)..."
# 核心关键：--cross-prefix 切换为 MinGW，--enable-slirp 开启用户态网络栈，精简掉所有其他架构
# 使用纯静态或尽量剪裁的配置
./configure \
    --cross-prefix=x86_64-w64-mingw32- \
    --target-list=x86_64-softmmu \
    --enable-slirp \
    --disable-tools \
    --disable-docs \
    --disable-gtk \
    --disable-sdl \
    --disable-vnc \
    --disable-spice \
    --disable-kvm \
    --static

echo "[+] Compiling Micro-QEMU engine..."
make -j$(nproc)

# 3. 提取生成的宿主机 Windows 虚拟机可执行程序
if [ -f "build/qemu-system-x86_64.exe" ]; then
    cp build/qemu-system-x86_64.exe "${OUTPUT_DIR}/"
    echo "[===] QEMU compilation completed. Output: ${OUTPUT_DIR}/qemu-system-x86_64.exe [===]"
else
    # 兼容某些老版本 QEMU 直接在根目录下生成产物的情况
    cp qemu-system-x86_64.exe "${OUTPUT_DIR}/" || (echo "[-] QEMU executable not found."; exit 1)
fi

exit 0