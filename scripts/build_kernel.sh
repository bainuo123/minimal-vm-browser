#!/bin/bash
# ==============================================================================
# scripts/build_kernel.sh
# 极简 Linux Kernel 自动下载 + 极限裁剪 + 编译脚本（修复驱动膨胀版）
# ==============================================================================

set -euxo pipefail

# ==============================================================================
# 基础变量
# ==============================================================================
KERNEL_VER="6.6.21"
KERNEL_DIR="linux-${KERNEL_VER}"
KERNEL_TAR="${KERNEL_DIR}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TAR}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOWNLOAD_DIR="${ROOT_DIR}/downloads"
BUILD_DIR="${ROOT_DIR}/build"
OUTPUT_DIR="${ROOT_DIR}/src"

mkdir -p "${DOWNLOAD_DIR}" "${BUILD_DIR}" "${OUTPUT_DIR}"

# ==============================================================================
# 下载与解压
# ==============================================================================
cd "${DOWNLOAD_DIR}"
if [ ! -f "${KERNEL_TAR}" ]; then
    echo "[+] Downloading Linux Kernel ${KERNEL_VER}..."
    wget -c "${KERNEL_URL}"
fi

if [ ! -d "${BUILD_DIR}/${KERNEL_DIR}" ]; then
    echo "[+] Extracting kernel source..."
    tar -xf "${KERNEL_TAR}" -C "${BUILD_DIR}"
fi

cd "${BUILD_DIR}/${KERNEL_DIR}"

echo "[+] Cleaning previous build..."
make mrproper

# ==============================================================================
# 生成基础精简配置
# ==============================================================================
echo "[+] Generating tinyconfig..."
make tinyconfig
make scripts

# ==============================================================================
# 极限裁剪：启用必要功能，严格关闭多媒体/设备驱动全家桶
# ==============================================================================
echo "[+] Configuring kernel options..."

# 1. 基础架构与64位
scripts/config --enable 64BIT
scripts/config --enable X86_64

# 2. Initramfs 内存盘支持
scripts/config --enable BLK_DEV_INITRD
scripts/config --enable RD_GZIP

# 3. 基础虚拟控制台
scripts/config --enable TTY
scripts/config --enable VT
scripts/config --enable VT_CONSOLE
scripts/config --enable SERIAL_8250
scripts/config --enable SERIAL_8250_CONSOLE

# 4. VirtIO 虚拟化核心支持 (QEMU 极速引导关键)
scripts/config --enable PCI
scripts/config --enable VIRTIO
scripts/config --enable VIRTIO_PCI

# 5. 用户态网络支持 (SLIRP)
scripts/config --enable NET
scripts/config --enable INET
scripts/config --enable NETDEVICES
scripts/config --enable NET_CORE
scripts/config --enable ETHERNET
scripts/config --enable VIRTIO_NET

# 6. 必要文件系统与内核运行环境
scripts/config --enable TMPFS
scripts/config --enable PROC_FS
scripts/config --enable SYSFS
scripts/config --enable BINFMT_ELF
scripts/config --enable KERNEL_GZIP

# 7. 🔥 核心封杀：强行关闭由于开启 PCI/NET 而连带激活的驱动全家桶
scripts/config --disable NET_VENDOR_AMD
scripts/config --disable NET_VENDOR_INTEL
scripts/config --disable NET_VENDOR_REALTEK
scripts/config --disable NET_VENDOR_MARVELL
scripts/config --disable NET_VENDOR_BROADCOM
scripts/config --disable NET_VENDOR_MICREL
scripts/config --disable NET_VENDOR_NATSEMI
scripts/config --disable NET_VENDOR_SEEQ
scripts/config --disable NET_VENDOR_SMSC
scripts/config --disable NET_VENDOR_STMICRO
scripts/config --disable NET_VENDOR_WIZNET

# 彻底封杀导致你卡死的多媒体驱动、声音、无线网卡和其它硬件
scripts/config --disable MEDIA_SUPPORT
scripts/config --disable SOUND
scripts/config --disable WIRELESS
scripts/config --disable WLAN
scripts/config --disable MISC_DEVICES

# 8. 关闭模块与调试
scripts/config --disable MODULES
scripts/config --disable DEBUG_INFO
scripts/config --disable DEBUG_INFO_BTF
scripts/config --disable DEBUG_KERNEL
scripts/config --disable GDB_SCRIPTS

# ==============================================================================
# 依赖应用与正式编译
# ==============================================================================
echo "[+] Resolving config dependencies..."
make olddefconfig

echo "[+] Building kernel bzImage..."
make -j"$(nproc)" bzImage

# ==============================================================================
# 复制输出
# ==============================================================================
if [ ! -f "arch/x86/boot/bzImage" ]; then
    echo "[-] ERROR: bzImage not found!"
    exit 1
fi

cp arch/x86/boot/bzImage "${OUTPUT_DIR}/vmlinuz"
echo "[===] Kernel build completed successfully! Size: $(du -h "${OUTPUT_DIR}/vmlinuz" | cut -f1) [===]"