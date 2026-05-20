#!/bin/bash
# ==============================================================================
# scripts/build_initramfs.sh - 极简根文件系统 (Initramfs) 全自动打包脚本
# ==============================================================================

set -e

BB_VER="1.36.1"
BB_DIR="busybox-${BB_VER}"
BB_TAR="${BB_DIR}.tar.bz2"
BB_URL="https://busybox.net/downloads/${BB_TAR}"

OUTPUT_DIR="$(pwd)/src"
BUILD_DIR="$(pwd)/build"
INITRAMFS_ROOT="${BUILD_DIR}/initramfs_root"

mkdir -p downloads build

cd downloads

# 1. 下载 BusyBox 源码
if [ ! -f "${BB_TAR}" ]; then
    echo "[+] Downloading BusyBox v${BB_VER}..."
    wget -c "${BB_URL}"
fi

# 2. 解压 BusyBox
if [ ! -d "${BUILD_DIR}/${BB_DIR}" ]; then
    echo "[+] Extracting BusyBox source..."
    tar -xf "${BB_TAR}" -C "${BUILD_DIR}/"
fi

# 3. 编译静态 BusyBox
cd "${BUILD_DIR}/${BB_DIR}"
echo "[+] Configuring BusyBox (Static Build)..."
make defconfig

# 修改配置以确保 BusyBox 编译为静态二进制文件（无需外部 glibc 依赖）
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

echo "[+] Compiling BusyBox..."
make -j$(nproc)
echo "[+] Installing BusyBox into temporary tree..."
make install CONFIG_PREFIX="${INITRAMFS_ROOT}"

# 4. 构建标准的 Linux 目录树与环境
echo "[+] Creating minimal Linux directory tree layout..."
cd "${INITRAMFS_ROOT}"
mkdir -p dev proc sys etc/init.d tmp var/log root usr/lib64

# 创建核心设备节点 (QEMU 启动时必需)
sudo mknod -m 600 dev/console c 5 1 || true
sudo mknod -m 666 dev/null c 1 3 || true
sudo mknod -m 666 dev/tty c 5 0 || true

# 5. 集成并裁剪嵌入式浏览器 (以微型或无 X11/Cage 容器集成的单窗口 Chromium 为主)
echo "[+] Integrating browser components and lightweight libs..."
# 注意：在真实的极简环境中，我们通常会拷贝预编译好的轻量化图形运行库（如含有 EGL/Wayland 或直接写 Framebuffer 的微型浏览器组件）
# 这里为流程骨架，我们将所需的依赖及浏览器二进制放到 usr/bin 目录下
mkdir -p usr/bin
# (此处通常通过包管理器或预编译链将最小化的无头/单窗口浏览器核心拷贝进 usr/bin/browser)
# 为了演示完整流，我们创建一个模拟或使用极简静态浏览器程序
cat << 'EOF' > usr/bin/browser
#!/bin/sh
echo "[Browser Shell] Starting Chromium Core with single window mode..."
# 启动 Chromium 内核参数：禁用沙箱（因为外部已经是 VM 沙箱）、禁用 GPU 硬件加速、进入信息亭全屏模式
# exec chromium-browser --no-sandbox --disable-gpu --kiosk --window-position=0,0 http://127.0.0.1
EOF
chmod +x usr/bin/browser

# 6. 载入宿主机编写的通用自启动 /init 脚本
echo "[+] Injecting master initialization boot script..."
cp "${OUTPUT_DIR}/../src/init.sh" ./init
chmod +x init

# 7. 整体打包打包为 CPIO 压缩镜像
echo "[+] Compiling and compressing final Initramfs archive..."
find . -print0 | cpio --null -ov --format=newc | gzip -9 > "${OUTPUT_DIR}/initramfs.cpio.gz"

echo "[===] Initramfs production successfully completed! Output: ${OUTPUT_DIR}/initramfs.cpio.gz (~$(du -h ${OUTPUT_DIR}/initramfs.cpio.gz | cut -f1)) [===]"
exit 0