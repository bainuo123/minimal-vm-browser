#!/bin/bash
################################################################################
# build_all.sh - 一键编译所有组件
# 用途: 自动化执行所有构建步骤
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} $1"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

# 显示使用说明
show_usage() {
    cat << EOF
用法: ./scripts/build_all.sh [选项]

选项:
  --help              显示此帮助信息
  --kernel-only       仅编译内核
  --initramfs-only    仅编译 Initramfs
  --qemu-only         仅编译 QEMU
  --exe-only          仅打包 EXE
  --skip-kernel       跳过内核编译
  --skip-initramfs    跳过 Initramfs 编译
  --skip-qemu         跳过 QEMU 编译
  --no-chromium       不安装 Chromium (仅 Initramfs)
  --jobs N            并行编译线程数 (默认: CPU数)
  --verbose           显示详细输出
  --clean             编译前清理

环境变量:
  KERNEL_VERSION      Linux 内核版本 (默认: 6.1.0)
  QEMU_VERSION        QEMU 版本 (默认: 8.0.4)
  BUSYBOX_VERSION     BusyBox 版本 (默认: 1.36.1)

示例:
  ./scripts/build_all.sh                    # 完整编译
  ./scripts/build_all.sh --kernel-only      # 仅编译内核
  ./scripts/build_all.sh --jobs 8           # 使用 8 个线程
  KERNEL_VERSION=6.6.0 ./scripts/build_all.sh

EOF
}

# 检查依赖
check_system_deps() {
    log_header "检查系统依赖"
    
    local missing_deps=()
    
    # 检查编译工具
    for tool in gcc make git wget tar gzip xz cpio; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    # 检查开发库
    if ! pkg-config --exists glib-2.0 2>/dev/null; then
        missing_deps+=("libglib2.0-dev")
    fi
    
    if ! pkg-config --exists pixman-1 2>/dev/null; then
        missing_deps+=("libpixman-1-dev")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[@]}"
        log_warn "请运行:"
        log_warn "  Ubuntu/Debian:"
        log_warn "    sudo apt-get install build-essential git pkg-config libglib2.0-dev libpixman-1-dev"
        log_warn ""
        log_warn "  CentOS/RHEL:"
        log_warn "    sudo yum groupinstall 'Development Tools'"
        log_warn "    sudo yum install glib2-devel pixman-devel"
        return 1
    fi
    
    log_info "✓ 所有依赖已安装"
    return 0
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_usage
                exit 0
                ;;
            --kernel-only)
                BUILD_KERNEL=1
                BUILD_INITRAMFS=0
                BUILD_QEMU=0
                BUILD_EXE=0
                shift
                ;;
            --initramfs-only)
                BUILD_KERNEL=0
                BUILD_INITRAMFS=1
                BUILD_QEMU=0
                BUILD_EXE=0
                shift
                ;;
            --qemu-only)
                BUILD_KERNEL=0
                BUILD_INITRAMFS=0
                BUILD_QEMU=1
                BUILD_EXE=0
                shift
                ;;
            --exe-only)
                BUILD_KERNEL=0
                BUILD_INITRAMFS=0
                BUILD_QEMU=0
                BUILD_EXE=1
                shift
                ;;
            --skip-kernel)
                BUILD_KERNEL=0
                shift
                ;;
            --skip-initramfs)
                BUILD_INITRAMFS=0
                shift
                ;;
            --skip-qemu)
                BUILD_QEMU=0
                shift
                ;;
            --no-chromium)
                NO_CHROMIUM=1
                shift
                ;;
            --clean)
                CLEAN_BUILD=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --jobs)
                JOBS=$2
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# 初始化变量
BUILD_KERNEL=${BUILD_KERNEL:-1}
BUILD_INITRAMFS=${BUILD_INITRAMFS:-1}
BUILD_QEMU=${BUILD_QEMU:-1}
BUILD_EXE=${BUILD_EXE:-1}
NO_CHROMIUM=${NO_CHROMIUM:-0}
CLEAN_BUILD=${CLEAN_BUILD:-0}
VERBOSE=${VERBOSE:-0}
JOBS=${JOBS:-$(nproc)}

# 显示构建配置
show_build_config() {
    log_header "构建配置"
    
    echo "构建组件:"
    echo "  内核:       ${BUILD_KERNEL:-0} $([ $BUILD_KERNEL -eq 1 ] && echo "✓" || echo "✗")"
    echo "  Initramfs:  ${BUILD_INITRAMFS:-0} $([ $BUILD_INITRAMFS -eq 1 ] && echo "✓" || echo "✗")"
    echo "  QEMU:       ${BUILD_QEMU:-0} $([ $BUILD_QEMU -eq 1 ] && echo "✓" || echo "✗")"
    echo "  EXE:        ${BUILD_EXE:-0} $([ $BUILD_EXE -eq 1 ] && echo "✓" || echo "✗")"
    echo ""
    echo "构建选项:"
    echo "  并行线程:   $JOBS"
    echo "  Chromium:   $([ $NO_CHROMIUM -eq 0 ] && echo "启用" || echo "禁用")"
    echo "  清理构建:   $([ $CLEAN_BUILD -eq 0 ] && echo "否" || echo "是")"
    echo ""
}

# 清理旧构建
clean_build() {
    if [ $CLEAN_BUILD -eq 1 ]; then
        log_header "清理旧构建"
        rm -rf "${PROJECT_ROOT}/build"
        log_info "✓ 旧构建已清理"
    fi
}

# 编译内核
build_kernel() {
    if [ $BUILD_KERNEL -eq 0 ]; then
        log_info "跳过内核编译"
        return 0
    fi
    
    log_header "编译 Linux 内核"
    
    export JOBS
    if bash "${SCRIPT_DIR}/build_kernel.sh"; then
        log_info "✓ 内核编译成功"
        return 0
    else
        log_error "✗ 内核编译失败"
        return 1
    fi
}

# 编译 Initramfs
build_initramfs() {
    if [ $BUILD_INITRAMFS -eq 0 ]; then
        log_info "跳过 Initramfs 编译"
        return 0
    fi
    
    log_header "构建 Initramfs"
    
    export JOBS BUSYBOX_VERSION
    
    if [ $NO_CHROMIUM -eq 1 ]; then
        if bash "${SCRIPT_DIR}/build_initramfs.sh" --no-chromium; then
            log_info "✓ Initramfs 构建成功 (无 Chromium)"
            return 0
        fi
    else
        if bash "${SCRIPT_DIR}/build_initramfs.sh"; then
            log_info "✓ Initramfs 构建成功"
            return 0
        fi
    fi
    
    log_error "✗ Initramfs 构建失败"
    return 1
}

# 编译 QEMU
build_qemu() {
    if [ $BUILD_QEMU -eq 0 ]; then
        log_info "跳过 QEMU 编译"
        return 0
    fi
    
    log_header "编译 QEMU"
    
    export JOBS QEMU_VERSION
    if bash "${SCRIPT_DIR}/build_qemu.sh"; then
        log_info "✓ QEMU 编译成功"
        return 0
    else
        log_error "✗ QEMU 编译失败"
        return 1
    fi
}

# 打包 EXE
build_exe() {
    if [ $BUILD_EXE -eq 0 ]; then
        log_info "跳过 EXE 打包"
        return 0
    fi
    
    log_header "打包 EXE"
    
    if bash "${SCRIPT_DIR}/build_exe.sh"; then
        log_info "✓ EXE 打包成功"
        return 0
    else
        log_error "✗ EXE 打包失败"
        return 1
    fi
}

# 显示最终结果
show_final_result() {
    log_header "构建完成"
    
    local build_dir="${PROJECT_ROOT}/build"
    
    if [ -f "${build_dir}/vm_launcher.exe" ]; then
        local exe_size=$(du -h "${build_dir}/vm_launcher.exe" | cut -f1)
        log_info "✓ 虚拟机已生成"
        log_info "  文件: ${build_dir}/vm_launcher.exe"
        log_info "  大小: $exe_size"
        echo ""
        log_info "启动虚拟机:"
        log_info "  Linux/macOS: ${build_dir}/run.sh"
        log_info "  Windows:     ${build_dir}\\run.bat"
        log_info "  直接运行:    ${build_dir}/vm_launcher.exe"
    else
        log_warn "虚拟机未生成 (可能跳过了 EXE 打包)"
    fi
}

# 记录构建时间
record_build_time() {
    local build_log="${PROJECT_ROOT}/build/BUILD_TIME.txt"
    mkdir -p "$(dirname "$build_log")"
    
    cat > "$build_log" << EOF
构建时间记录
构建开始: $BUILD_START_TIME
构建结束: $(date)
构建耗时: $SECONDS 秒
EOF
}

# 主函数
main() {
    local BUILD_START_TIME=$(date)
    local START_TIME=$SECONDS
    
    # 显示欢迎信息
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║                                                       ║"
    echo "║    🚀 Minimal VM Browser - 一键构建工具              ║"
    echo "║                                                       ║"
    echo "║    超轻量级虚拟机 | 极简浏览器 | 用户态网络            ║"
    echo "║                                                       ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # 解析参数
    parse_args "$@"
    
    # 显示配置
    show_build_config
    
    # 检查依赖
    check_system_deps || exit 1
    
    # 清理旧构建
    clean_build
    
    # 执行构建
    local exit_code=0
    
    build_kernel || exit_code=1
    build_initramfs || exit_code=1
    build_qemu || exit_code=1
    build_exe || exit_code=1
    
    # 记录构建时间
    record_build_time
    
    # 显示最终结果
    if [ $exit_code -eq 0 ]; then
        show_final_result
    else
        log_error "构建过程中出现错误"
    fi
    
    # 显示总用时
    local build_duration=$((SECONDS - START_TIME))
    local mins=$((build_duration / 60))
    local secs=$((build_duration % 60))
    
    echo ""
    log_info "总耗时: ${mins}m ${secs}s"
    
    exit $exit_code
}

# 执行主函数
main "$@"
