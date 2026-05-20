#!/bin/bash
################################################################################
# build_kernel.sh - 编译最小化 Linux 内核
# 用途: 构建虚拟机用的最小化 Linux 内核 (vmlinuz ~5MB)
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_ROOT}/build"
KERNEL_VERSION="${KERNEL_VERSION:-6.1.0}"
KERNEL_SOURCE_DIR="${BUILD_DIR}/linux-kernel-src"
KERNEL_BUILD_DIR="${BUILD_DIR}/linux-kernel-build"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建构建目录
mkdir -p "$BUILD_DIR"
mkdir -p "$KERNEL_BUILD_DIR"

log_info "=========================================="
log_info "Linux 内核编译 (版本: $KERNEL_VERSION)"
log_info "=========================================="

# 步骤 1: 下载内核源码
log_info "步骤 1/5: 下载 Linux 内核源码..."
if [ ! -d "$KERNEL_SOURCE_DIR" ]; then
    cd "$BUILD_DIR"
    
    KERNEL_URL="https://www.kernel.org/releases/linux/v${KERNEL_VERSION%.*}.x/linux-${KERNEL_VERSION}.tar.xz"
    log_info "从 $KERNEL_URL 下载..."
    
    if ! wget -q --show-progress "$KERNEL_URL"; then
        log_error "下载失败！请检查网络或手动下载"
        exit 1
    fi
    
    tar xf "linux-${KERNEL_VERSION}.tar.xz"
    mv "linux-${KERNEL_VERSION}" "$KERNEL_SOURCE_DIR"
else
    log_warn "内核源码已存在，跳过下载"
fi

# 步骤 2: 应用最小化配置
log_info "步骤 2/5: 应用极简配置 (tinyconfig)..."
cd "$KERNEL_SOURCE_DIR"

# 清理旧配置
make -j$(nproc) O="$KERNEL_BUILD_DIR" mrproper > /dev/null 2>&1 || true

# 使用 tinyconfig 作为基础
make -j$(nproc) O="$KERNEL_BUILD_DIR" tinyconfig

# 步骤 3: 添加必要的虚拟化模块配置
log_info "步骤 3/5: 启用虚拟化必要模块..."

KERNEL_CONFIG="${KERNEL_BUILD_DIR}/.config"

# 追加配置
cat >> "$KERNEL_CONFIG" << 'EOF'
# 虚拟化支持
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_CONSOLE=y

# 网络支持
CONFIG_NET=y
CONFIG_INET=y
CONFIG_IPV4=y
CONFIG_IPV6=y
CONFIG_NETDEVICES=y
CONFIG_NET_CORE=y

# 文件系统
CONFIG_EXT4_FS=y
CONFIG_TMPFS=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y

# 串口控制台
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_CORE_CONSOLE=y

# 必要的驱动
CONFIG_KEYBOARD_ATKBD=y
CONFIG_MOUSE_PS2=y

# 关闭不必要的功能 (已在 tinyconfig 中禁用)
# CONFIG_SOUND is not set
# CONFIG_VIDEO_FOR_LINUX is not set
# CONFIG_X11_DRIVER_MGMT is not set
EOF

# 更新配置依赖
make -j$(nproc) O="$KERNEL_BUILD_DIR" olddefconfig > /dev/null 2>&1

log_info "内核配置已应用"

# 步骤 4: 编译内核
log_info "步骤 4/5: 编译内核 (这可能需要 10-15 分钟)..."
log_info "使用 $(nproc) 个线程编译..."

cd "$KERNEL_SOURCE_DIR"
make -j$(nproc) O="$KERNEL_BUILD_DIR" bzImage 2>&1 | tee "$BUILD_DIR/kernel_build.log" | tail -20

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log_error "内核编译失败！查看日志: $BUILD_DIR/kernel_build.log"
    exit 1
fi

# 步骤 5: 验证和复制
log_info "步骤 5/5: 验证编译结果..."

KERNEL_IMAGE="${KERNEL_BUILD_DIR}/arch/x86/boot/bzImage"
if [ ! -f "$KERNEL_IMAGE" ]; then
    log_error "内核镜像不存在: $KERNEL_IMAGE"
    exit 1
fi

# 复制到最终位置
cp "$KERNEL_IMAGE" "$BUILD_DIR/vmlinuz"

# 显示文件大小
KERNEL_SIZE=$(du -h "$BUILD_DIR/vmlinuz" | cut -f1)
log_info "✓ 内核编译完成！"
log_info "  输出文件: $BUILD_DIR/vmlinuz"
log_info "  文件大小: $KERNEL_SIZE"

# 显示编译统计
log_info ""
log_info "编译统计:"
grep -E "^(  [A-Z]|  [0-9])" "$BUILD_DIR/kernel_build.log" | tail -10 || true

log_info ""
log_info "下一步: 运行 './scripts/build_initramfs.sh' 构建根文件系统"
