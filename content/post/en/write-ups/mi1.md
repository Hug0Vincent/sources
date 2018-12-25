---
title: "Mission impossible 1"
date: 2018-12-20
categories:
- write-ups
- santhacklausctf
tags:
- forensic
- crypto
keywords:
- forensic
- crypto
coverImage: /images/mi1/bg.png
coverSize: full
coverMeta: in
autoThumbnailImage: false
summary : "Write-up about the challenge mission impossible 1 from the santhacklaus CTF."
---

|  Event | Challenge | Category | Points | Solves |
|:----------:|:------------:|:------------:|:------------:|:------------:|
| santhacklausctf |  mi1  |  Forensic/Crypto  | 800 |  18  |


# TL;DR

After downloading the zip file we were faced with a linux memory dump. After building the correct profile for volatility you had to perform a known plain text attack on an encrypted and splited zip file to recover the file flag.txt.

# Introduction

After downloading the file {{< hl-text orange >}}MI1.zip{{< /hl-text >}} we had a memdump. You first have to check wether it's a linux or a windows memdump. You can run the following command to determine this :

{{< codeblock lang="bash"  >}}
$ strings challenge.elf | grep "Linux version"
Linux version %d.%d.%d
Linux version 3.16.0-6-amd64 (debian-kernel@lists.debian.org) (gcc version 4.9.2 (Debian 4.9.2-10+deb8u1) ) #1 SMP Debian 3.16.57-2 (2018-07-14)
Linux version 3.16.0-6-amd64 (debian-kernel@lists.debian.org) (gcc version 4.9.2 (Debian 4.9.2-10+deb8u1) ) #1 SMP Debian 3.16.57-2 (2018-07-14)
^C
{{< /codeblock >}}

So we have a linux memdump. To use [volatility](https://github.com/volatilityfoundation/volatility) we have to build a special profile and to do that we need :

<p>

- A debian distribution
- The right version of the kernel
- Additional tools


I downloaded the last Debian [release](https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-9.6.0-amd64-netinst.iso) installed it on a VM and run :

{{< codeblock lang="bash"  >}}
$ uname -a
{{< /codeblock >}}


I didn't have the right kernel version so I installed the right one 

{{< codeblock lang="bash"  >}}
$ sudo apt-get install linux-image-3.16.0-6-amd64
{{< /codeblock >}}

reboot my VM and select in the grub the right kernel version. 

{{< codeblock lang="bash"  >}}
$ uname -a
Linux santa 3.16.0-6-amd64 #1 SMP Debian 3.16.57-2 (2018-07-14) x86_64 GNU/Linux
{{< /codeblock >}}

# Building the profile

Then we need to install the kernel headers, it gave me a lot of pain, nothing was working, dependencies were missing. I finally had to install everything by hand.

```
http://security.debian.org/debian-security/pool/updates/main/l/linux/linux-image-3.16.0-6-amd64_3.16.57-2_amd64.deb
http://security.debian.org/debian-security/pool/updates/main/l/linux/linux-headers-3.16.0-6-amd64_3.16.57-2_amd64.deb
http://security.debian.org/debian-security/pool/updates/main/l/linux/linux-compiler-gcc-4.9-x86_3.16.59-1_amd64.deb
http://ftp.fr.debian.org/debian/pool/main/l/linux-tools/linux-kbuild-3.16_3.16.56-1_amd64.deb
http://security.debian.org/debian-security/pool/updates/main/g/gcc-4.9/gcc-4.9_4.9.2-10+deb8u2_amd64.deb
http://security.debian.org/debian-security/pool/updates/main/l/linux/linux-headers-3.16.0-6-common_3.16.57-2_amd64.deb
http://security.debian.org/debian-security/pool/updates/main/g/gcc-4.9/cpp-4.9_4.9.2-10+deb8u2_amd64.deb
http://security.debian.org/debian-security/pool/updates/main/g/gcc-4.9/gcc-4.9-base_4.9.2-10+deb8u2_amd64.deb
http://security.debian.org/debian-security/pool/updates/main/g/gcc-4.9/libgcc-4.9-dev_4.9.2-10+deb8u2_amd64.deb
http://security.debian.org/debian-security/pool/updates/main/g/gcc-4.9/libasan1_4.9.2-10+deb8u2_amd64.deb
http://ftp.fr.debian.org/debian/pool/main/i/isl/libisl10_0.12.2-2_amd64.deb
http://ftp.fr.debian.org/debian/pool/main/c/cloog/libcloog-isl4_0.18.2-1+b2_amd64.deb

```

The last step is to install packages for linux profile generation.

{{< codeblock lang="bash"  >}}
sudo apt-get install build-essential volatility dwarfdump
{{< /codeblock >}}

In order to generate the profile :

{{< codeblock lang="bash"  >}}
cd volatility/tools/linux
make
zip MI1.zip module.dwarf /boot/System.map-3.16.0-6-amd64
mv MI1.zip ../../volatility/plugings/overlays/linux
{{< /codeblock >}}

Let see if our profile is working :

{{< codeblock lang="bash"  >}}
volatility -f challenge.elf --profile LinuxDebianx64 linux_banner
Linux version 3.16.0-6-amd64 (debian-kernel@lists.debian.org) (gcc version 4.9.2 (Debian 4.9.2-10+deb8u1) ) #1 SMP Debian 3.16.57-2 (2018-07-14)
{{< /codeblock >}}

Yeah it's working, our investigation can now start. 

# Digging into the memdump

Fisrt thing to do is to check the bash history :

{{< codeblock lang="bash"  >}}
volatility -f challenge.elf --profile linux_bash
Volatility Foundation Volatility Framework 2.6
Pid      Name                 Command Time                   Command
-------- -------------------- ------------------------------ -------
    1867 bash                 2018-12-16 16:17:45 UTC+0000   rm flag.txt 
    1867 bash                 2018-12-16 16:17:45 UTC+0000   ls
    1867 bash                 2018-12-16 16:17:45 UTC+0000   ls
    1867 bash                 2018-12-16 16:17:45 UTC+0000   sudo reboot
    1867 bash                 2018-12-16 16:17:45 UTC+0000   zip -r -e -s 64K backup.zip *
    1867 bash                 2018-12-16 16:17:45 UTC+0000   cat /dev/urandom > flag.txt 
    1867 bash                 2018-12-16 16:17:45 UTC+0000   cd /var/www/a-strong-hero.com/
    1867 bash                 2018-12-16 16:17:45 UTC+0000   sudo reboot
    1867 bash                 2018-12-16 16:17:49 UTC+0000   cd /var/www/a-strong-hero.com/
    1867 bash                 2018-12-16 16:17:49 UTC+0000   ls
    1867 bash                 2018-12-16 16:18:09 UTC+0000   find . -type f -print0 | xargs -0 md5sum > md5sums.txt
    1867 bash                 2018-12-16 16:18:10 UTC+0000   cat md5sums.txt 
{{< /codeblock >}}

Ok so we got something here let's try to understand this. We have a backup.zip file which was built with specials options and an interesting directory called {{< hl-text orange >}}a-strong-hero.com/{{< /hl-text >}}.

After reading the zip manual we can understand this command 

<p>

- *r* is for recursively 
- *e* is for encrypted
- *s* is for spliting the final zip into serveral parts of 64 Ko

<p>

{{< codeblock lang="bash"  >}}
$ volatility -f challenge.elf --profile LinuxDebianx64 linux_enumerate_files | grep 'a-strong-hero.com'

Volatility Foundation Volatility Framework 2.6
0xffff88001e6190c8                    295194 /var/www/a-strong-hero.com
0xffff88001e61f0c8                    261718 /var/www/a-strong-hero.com/md5sums.txt
0xffff88001e61e4b0                    261933 /var/www/a-strong-hero.com/backup.z02
0xffff88001e61e898                    263120 /var/www/a-strong-hero.com/backup.z05
0xffff88001e61ec80                    263122 /var/www/a-strong-hero.com/backup.z07
0xffff88001e61d0c8                    263123 /var/www/a-strong-hero.com/backup.z08
0xffff88001e61d4b0                    263125 /var/www/a-strong-hero.com/backup.zip
0xffff88001e61d898                    261792 /var/www/a-strong-hero.com/backup.z01
0xffff88001e61dc80                    262990 /var/www/a-strong-hero.com/backup.z04
0xffff88001e61c0c8                    263121 /var/www/a-strong-hero.com/backup.z06
0xffff88001e61c4b0                    263124 /var/www/a-strong-hero.com/backup.z09
0xffff88001e61c898                    295201 /var/www/a-strong-hero.com/jcvd-website
0xffff88001e441898                    295202 /var/www/a-strong-hero.com/jcvd-website/css
0xffff88001e494898                    261747 /var/www/a-strong-hero.com/jcvd-website/css/bootstrap.min.css
0xffff88001e494c80                    261739 /var/www/a-strong-hero.com/jcvd-website/css/custom.css
0xffff88001e4410c8                    261738 /var/www/a-strong-hero.com/jcvd-website/css/bootstrap.css
0xffff88001e4414b0                    261746 /var/www/a-strong-hero.com/jcvd-website/css/.DS_Store
0xffff88001e61b0c8                    295207 /var/www/a-strong-hero.com/jcvd-website/fonts
0xffff88001e441c80                    261755 /var/www/a-strong-hero.com/jcvd-website/fonts/glyphicons-halflings-regular.svg
0xffff88001e43e0c8                    261762 /var/www/a-strong-hero.com/jcvd-website/fonts/glyphicons-halflings-regular.eot
0xffff88001e43e4b0                    261752 /var/www/a-strong-hero.com/jcvd-website/fonts/glyphicons-halflings-regular.woff
0xffff88001e43e898                    261758 /var/www/a-strong-hero.com/jcvd-website/fonts/glyphicons-halflings-regular.woff2
0xffff88001e43ec80                    261760 /var/www/a-strong-hero.com/jcvd-website/fonts/glyphicons-halflings-regular.ttf
0xffff88001e61b4b0                    261734 /var/www/a-strong-hero.com/jcvd-website/index.html
0xffff88001e49a4b0                    295211 /var/www/a-strong-hero.com/jcvd-website/images
0xffff88001e61b898                    261764 /var/www/a-strong-hero.com/jcvd-website/images/pencil_sharpener.jpg
0xffff88001e61bc80                    261766 /var/www/a-strong-hero.com/jcvd-website/images/writing.jpg
0xffff88003ce0f0c8                    261770 /var/www/a-strong-hero.com/jcvd-website/images/header.jpg
0xffff88003ce0f4b0                    261763 /var/www/a-strong-hero.com/jcvd-website/images/iphone.jpg
0xffff88003ce0f898                    261768 /var/www/a-strong-hero.com/jcvd-website/images/microphone.jpg
0xffff88003ce0fc80                    261767 /var/www/a-strong-hero.com/jcvd-website/images/.DS_Store
0xffff88001e49a0c8                    261771 /var/www/a-strong-hero.com/jcvd-website/images/concert.jpg
0xffff88001e49a898                    261735 /var/www/a-strong-hero.com/jcvd-website/.DS_Store
0xffff88001e5ca898                    295216 /var/www/a-strong-hero.com/jcvd-website/js
0xffff88001e49ac80                    261774 /var/www/a-strong-hero.com/jcvd-website/js/jquery.easing.min.js
0xffff88001e4440c8                    261784 /var/www/a-strong-hero.com/jcvd-website/js/ie10-viewport-bug-workaround.js
0xffff88001e4444b0                    261783 /var/www/a-strong-hero.com/jcvd-website/js/custom.js
0xffff88001e444898                    261780 /var/www/a-strong-hero.com/jcvd-website/js/bootstrap.js
0xffff88001e444c80                    261775 /var/www/a-strong-hero.com/jcvd-website/js/jquery-1.11.3.min.js
0xffff88001e5ca0c8                    261772 /var/www/a-strong-hero.com/jcvd-website/js/bootstrap.min.js
0xffff88001e5ca4b0                    261782 /var/www/a-strong-hero.com/jcvd-website/js/.DS_Store
0xffff88001e61cc80                    262949 /var/www/a-strong-hero.com/backup.z03
{{< /codeblock >}}

In the web directory we can find our splited zip and files about a website. For further investigation we need to extract those zip files.

# Extracting the zip parts

Here is the command to extract those zip parts, you also have to extract the file called {{< hl-text orange >}}backup.zip{{< /hl-text >}}

{{< codeblock lang="bash"  >}}
$ volatility -f challenge.elf --profile=LinuxDebianx64 linux_find_file -i 0xffff88001e61d898 -O backup.z01
[...]
$ volatility -f challenge.elf --profile=LinuxDebianx64 linux_find_file -i 0xffff88001e61c4b0 -O backup.z09
{{< /codeblock >}}

To rebuild the zip file :

{{< codeblock lang="bash"  >}}
$ zip -FF backup.zip --out encrypted.zip
$ unzip -v encrypted.zip
Archive:  encrypted.zip
 Length   Method    Size  Cmpr    Date    Time   CRC-32   Name
--------  ------  ------- ---- ---------- ----- --------  ----
      30  Stored       30   0% 2018-12-16 10:57 ee057a25  flag.txt
       0  Stored        0   0% 2018-12-16 09:51 00000000  jcvd-website/
       0  Stored        0   0% 2018-12-16 09:51 00000000  jcvd-website/js/
    6148  Defl:N      178  97% 2018-12-16 09:51 6d88006a  jcvd-website/js/.DS_Store
   36816  Defl:N     9736  74% 2018-12-16 09:51 6e49bf5e  jcvd-website/js/bootstrap.min.js
   95957  Defl:N    33159  65% 2018-12-16 09:51 9365860e  jcvd-website/js/jquery-1.11.3.min.js
   68890  Defl:N    14104  80% 2018-12-16 09:51 e6e7a5a7  jcvd-website/js/bootstrap.js
      79  Defl:N       74   6% 2018-12-16 09:51 771936f7  jcvd-website/js/custom.js
     641  Defl:N      406  37% 2018-12-16 09:51 241e2d06  jcvd-website/js/ie10-viewport-bug-workaround.js
    5564  Defl:N     1853  67% 2018-12-16 09:51 20faacf3  jcvd-website/js/jquery.easing.min.js
   12292  Defl:N     2079  83% 2018-12-16 09:51 97a194fa  jcvd-website/.DS_Store
       0  Stored        0   0% 2018-12-16 09:51 00000000  jcvd-website/images/
   37682  Defl:N    37558   0% 2018-12-16 09:51 f88ae623  jcvd-website/images/concert.jpg
    6148  Defl:N      178  97% 2018-12-16 09:51 6d88006a  jcvd-website/images/.DS_Store
   52003  Defl:N    51761   1% 2018-12-16 09:51 caf85339  jcvd-website/images/microphone.jpg
   49276  Defl:N    49043   1% 2018-12-16 09:51 187195bb  jcvd-website/images/iphone.jpg
   91733  Defl:N    83026  10% 2018-12-16 09:51 04fbc0a3  jcvd-website/images/header.jpg
   26267  Defl:N    26101   1% 2018-12-16 09:51 5cbadcef  jcvd-website/images/writing.jpg
  133773  Defl:N   133615   0% 2018-12-16 09:51 90a56f07  jcvd-website/images/pencil_sharpener.jpg
    7384  Defl:N     2239  70% 2018-12-16 09:51 07211a33  jcvd-website/index.html
       0  Stored        0   0% 2018-12-16 09:51 00000000  jcvd-website/fonts/
   45404  Defl:N    23491  48% 2018-12-16 09:51 9c3c179a  jcvd-website/fonts/glyphicons-halflings-regular.ttf
   18028  Defl:N    18012   0% 2018-12-16 09:51 61c3e876  jcvd-website/fonts/glyphicons-halflings-regular.woff2
   23424  Defl:N    23120   1% 2018-12-16 09:51 f57b14ea  jcvd-website/fonts/glyphicons-halflings-regular.woff
   20127  Defl:N    20032   1% 2018-12-16 09:51 9cb1c758  jcvd-website/fonts/glyphicons-halflings-regular.eot
  108738  Defl:N    26799  75% 2018-12-16 09:51 c9c6ee7c  jcvd-website/fonts/glyphicons-halflings-regular.svg
       0  Stored        0   0% 2018-12-16 09:51 00000000  jcvd-website/css/
    6148  Defl:N      178  97% 2018-12-16 09:51 6d88006a  jcvd-website/css/.DS_Store
  147430  Defl:N    21352  86% 2018-12-16 09:51 1367536e  jcvd-website/css/bootstrap.css
    8335  Defl:N     1613  81% 2018-12-16 09:51 2f33e8e6  jcvd-website/css/custom.css
  122540  Defl:N    19701  84% 2018-12-16 09:51 bbebdb54  jcvd-website/css/bootstrap.min.css
--------          -------  ---                            -------
 1130857           599438  47%                            31 files

{{< /codeblock >}}

The first file is {{< hl-text orange >}}flag.txt{{< /hl-text >}}, we now know that we have to decrypt this zip archive to validate this challenge. I recently read an attack on encrypted zip files. If we have a clear copy of a file that is present on an encrypted zip archive we can retrieve all the files in the encrypted zip. It's a known plain text attack. 

We can use a tool called [pkcrack](https://github.com/keyunluo/pkcrack) to do it and I choosed the file {{< hl-text orange >}}bootstrap.min.js{{< /hl-text >}} as the known file

{{< codeblock lang="bash"  >}}
$ ./pkcrack -C encrypted.zip -c "jcvd-website/js/bootstrap.min.js" -P bootstrap.min.js.zip -p "bootstrap.min.js" -d decrypted.zip
Files read. Starting stage 1 on Tue Dec 25 16:42:41 2018
Generating 1st generation of possible key2_9747 values...done.
Found 4194304 possible key2-values.
Now we're trying to reduce these...
Lowest number: 940 values at offset 5497
Lowest number: 897 values at offset 5349
Lowest number: 862 values at offset 4869
Lowest number: 847 values at offset 4780
Lowest number: 829 values at offset 4066
Lowest number: 825 values at offset 3886
Lowest number: 749 values at offset 3885
Lowest number: 697 values at offset 3880
Lowest number: 695 values at offset 3875
Done. Left with 695 possible Values. bestOffset is 3875.
Stage 1 completed. Starting stage 2 on Tue Dec 25 16:43:01 2018
Ta-daaaaa! key0=751f036a, key1=397078fa, key2=d156dfac
Probabilistic test succeeded for 5877 bytes.
Ta-daaaaa! key0=751f036a, key1=397078fa, key2=d156dfac
Probabilistic test succeeded for 5877 bytes.
Ta-daaaaa! key0=751f036a, key1=397078fa, key2=d156dfac
Probabilistic test succeeded for 5877 bytes.
Ta-daaaaa! key0=751f036a, key1=397078fa, key2=d156dfac
Probabilistic test succeeded for 5877 bytes.
Stage 2 completed. Starting zipdecrypt on Tue Dec 25 16:43:41 2018
Decrypting flag.txt (91c644af94249dd314b62b57)... OK!
Decrypting jcvd-website/js/.DS_Store (2fe6d64c750f20da2d6b7b4e)... OK!
Decrypting jcvd-website/js/bootstrap.min.js (31beae5a6417af2fcee27b4e)... OK!
Decrypting jcvd-website/js/jquery-1.11.3.min.js (68cffaef64b77eca810f7b4e)... OK!
Decrypting jcvd-website/js/bootstrap.js (172450e6004efe284b507b4e)... OK!
Decrypting jcvd-website/js/custom.js (4038fc0d73419d37a34f7b4e)... OK!
Decrypting jcvd-website/js/ie10-viewport-bug-workaround.js (71f134fe12dcf4d413c17b4e)... OK!
Decrypting jcvd-website/js/jquery.easing.min.js (dd66d46318af5411b24b7b4e)... OK!
Decrypting jcvd-website/.DS_Store (ccc90b8c7a949b1dd0297b4e)... OK!
Decrypting jcvd-website/images/concert.jpg (2531ab52a4c3f2af90017b4e)... OK!
Decrypting jcvd-website/images/.DS_Store (cd53bfa34fee99aade507b4e)... OK!
Decrypting jcvd-website/images/microphone.jpg (e04e73cca1576915c96f7b4e)... OK!
Decrypting jcvd-website/images/iphone.jpg (7d0e3ddec5bb0eb5d5537b4e)... OK!
Decrypting jcvd-website/images/header.jpg (558cd122c491a4c95df47b4e)... OK!
Decrypting jcvd-website/images/writing.jpg (de9b24799ceac1377f317b4e)... OK!
Decrypting jcvd-website/images/pencil_sharpener.jpg (89cbb73d79aa6c0472607b4e)... OK!
Decrypting jcvd-website/index.html (e2b688ad4623c81471017b4e)... OK!
*** Error in `./pkcrack': corrupted size vs. prev_size: 0x000055b2dbb0a280 ***
{{< /codeblock >}}

I got an error and when I tried to unzip the {{< hl-text orange >}}decrypted.zip{{< /hl-text >}}, it also gave me an error because the file was corrupted. After many tries and hours spent on this challenge I finally used the *A* option of zip and the tool {{< hl-text orange >}}zipdecrypt{{< /hl-text >}} with the previous keys that we found. (zipdecrypt is in the pkcrack github repository)

{{< codeblock lang="bash"  >}}
$ zip -A encrypted.zip
$ Zip entry offsets do not need adjusting

$ ./zipdecrypt 751f036a 397078fa d156dfac encrypted.zip decrypted.zip
Decrypting flag.txt (91c644af94249dd314b62b57)... OK!
Decrypting jcvd-website/js/.DS_Store (2fe6d64c750f20da2d6b7b4e)... OK!
[...]
Decrypting jcvd-website/css/custom.css (2fb6cfe34b31eb7bfd4d7b4e)... OK!
Decrypting jcvd-website/css/bootstrap.min.css (a0714f05ca3b87dfec097b4e)... OK!

unzip decrypted.zip 
Archive:  decrypted.zip
 extracting: flag.txt                
   creating: jcvd-website/
   creating: jcvd-website/js/
[...]
  inflating: jcvd-website/images/writing.jpg  
  inflating: jcvd-website/images/pencil_sharpener.jpg  
  error:  invalid compressed data to inflate
  inflating: jcvd-website/index.html  
[...] 
  inflating: jcvd-website/css/custom.css  
  inflating: jcvd-website/css/bootstrap.min.css  

$ cat flag.txt
IMTLD{z1p_1s_n0t_alw4y5_s4fe}

{{< /codeblock >}}

And we have our flag : {{< hl-text red >}}IMTLD{z1p_1s_n0t_alw4y5_s4fe}{{< /hl-text >}}
