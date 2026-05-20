#!/bin/bin/sh
# ==============================================================================
# src/init.sh - 虚拟机内部核心 Init 引导与自启动控制脚本 (PID=1)
# ==============================================================================

# 1. 挂载虚拟内核文件系统
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || true

echo "========================================================"
echo "    Welcome to Minimal Secure Browser Virtual Machine   "
echo "========================================================"

# 2. 初始化网络环回接口与 VirtIO 网卡
echo "[+] Initializing localhost loopback network..."
ifconfig lo 127.0.0.1 up

echo "[+] Detecting and configuring VirtIO Network Interface (SLIRP)..."
# QEMU 默认的 slirp 会将第一张网卡命名为 eth0
ifconfig eth0 up

# 3. 通过内置的 udhcpc 自动向 QEMU 用户态 NAT 栈请求分配 IP
echo "[+] Requesting IP address from local space user-NAT via DHCP..."
udhcpc -i eth0 -n -q -T 2 -A 1

echo "[+] Current network status inside sandbox:"
ifconfig eth0 | grep 'inet addr' || echo "[-] Warning: No IP obtained, running local sandbox mode."

# 4. 创建系统必须的软链接与临时区
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts

# 5. 秒级直接冷启动拉起浏览器内核，阻止其崩溃重启循环
while true; do
    echo "[*] Launching browser engine interface..."
    # 调起打包进入根文件系统的单窗口定制浏览器，默认打开本地沙箱主页或指定引导页
    /usr/bin/browser
    echo "[-] Browser exited or crashed. Respawning in 2 seconds..."
    sleep 2
done

# 如果万一跳出循环，防止内核 Panic，进入交互式 Shell 备用
exec /bin/sh