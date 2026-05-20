#!/bin/bash
################################################################################
# scripts/build_exe.sh - 最终单 EXE 启动器资源内嵌与编译脚本
# 用途: 将核心组件通过 objcopy 转换为 COFF 对象，并与外壳 C 语言链接
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 引入与 build_all.sh 一致的颜色与日志输出风格
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 路径定义
SRC_DIR="${PROJECT_ROOT}/src"
BIN_DIR="${PROJECT_ROOT}/bin"
BUILD_DIR="${PROJECT_ROOT}/build"

# 输入源部件路径
KERNEL_IMG="${SRC_DIR}/vmlinuz"
INITRAMFS_IMG="${SRC_DIR}/initramfs.cpio.gz"
QEMU_EXE="${SRC_DIR}/qemu-system-x86_64.exe"

# 最终输出文件
TARGET_EXE="${BIN_DIR}/minimal_browser_vm.exe"

# 交叉编译器定义
CC_HOST="x86_64-w64-mingw32-gcc"
OBJCOPY="x86_64-w64-mingw32-objcopy"

echo -e "${CYAN}====================================================${NC}"
log_info "开始执行最终 Windows 单 EXE 打包流水线..."
echo -e "${CYAN}====================================================${NC}"

# 1. 验证前置核心大部件是否存在
for f in "$KERNEL_IMG" "$INITRAMFS_IMG" "$QEMU_EXE"; do
    if [ ! -f "$f" ]; then
        log_error "未检测到必要组件: $(basename "$f")"
        log_error "请确保 build_kernel.sh, build_initramfs.sh 和 build_qemu.sh 已成功运行！"
        exit 1
    fi
done

# 2. 创建编译目标输出目录
mkdir -p "$BIN_DIR"
mkdir -p "$BUILD_DIR"

log_info "正在将大二进制部件转换为 Windows 原生链接对象 (COFF 格式)..."

# 使用 objcopy 将二进制大对象转化为静态链接库符号
# 这将生成以 _binary_[路径]_start 和 _binary_[路径]_end 命名的全局指针供 launcher.c 调用
cd "$PROJECT_ROOT"

log_info "-> 转换 Linux 内核..."
"$OBJCOPY" -I binary -O pe-x86-64 --binary-architecture i386:x86-64 \
    "src/vmlinuz" "${BUILD_DIR}/kernel.o"

log_info "-> 转换 Initramfs 根文件系统..."
"$OBJCOPY" -I binary -O pe-x86-64 --binary-architecture i386:x86-64 \
    "src/initramfs.cpio.gz" "${BUILD_DIR}/initramfs.o"

log_info "-> 转换 QEMU 虚拟化主引擎..."
"$OBJCOPY" -I binary -O pe-x86-64 --binary-architecture i386:x86-64 \
    "src/qemu-system-x86_64.exe" "${BUILD_DIR}/qemu.o"

# 3. 链接并编译外壳启动器
log_info "正在调用 MinGW 编译器链接 C 启动器与嵌入资源..."

if [ ! -f "${SRC_DIR}/launcher.c" ]; then
    log_error "未找到启动器源码: src/launcher.c"
    exit 1
fi

# 编译参数说明:
# -O2: 优化代码体积与加载速度
# -lshlwapi -luser32: 链接 Windows 路径 API 与窗口管理 API
# -mwindows: 阻止最终的 EXE 在宿主机双击运行时闪烁弹出 CMD 黑色后台窗口（确保纯绿无感运行）
"$CC_HOST" -O2 -mwindows \
    "${SRC_DIR}/launcher.c" \
    "${BUILD_DIR}/kernel.o" \
    "${BUILD_DIR}/initramfs.o" \
    "${BUILD_DIR}/qemu.o" \
    -o "$TARGET_EXE" \
    -lshlwapi -luser32

if [ -f "$TARGET_EXE" ]; then
    log_info "🎉 单 EXE 绿色虚拟机启动器构建成功！"
    log_info "最终产物路径: $TARGET_EXE"
    log_info "最终文件大小: $(du -h "$TARGET_EXE" | cut -f1)"
else
    log_error "链接过程失败，未能生成 $TARGET_EXE"
    exit 1
fi

exit 0