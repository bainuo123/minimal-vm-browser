# BUILD GUIDE

1. `./scripts/check_deps.sh`
2. `./scripts/build_all.sh --no-chromium`（快速验证）
3. 运行：`./build/run.sh`

## 缺少文件补齐清单（已完成）
- 构建入口：`scripts/build_all.sh`
- 依赖检测：`scripts/check_deps.sh`
- initramfs 构建：`scripts/build_initramfs.sh`
- QEMU 准备：`scripts/build_qemu.sh`
- 打包启动器：`scripts/build_exe.sh`
- 启动器源码：`src/launcher.c`
- To-Do Web 应用静态文件：`todo-app/index.html` `todo-app/styles.css` `todo-app/app.js`
