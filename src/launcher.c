#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void) {
    const char *qemu = "./build/qemu-system-x86_64";
    const char *args[] = {
        qemu,
        "-m", getenv("VM_MEMORY") ? getenv("VM_MEMORY") : "512",
        "-kernel", "./build/vmlinuz",
        "-initrd", "./build/initramfs.gz",
        "-append", "console=ttyS0 rdinit=/init",
        "-nographic",
        "-netdev", "user,id=n1",
        "-device", "virtio-net-pci,netdev=n1",
        NULL
    };
    execv(qemu, (char * const *)args);
    perror("execv qemu failed");
    return 1;
}
