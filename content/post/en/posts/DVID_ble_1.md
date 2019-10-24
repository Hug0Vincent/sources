---
title: "BLE introduction"
date: 2019-10-19T14:23:07+02:00
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
summary : "Introduction to Bluetooth and method to solve the challenge \"advertising\" from the DVID project."
---

# Introduction

I recently bought a [DVID](https://github.com/Vulcainreo/DVID) board which is an open source vulnerable designed IoT device. In this post I will try to explain how the Bluetooth protocol works and how we can solve the first Bluetooth challenge of the DVID project. 

# Bluetooth protocol

This [talk](https://conference.hitb.org/hitbsecconf2017ams/materials/D2T3%20-%20Slawomir%20Jasek%20-%20Blue%20Picking%20-%20Hacking%20Bluetooth%20Smart%20Locks.pdf) is a good introduction to Bluetooth hacking, what's following come from this document, but if you want more details you should read it. The next diagram shows how a typical connection between a phone and a Bluetooth device work. The device sends advertisement packet to tell other devices that it's up and waiting for connections.

{{< image classes="fancybox clear center fig-100" src="/images/Posts/DVID_ble_1/diag.png" thumbnail="/images/Posts/DVID_ble_1/diag.png" >}}

Once you are connected, the device offers different services, each service has some characteristics, each characteristic has one or more descriptor, a property and a value. 

Services, characteristics, descriptors have 2 forms of ID:

- Typical services (e.g. battery level, device information) use short UUID values defined in the Bluetooth specification
- 16 or 32 bit UUID format for proprietary, vendor-specific ones

Common typical short service IDs:

- 0x180F Battery service
- 0x180A Device information (manufacturer name, model number...)

Typical Descriptor IDs:

- 0x2901 text description
- 0x2902 subscription status

Each characteristic has properties, read/write/notify they can be combined (e.g. read+notify, read+write). The notify property is for receiving periodical update from the Bluetooth device. For example the phone subscribes for a specific characteristic, then the peripheral device sends data asynchronously.

Everything can be summarize with this diagram :

{{< image classes="fancybox clear center fig-100" src="/images/Posts/DVID_ble_1/service.png" thumbnail="/images/Posts/DVID_ble_1/service.png" thumbnail-width="40%" thumbnail-height="10%">}}

# Challenge

The first challenge, {{< hl-text orange >}}advertising{{< /hl-text >}} is really simple, we just need to get the name of the device. All challenges can be easily solved with the {{< hl-text orange >}}nRF Connect{{< /hl-text >}} application, but we are going to use the terminal to solve them. First plug the BLE module and then flash the firmware with this command:

{{< codeblock lang="bash"  >}}
sudo avrdude -c usbasp -p m328p -U flash:w:advertising.ino.with_bootloader.arduino_standard.hex
{{< /codeblock >}}

{{< image classes="fancybox clear center fig-100" src="/images/Posts/DVID_ble_1/flash.jpg" thumbnail="/images/Posts/DVID_ble_1/flash.jpg" thumbnail-width="40%" thumbnail-height="40%">}}

I'm using the CSR BLE adapter provided with the board to scan for Bluetooth devices. You can check that everything is ok with the command ```hciconfig```, to enable your adapter you can use this command ```sudo hciconfig hci1 up```. You can see on the pictures that the adapter is down then up.

{{< image classes="fancybox fig-50" src="/images/Posts/DVID_ble_1/screen2.png" thumbnail="/images/Posts/DVID_ble_1/screen2.png" >}}
{{< image classes="fancybox clear fig-50" src="/images/Posts/DVID_ble_1/screen1.png" thumbnail="/images/Posts/DVID_ble_1/screen1.png" >}}

If it's not already enabled you need to enable Bluetooth with this command ```sudo systemctl start bluetooth```

To scan for Bluetooth devices I'm using {{< hl-text orange >}}hcitool{{< /hl-text >}}, hcitool is used to configure Bluetooth connections and send some special command to Bluetooth devices. 

{{< codeblock lang="bash"  >}}
sudo hcitool lescan
{{< /codeblock >}}

{{< image classes="fancybox center clear fig-100" src="/images/Posts/DVID_ble_1/name.png" thumbnail="/images/Posts/DVID_ble_1/name.png" thumbnail-width="50%" thumbnail-height="50%">}}

Then we send the name of the device to the board over UART, I'm using a tool called {{< hl-text orange >}}minicom{{< /hl-text >}} for this, and we get the flag (the author asked me to hide the flags):


{{< image classes="fancybox center clear fig-100" src="/images/Posts/DVID_ble_1/flag.jpg" thumbnail="/images/Posts/DVID_ble_1/flag.jpg" thumbnail-width="40%" thumbnail-height="40%">}}



