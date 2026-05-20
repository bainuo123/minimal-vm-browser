#!/bin/bash
# ==============================================================================
# scripts/build_kernel.sh
# 极简 Linux Kernel 自动下载 + 裁剪 + 编译脚本（GitHub Actions 修复版）
# ==============================================================================

set -euxo pipefail

# ==============================================================================
# 基础变量
# ==============================================================================

KERNEL_VER="6.6.21"

KERNEL_DIR="linux-${KERNEL_VER}"
KERNEL_TAR="${KERNEL_DIR}.tar.xz"

KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TAR}"

# 获取项目根目录（避免 pwd 路径错乱）
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

DOWNLOAD_DIR="${ROOT_DIR}/downloads"
BUILD_DIR="${ROOT_DIR}/build"
OUTPUT_DIR="${ROOT_DIR}/src"

mkdir -p \
    "${DOWNLOAD_DIR}" \
    "${BUILD_DIR}" \
    "${OUTPUT_DIR}"

# ==============================================================================
# 下载内核源码
# ==============================================================================

cd "${DOWNLOAD_DIR}"

if [ ! -f "${KERNEL_TAR}" ]; then
    echo "[+] Downloading Linux Kernel ${KERNEL_VER}..."
    wget -c "${KERNEL_URL}"
fi

# ==============================================================================
# 解压源码
# ==============================================================================

if [ ! -d "${BUILD_DIR}/${KERNEL_DIR}" ]; then
    echo "[+] Extracting kernel source..."
    tar -xf "${KERNEL_TAR}" -C "${BUILD_DIR}"
fi

cd "${BUILD_DIR}/${KERNEL_DIR}"

# ==============================================================================
# 清理旧构建
# ==============================================================================

echo "[+] Cleaning previous build..."
make mrproper

# ==============================================================================
# 生成最小配置
# ==============================================================================

echo "[+] Generating tinyconfig..."
make tinyconfig

# ==============================================================================
# 生成 scripts/config
# ==============================================================================

echo "[+] Building kernel scripts..."
make scripts

# ==============================================================================
# 启用必要功能
# ==============================================================================

echo "[+] Configuring kernel options..."

# 架构
scripts/config --enable 64BIT
scripts/config --enable X86_64

# initramfs
scripts/config --enable BLK_DEV_INITRD
scripts/config --enable RD_GZIP

# 控制台
scripts/config --enable TTY
scripts/config --enable VT
scripts/config --enable VT_CONSOLE

scripts/config --enable SERIAL_8250
scripts/config --enable SERIAL_8250_CONSOLE

# PCI / VirtIO
scripts/config --enable PCI
scripts/config --enable VIRTIO
scripts/config --enable VIRTIO_PCI

# 网络
scripts/config --enable NET
scripts/config --enable INET

scripts/config --enable NETDEVICES
scripts/config --enable ETHERNET

scripts/config --enable NET_CORE
scripts/config --enable VIRTIO_NET

# 文件系统
scripts/config --enable TMPFS
scripts/config --enable PROC_FS
scripts/config --enable SYSFS

# ELF 支持
scripts/config --enable BINFMT_ELF

# 压缩
scripts/config --enable KERNEL_GZIP

# 关闭调试（避免 GitHub Actions 编译失败）
scripts/config --disable DEBUG_INFO
scripts/config --disable DEBUG_INFO_BTF
scripts/config --disable DEBUG_KERNEL
scripts/config --disable GDB_SCRIPTS

# 关闭模块（全部内建）
scripts/config --disable MODULES

# ==============================================================================
# 修复配置依赖
# ==============================================================================

echo "[+] Resolving config dependencies..."
make olddefconfig

# ==============================================================================
# 编译内核
# ==============================================================================

echo "[+] Building kernel bzImage..."

make -j"$(nproc)" bzImage V=1

# ==============================================================================
# 检查输出
# ==============================================================================

if [ ! -f "arch/x86/boot/bzImage" ]; then
    echo "[-] ERROR: bzImage not found!"
    exit 1
fi

# ==============================================================================
# 复制输出
# ==============================================================================

cp arch/x86/boot/bzImage "${OUTPUT_DIR}/vmlinuz"

echo "[+] Kernel copied to:"
echo "    ${OUTPUT_DIR}/vmlinuz"

ls -lh "${OUTPUT_DIR}/vmlinuz"

echo "[===] Kernel build completed successfully [===]"