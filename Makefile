# ###############################################################################
# Makefile - 极简虚拟机浏览器项目核心构建总控
# 用途: 提供细粒度的单步组件编译命令，调度各种自动化 Shell 脚本
# ###############################################################################

# 基础目录配置定义
SCRIPT_DIR := scripts
BIN_DIR    := bin
BUILD_DIR  := build
SRC_DIR    := src

# 关键脚本定义
BUILD_ALL_SH       := $(SCRIPT_DIR)/build_all.sh
BUILD_KERNEL_SH    := $(SCRIPT_DIR)/build_kernel.sh
BUILD_INITRAMFS_SH := $(SCRIPT_DIR)/build_initramfs.sh
BUILD_QEMU_SH      := $(SCRIPT_DIR)/build_qemu.sh
BUILD_EXE_SH       := $(SCRIPT_DIR)/build_exe.sh

.PHONY: all all-pipeline kernel initramfs qemu exe clean help

# 默认目标：直接调用你编写的工业级全自动 build_all.sh 流水线
all: all-pipeline

help:
	@echo "Minimal VM Browser 编译指令集:"
	@echo "  make all         - 运行 build_all.sh 脚本一键全自动编译所有组件"
	@echo "  make kernel      - 单独下载并编译超轻量化 Linux 内核 (vmlinuz)"
	@echo "  make initramfs   - 单独打包极简包含浏览器自启的根文件系统"
	@echo "  make qemu        - 单独交叉编译适用于 Windows 的微型 QEMU 引擎"
	@echo "  make exe         - 将现有组件资源内嵌并链入 C 外壳，生成最终单 EXE"
	@echo "  make clean       - 清理所有临时构建缓存与产物"

# 1. 一键总控流水线
all-pipeline:
	@echo "[+] 启动 build_all.sh 一键总控编译链..."
	@chmod +x $(SCRIPT_DIR)/*.sh
	@bash $(BUILD_ALL_SH)

# 2. 单步调试目标：内核编译
kernel:
	@echo "[+] 单步引导：编译极简 Linux 内核..."
	@chmod +x $(BUILD_KERNEL_SH)
	@bash $(BUILD_KERNEL_SH)

# 3. 单步调试目标：根文件系统打包
initramfs:
	@echo "[+] 单步引导：构建定制 Initramfs 根文件系统..."
	@chmod +x $(BUILD_INITRAMFS_SH)
	@bash $(BUILD_INITRAMFS_SH)

# 4. 单步调试目标：QEMU 引擎编译
qemu:
	@echo "[+] 单步引导：交叉编译微型 Windows-QEMU 进程..."
	@chmod +x $(BUILD_QEMU_SH)
	@bash $(BUILD_QEMU_SH)

# 5. 单步调试目标：外壳打包
exe:
	@echo "[+] 单步引导：执行资源封装链接 (Launcher EXE)..."
	@chmod +x $(BUILD_EXE_SH)
	@bash $(BUILD_EXE_SH)

# 6. 清理所有编译产物
clean:
	@echo "[*] 正在彻底擦除构建缓存与临时生成的二进制部件..."
	rm -rf $(BUILD_DIR)
	rm -rf $(BIN_DIR)
	rm -f $(SRC_DIR)/vmlinuz
	rm -f $(SRC_DIR)/initramfs.cpio.gz
	rm -f $(SRC_DIR)/qemu-system-x86_64.exe
	rm -f $(SRC_DIR)/*.o
	@echo "[+] 项目已恢复至初始纯净状态。"