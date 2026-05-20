# minimal-vm-browser

一个“尽可能轻量”的虚拟机浏览器方案：
- 打包极简 Linux Kernel + initramfs（仅浏览器运行时）
- 用 QEMU user-mode networking（SLIRP）实现用户态 NAT
- 不创建额外物理网卡，不暴露新的真实 MAC

## 项目现状

当前仓库已补齐关键脚手架：
- `scripts/`：依赖检查、内核/initramfs/QEMU/EXE 打包、一键构建
- `src/launcher.c`：宿主机启动器，调用 QEMU
- `docs/`：架构、网络与构建指南
- `todo-app/`：本地存储 To-Do 示例（用于验证浏览器运行能力）

## 快速开始

```bash
chmod +x scripts/*.sh
./scripts/check_deps.sh
./scripts/build_all.sh --no-chromium
```

完整构建（含浏览器下载/集成）依赖较多、耗时较长：

```bash
./scripts/build_all.sh
```

## 目录

- `scripts/build_all.sh`: 一键构建入口
- `scripts/build_kernel.sh`: 构建极简 Linux 内核
- `scripts/build_initramfs.sh`: 构建 initramfs
- `scripts/build_qemu.sh`: 构建精简 QEMU（启用 slirp）
- `scripts/build_exe.sh`: 打包启动器与产物
- `src/launcher.c`: VM 启动器
- `docs/BUILD_GUIDE.md`: 分步构建说明
