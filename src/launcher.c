// ==============================================================================
// src/launcher.c - 宿主机单一 EXE 资源释放、销毁与虚拟机自启动核心外壳程序
// ==============================================================================

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <shlwapi.h>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "user32.lib")

// 引入由 objcopy 在编译链接时注入的全局二进制资源符号指针
// 命名规则由 objcopy 自动生成：_binary_[文件名]_start / _binary_[文件名]_end
extern char _binary_src_vmlinuz_start[];
extern char _binary_src_vmlinuz_end[];

extern char _binary_src_initramfs_cpio_gz_start[];
extern char _binary_src_initramfs_cpio_gz_end[];

extern char _binary_src_qemu_system_x86_64_exe_start[];
extern char _binary_src_qemu_system_x86_64_exe_end[];

// 辅助函数：将内存中的二进制大对象（Blob）安全写入本地物理硬盘
BOOL WritePayloadToDisk(const char* start, const char* end, const char* targetPath) {
    size_t size = (size_t)(end - start);
    HANDLE hFile = CreateFileA(targetPath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) {
        return FALSE;
    }
    
    DWORD bytesWritten = 0;
    BOOL result = WriteFile(hFile, start, (DWORD)size, &bytesWritten, NULL);
    CloseHandle(hFile);
    
    return result && (bytesWritten == size);
}

// 辅助函数：深度递归删除产生的临时文件夹痕迹
void DeleteSandboxDirectory(const char* path) {
    char searchPath[MAX_PATH];
    sprintf(searchPath, "%s\\*.*", path);
    
    WIN32_FIND_DATAA findData;
    HANDLE hFind = FindFirstFileA(searchPath, &findData);
    if (hFind == INVALID_HANDLE_VALUE) return;
    
    do {
        if (strcmp(findData.cFileName, ".") != 0 && strcmp(findData.cFileName, "..") != 0) {
            char filePath[MAX_PATH];
            sprintf(filePath, "%s\\%s", path, findData.cFileName);
            if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                DeleteSandboxDirectory(filePath);
            } else {
                DeleteFileA(filePath);
            }
        }
    } while (FindNextFileA(hFind, &findData));
    
    FindClose(hFind);
    RemoveDirectoryA(path);
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    char tempDir[MAX_PATH];
    char sandboxPath[MAX_PATH];
    
    // 1. 获取 Windows 系统临时目录并创建一个属于本实例的唯一隔离沙箱环境
    GetTempPathA(MAX_PATH, tempDir);
    sprintf(sandboxPath, "%sMinimalBrowserVM_%lu", tempDir, GetCurrentProcessId());
    
    if (!CreateDirectoryA(sandboxPath, NULL)) {
        MessageBoxA(NULL, "Failed to initialize isolated runtime sandbox workspace.", "Error", MB_ICONERROR);
        return 1;
    }
    
    // 定义释放的目标路径
    char kernelPath[MAX_PATH];
    char initramfsPath[MAX_PATH];
    char qemuPath[MAX_PATH];
    
    sprintf(kernelPath, "%s\\vmlinuz", sandboxPath);
    sprintf(initramfsPath, "%s\\initramfs.cpio.gz", sandboxPath);
    sprintf(qemuPath, "%s\\qemu-engine.exe", sandboxPath);
    
    // 2. 依次高速从物理 EXE 中向临时沙箱中释放内核、文件系统和虚拟化引擎
    if (!WritePayloadToDisk(_binary_src_vmlinuz_start, _binary_src_vmlinuz_end, kernelPath) ||
        !WritePayloadToDisk(_binary_src_initramfs_cpio_gz_start, _binary_src_initramfs_cpio_gz_end, initramfsPath) ||
        !WritePayloadToDisk(_binary_src_qemu_system_x86_64_exe_start, _binary_src_qemu_system_x86_64_exe_end, qemuPath)) {
        
        MessageBoxA(NULL, "Resource unpacking failure. Disk space might be full.", "Fatal Error", MB_ICONERROR);
        DeleteSandboxDirectory(sandboxPath);
        return 1;
    }
    
    // 3. 构建全套 QEMU 启动指令
    // -m 512M: 动态分配 512MB 内存给浏览器运行
    // -kernel / -initrd: 直接基于内存无盘引导 Linux
    // -append: 将串口重定向至控制台，加速启动，关闭无用内核屏显
    // -netdev user... -device virtio-net-pci: 【核心】激活 SLIRP 用户态网络栈，建立专属内部 NAT 空间
    char cmdArgs[4096];
    sprintf(cmdArgs, "\"%s\" -m 512M -kernel \"%s\" -initrd \"%s\" "
                     "-append \"console=ttyS0 quiet panic=1 net.ifnames=0\" "
                     "-nographic -monitor none "
                     "-netdev user,id=net0,net=10.0.2.0/24,dhcpstart=10.0.2.15 "
                     "-device virtio-net-pci,netdev=net0", 
                     qemuPath, kernelPath, initramfsPath);
                     
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    // 可选：如果不希望宿主机弹出 QEMU 的黑色 CMD 窗口，可以设置 SW_HIDE
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE; 
    
    ZeroMemory(&pi, sizeof(pi));
    
    // 4. 正式冷启动拉起内聚虚拟机进程
    if (!CreateProcessA(NULL, cmdArgs, NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL, sandboxPath, &si, &pi)) {
        MessageBoxA(NULL, "Failed to launch execution sandboxed virtual machine virtualization layer.", "Error", MB_ICONERROR);
        DeleteSandboxDirectory(sandboxPath);
        return 1;
    }
    
    // 5. 阻塞等待虚拟机内部的浏览器实例被用户关闭或虚拟机进程自销毁
    WaitForSingleObject(pi.hProcess, INFINITE);
    
    // 关闭句柄
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    
    // 6. 深度清理，强制擦除宿主机临时文件夹内解压出来的所有敏感资源，做到完全绿色不留痕
    DeleteSandboxDirectory(sandboxPath);
    
    return 0;
}