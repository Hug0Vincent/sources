---
title: "DVID : Characteristics"
date: 2019-10-23T10:28:41+02:00
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
summary : "Solving the challenge \"Characteristics\" from the DVID project."
---


# Introduction

I recently bought a [DVID](https://github.com/Vulcainreo/DVID) board which is an open source vulnerable designed IoT device. In this post I will try to explain how to solve the second Bluetooth challenge of the DVID project. In this challenge we need to read data from a special characteristic. 

# Challenge

Let's flash the firmware, enable Bluetooth and setup the usb dongle:

{{< codeblock lang="bash"  >}}
sudo avrdude -c usbasp -p m328p -U flash:w:characteristics.ino.with_bootloader.arduino_standard.hex
sudo systemctl start bluetooth
sudo hciconfig hci1 up
{{< /codeblock >}}

For this challenge I'll be using the command line tool {{< hl-text orange >}}bluetoothctl{{< /hl-text >}} which provide easy commands to interact with Bluetooth devices. 

{{< codeblock lang="bash"  >}}
sudo bluetoothctl
{{< /codeblock >}}

First, you can scan devices which are advertising their presence by using this:

{{< codeblock lang="sh"  >}}
scan on
{{< /codeblock >}}

{{< image classes="fancybox clear center " src="/images/Posts/DVID_ble_2/scan.png" thumbnail="/images/Posts/DVID_ble_2/scan.png" thumbnail-width="80%" thumbnail-height="80%" >}}

Thanks to the scan we have the MAC address of the Bluetooth device. We can then connect to the device with his MAC address:

{{< codeblock lang="sh"  >}}
connect 00:13:AA:00:22:57
{{< /codeblock >}}


{{< image classes="fancybox clear center " src="/images/Posts/DVID_ble_2/connect.png" thumbnail="/images/Posts/DVID_ble_2/connect.png" thumbnail-width="80%" thumbnail-height="80%" >}}

After the connection, to interact with the device you need to use the submenu {{< hl-text orange >}}gatt{{< /hl-text >}}. Then to get more information about the different services/characteristics you can use this command:

{{< codeblock lang="sh"  >}}
menu gatt
list-attributes
{{< /codeblock >}}

{{< image classes="fancybox clear center " src="/images/Posts/DVID_ble_2/services.png" thumbnail="/images/Posts/DVID_ble_2/services.png" thumbnail-width="80%" thumbnail-height="80%" >}}

From the challenge tips (*Verbose mode = 1 on 0000ffe1*) we know that something is leaking on the UUID {{< hl-text orange >}}0000ffe1{{< /hl-text >}}.

You can select any UUID and get more details with those commands:

{{< codeblock lang="sh"  >}}
select-attribute 0000ffe1-0000-1000-8000-00805f9b34fb
attribute-info
{{< /codeblock >}}

{{< image classes="fancybox clear center " src="/images/Posts/DVID_ble_2/info.png" thumbnail="/images/Posts/DVID_ble_2/info.png" thumbnail-width="80%" thumbnail-height="80%" >}}

We can see the value {{< hl-text orange >}}01{{< /hl-text >}} but no flag here. Thanks to this command we know which properties can be used with this characteristic. Let's try to subscribe to notifications. Here is a quick recap of the notify property from my previous [post](/2019/10/ble-introduction/):

{{< pullquote >}}
The notify property is for receiving periodical update from the Bluetooth device. For example the phone subscribes for a specific characteristic, then the peripheral device sends data asynchronously.
{{< /pullquote >}}

{{< codeblock lang="sh"  >}}
notify on
{{< /codeblock >}}

And we get the flag!

{{< image classes="fancybox clear center " src="/images/Posts/DVID_ble_2/flag.png" thumbnail="/images/Posts/DVID_ble_2/flag.png" thumbnail-width="90%" thumbnail-height="90%" >}}










