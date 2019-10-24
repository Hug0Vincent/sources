---
title: "DVID : Characteristics 2"
date: 2019-10-23T22:24:10+02:00
categories:
- posts
- dvid
tags:
- bluetooth
- network
keywords:
- bluetooth
- network
coverImage: /images/Posts/bg_ble.png
coverSize: full
coverMeta: in
metaAlignment: center
autoThumbnailImage: false
summary : "Solving the challenge \"Characteristics 2\" from the DVID project."
---

# Introduction

I recently bought a [DVID](https://github.com/Vulcainreo/DVID) board which is an open source vulnerable designed IoT device. In this post I will try to explain how to solve the third  challenge of the DVID project. In this challenge we need to write data to a special characteristic. 

# Challenge

Let's flash the firmware, enable  and setup the usb dongle:

{{< codeblock lang="bash"  >}}
sudo avrdude -c usbasp -p m328p -U flash:w:characteristics2.ino.with_bootloader.arduino_standard.hex
sudo systemctl start bluetooth
sudo hciconfig hci1 up
{{< /codeblock >}}

The following commands are exactly the same than those used in my previous [post](/2019/10/dvid-characteristics/), more details on those steps are given in it.

{{< codeblock lang="bash"  >}}
sudo bluetoothctl
scan on
connect 00:13:AA:00:22:57
menu gatt
list-attributes
{{< /codeblock >}}

{{< image classes="fancybox clear center " src="/images/Posts/DVID_ble_2/services.png" thumbnail="/images/Posts/DVID_ble_2/services.png" thumbnail-width="80%" thumbnail-height="80%" >}}

From the challenge tips *Come on to say hello on 0000ffe1* we know that we need to write {{< hl-text orange >}}hello{{< /hl-text >}} on the UUID {{< hl-text orange >}}0000ffe1{{< /hl-text >}}.

{{< codeblock lang="sh"  >}}
select-attribute 0000ffe1-0000-1000-8000-00805f9b34fb
{{< /codeblock >}}

To write data to a specific characteristics it's really easy, you just need to convert your data to hexadecimal values. Here are the hexadecimal values for {{< hl-text orange >}}hello{{< /hl-text >}}

{{< codeblock lang="js"  >}}
write "0x68 0x65 0x6c 0x6c 0x6f"
{{< /codeblock >}}

{{< image classes="fancybox clear center " src="/images/Posts/DVID_ble_3/write.png" thumbnail="/images/Posts/DVID_ble_3/write.png" thumbnail-width="80%" thumbnail-height="80%" >}}

And we get the flag on the board!

{{< image classes="fancybox clear center " src="/images/Posts/DVID_ble_3/flag.jpg" thumbnail="/images/Posts/DVID_ble_3/flag.jpg" thumbnail-width="40%" thumbnail-height="40%" >}}