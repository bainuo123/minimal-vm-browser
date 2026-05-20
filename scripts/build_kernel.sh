#!/bin/bash
# ==============================================================================
# scripts/build_kernel.sh - 极简 Linux 内核下载与极限裁剪编译脚本
# ==============================================================================

set -e

KERNEL_VER="6.6.21" # 选用长期支持的稳定版内核
KERNEL_DIR="linux-${KERNEL_VER}"
KERNEL_TAR="${KERNEL_DIR}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TAR}"

OUTPUT_DIR="$(pwd)/src"
BUILD_DIR="$(pwd)/build"

mkdir -p downloads build

cd downloads

# 1. 自动安全下载内核源码
if [ ! -f "${KERNEL_TAR}" ]; then
    echo "[+] Downloading Linux Kernel v${KERNEL_VER}..."
    wget -c "${KERNEL_URL}"
fi

# 2. 解压至构建工作区
if [ ! -d "${BUILD_DIR}/${KERNEL_DIR}" ]; then
    echo "[+] Extracting Kernel source code into build workspace..."
    tar -xf "${KERNEL_TAR}" -C "${BUILD_DIR}/"
fi

cd "${BUILD_DIR}/${KERNEL_DIR}"

echo "[+] Generating base miniature configuration (tinyconfig)..."
# 使用内核自带的极限精简基准配置
make defconfig # 先基于x86_64默认配置

echo "[+] Tailoring and tuning kernel options for micro-VM..."
# 通过直接追加到 .config 文件中，激活运行 QEMU 和网络必不可少的 VirtIO 驱动
cat << EOF >> .config
# 启用必要的 initramfs 支持
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y

# 启用 PCI 虚拟总线与串口控制台输出支持
CONFIG_PCI=y
CONFIG_VIRTIO_PCI=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_TTY=y

# 启用 VirtIO 网络核心驱动，以便 SLIRP 用户态网栈可以对接
CONFIG_NET=y
CONFIG_NETDEVICES=y
CONFIG_NET_CORE=y
CONFIG_VIRTIO_NET=y
CONFIG_INET=y

# 关掉庞大的图形驱动、无线网卡等无用模块以极限压减体积
#CONFIG_WLAN=n
#CONFIG_SOUND=n
#CONFIG_DRM=n
EOF

# 刷新并修复配置依赖
make olddefconfig

echo "[+] Starting Kernel compilation (this may take a few minutes)..."
# 使用多线程加速编译
make -j$(nproc) bzImage

# 3. 将编译好的超小内核镜像复制到 src 目录中
if [ -f "arch/x86/boot/bzImage" ]; then
    cp arch/x86/boot/bzImage "${OUTPUT_DIR}/vmlinuz"
    echo "[===] Kernel build completed. Output: ${OUTPUT_DIR}/vmlinuz (~$(du -h ${OUTPUT_DIR}/vmlinuz | cut -f1)) [===]"
else
    echo "[-] ERROR: Kernel compilation failed. bzImage not found."
    exit 1
fi