# Description

The Raspberry Pi 4 is an inexpensive single-board computer that contains four Arm Cortex-A72 cores. However, at the current time (`April 8, 2023`), this plataform does not support the Trusted OS capable of running *secure* services in a TEE enclosure. Note that this port will not became the system secure, because in Raspberry PI boards, all of the memory used is DRAM, which is available from both the Non-Secure and Secure State. To make the system safe, both in terms of the CPU and in terms of memory and peripherals, a **Hypervisor** must be used to overcome the defects inherent in the board itself, which have already been mentioned.

However, this port will show all the steps, from the generation of the **Rich Operating System**, to the compilation of the **ARM Trusted Firmware** and the **Trusted OS** to run [OPTEE](https://www.op-tee.org/) on the board.

The image below graphically illustrates the steps to be performed:

![](https://github.com/joaopeixoto13/OPTEE-RPI4/blob/main/Images/Flow.png)

Not only, but in order to understand the main blocks in the architecture of OPTEE, namely which packages will be needed both for the Client Application and for the Trusted Application, see the image below:

![](https://github.com/joaopeixoto13/OPTEE-RPI4/blob/main/Images/BuildingBlocks.png)
---

# Generate the Rich Operating System

First, it is necessary to generate the unsecured, or rich, operating system in order to run the Client Application. 

For this, [Buildroot](https://buildroot.org/) was used, which is nothing more than a simple and easy to use tool to generate embedded Linux systems through cross-compilation.

Open a console and write:

```
mkdir OPTEE-RPI4
cd OPTEE-RPI4/
```
Check the [BuildRoot User Manual](https://buildroot.org/downloads/manual/manual.html), in order to verify if all mandatoy packages are installed. 
If not, install.

```
sudo apt update && sudo apt upgrade

git clone git://git.buildroot.net/buildroot 
cd buildroot/
ls
ls configs/
```

In this stpe, we should see the configuration files for our board! (for example, raspberrypi4_64_defconfig)
If not, check on the internet.

From the buildroot directory, run the following command:

```
make raspberrypi4_64_defconfig
```

We should see `configuration written to .../OPTEE-RPI4/buildroot/.config`

Run the next command to bring the graphical interface for our build:

```
make menuconfig
```

- Change the serial port ID and baudrate:
```
System Configuration ==> Run a getty (login prompt) after boot 
(Change "**TTY port**" to "**ttyAMA0**" and **baudrate to 115200**) (Change the serial port and baudrate)
```

- Enable **DHCP** and **Dropbear**:
```
Target Packages ==> Networking Applications
(Enable "dhcpcd" and "dropbear")
```
**Note**: The `dropbear` provides a Secure-Shell compatible server and client, as SSH, for environments with lower resources, such as Embedded Systems.

- Enable **optee-client**:
```
Target Packages ==> Security
(Enable "optee-client")
```

**Note**: The `optee-client` provides all the tools to run the Client Application (Context, Session, TEE-Supplicant ...) and will be built as library (*libteec.so*) and included in rootfs.


- Enable filesystem compression images
```
Filesystem images ==> tar the root filesystems 
(Enable it and select in "compression method" the "bzip2")
```

To start the build process, simply run:

```
make -j$(nproc)
```

(*This step can take about ~1h to be completed on a laptop with an Intel i7-9750H processor*)

Once the process is done, **and if no error occurred**, Buildroot output is stored in a single directory, output/. This directory contains several subdirectories:

- `images/`: where all the images (kernel image, bootloader and root filesystem images) are stored. These are the files you need to put on your target system.
- `build/`: where all the components are built (this includes tools needed by Buildroot on the host and packages compiled for the target). This directory contains one subdirectory for each of these components.
- `host/`: contains both the tools built for the host, and the sysroot of the target toolchain. The former is an installation of tools compiled for the host that are needed for the proper execution of Buildroot, including the cross-compilation toolchain. The latter is a hierarchy similar to a root filesystem hierarchy. It contains the headers and libraries of all user-space packages that provide and install libraries used by other packages. However, this directory is not intended to be the root filesystem for the target: it contains a lot of development files, unstripped binaries and libraries that make it far too big for an embedded system. These development files are used to compile libraries and applications for the target that depend on other libraries.
- `staging/`: is a symlink to the target toolchain sysroot inside host/, which exists for backwards compatibility.
- `target/`: which contains almost the complete root filesystem for the target: everything needed is present except the device files in /dev/ (Buildroot can’t create them because Buildroot doesn’t run as root and doesn’t want to run as root). Also, it doesn’t have the correct permissions (e.g. setuid for the busybox binary). Therefore, this directory should not be used on your target. Instead, you should use one of the images built in the images/ directory. If you need an extracted image of the root filesystem for booting over NFS, then use the tarball image generated in images/ and extract it as root. Compared to staging/, target/ contains only the files and libraries needed to run the selected target applications: the development files (headers, etc.) are not present, the binaries are stripped.

Next, run the next command to configure the kernel:

```
make linux-menuconfig
```

- Enable **Trusted Execution Environment support**:
```
Device Drivers ==> Trusted Execution Environment support
```

**Note**: The `Trusted Execution Environment support` provides all the drivers to establish the communication between the Secure and Non-Secure World (more known as *Secure Monitor*). This driver will be built as module (*optee.ko*) by default and included in rootfs.

---

# Update the ARM Trusted Firmware

In this case, although ARM offers the [Firmware](https://github.com/ARM-software/arm-trusted-firmware) support to Raspberry Pi 4 platform, at the moment the BL32 (or Trusted OS) is not supported.

In a more technical perspective, the ARM implements the **cold boot path**, or ARM Trusted Firmware (ATF) **Secure Boot**, that is responsible to authenticate a series of cryptographic signed binary images each containing a different stage or element in the system boot process to be loaded and executed. Every bootloader (BL) stage accomplishes a different stage in the initialization process:

- **BL1** - AP Trusted ROM
- **BL2** - Trusted Boot Firmware
- **BL31** - EL3 Runtime Firmware
- **BL32** - Secure-EL1 Payload
- **BL33** - Non-trusted Firmware

For more information, please consult the [link](https://chromium.googlesource.com/chromiumos/third_party/arm-trusted-firmware/+/v1.2-rc0/docs/firmware-design.md)

In this port, and knowing the physical memory layout form the point of view of the ARM cores, visible in the image below, the approach is to copy the OPTEE Trusted OS binary to the entry address, or Secure Payload (0x10100000), because the BL32 binaries are stored in the FIP address space (0x20000). Not only, but also the Device Tree Blob (DTB) address must be defined to describe the hardware features and the Secure State must be defined. All this steps are described below.

![alt text](https://github.com/joaopeixoto13/OPTEE-RPI4/blob/main/Images/Memory.png)

First, we need to fork (or download) the existing ARM Trusted Firmware from the offcial ARM Github website:

```
cd OPTEE-RPI4
git clone git@github.com:ARM-software/arm-trusted-firmware.git

cd /arm-trusted-firmware/plat/rpi/rpi4
```

Next, to perform all the discussed above, open the `rpi4_bl31_setup.c` and navigate to the **bl31_early_platform_setup2** function:
```
code rpi4_bl31_setup.c
```
As can been seen, the function *bl31_early_platform_setup2** performs any BL31 early platform setup and can be a opportunity to copy parameters passed by the calling EL (S-EL1 in BL2 & EL3 in BL1) before they are lost (potentially). However, in this case, copy the following code after the console initialization *rpi3_console_init()* and before the bl33 initialization:

```
// Define the OP-TEE OS image size (500k bytes)
const size_t trustedOS_size = 500 * 1024;		

// Define the OP-TEE OS image load address (FIP address - 0x20000)
const void *const fip_addr = (const void*)0x20000;	

// Define the OP-TEE OS image address (Secure Payload - 0x10100000)
void *const trustedOS_addr = (void*)0x10100000;				

// Print some information (Boot debug)
VERBOSE("rpi4: copy trusted_os image (%lu bytes) from %p to %p\n", trustedOS_size, fip_addr, trustedOS_addr);

// Copy the OP-TEE OS image to the entry address
memcpy(trustedOS_addr, fip_addr, trustedOS_size);	

// Define the bl32 entry point address (0x10100000)
bl32_image_ep_info.pc = (uintptr_t)trustedOS_addr;

// Define the Device Tree Blob (DTB) address
bl32_image_ep_info.args.arg2 = rpi4_get_dtb_address();		

// Define the Secure State
SET_SECURITY_STATE(bl32_image_ep_info.h.attr, SECURE);	

// Print some information (Boot debug)
VERBOSE("rpi4: trusted_os entry: %p\n", (void*)bl32_image_ep_info.pc);

// Print some information (Boot debug)
VERBOSE("rpi4: bl32 dtb: %p\n", (void*)bl32_image_ep_info.args.arg2);
```

**Note**: The `rpi4_bl31_setup.c` code can be found [here](https://github.com/joaopeixoto13/OPTEE-RPI4/blob/main/rpi4_bl31_setup.c)

# Update the OPTEE Trusted OS

First, we need to download the existing OPTEE Trusted OS from the official OPTEE Github website:

```
cd OPTEE-RPI4
git clone git@github.com:OP-TEE/optee_os.git
```

Next, execute the following command to create a new platform for the Raspberry Pi 4 based on the previsous version:
```
cd optee_os/core/arch/arm
cp -rf plat-rpi3 plat-rpi4

cd plat-rpi4
ls
```

Now, you should see four files:
- **conf.mk**: This is the device specific makefile where you define configurations unique to your platform
- **main.c**: This platform specific file will contain power management handlers and code related to the UART
- **platform_config.h**: Memory configuration and define base addresses 
- **sub.mk**: Indicates the source files

However, only two things must be changed in the file `platform_config.h`. This things are:
- The **UART base address**: 0xfe215040
- The **UART Clock Frequency**: 48000000

The **UART base address** can be found in the next [link](https://www.raspberrypi.com/documentation/computers/configuration.html) and the **UART Clock Frequency** can be found in this [link](https://www.raspberrypi.com/documentation/computers/config_txt.html#init_uart_clock) 

**Note**: The `platform_config.h` code can be found [here](https://github.com/joaopeixoto13/OPTEE-RPI4/blob/main/platform_config.h)

---

# Compile the ARM Trusted Firmware and the Trusted OS

Before compile the ARM Trusted Firmware and the Trusted OS, we need to download the ARM toolchains. In this case, was used the aarch64 11.3 version and can be downloaded [here](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads).

After that, **extract the toolchain** to the working directory, create a directory called `toolchains` and insert them into that directory.

If you run the command `ls`you should see:

```
arm-trusted-firmware
buildroot
optee_os
toolchains
```

Where inside the toolchains you have the `aarch64`folder with the toolchain.

Next, copy the [Makefile](https://github.com/joaopeixoto13/OPTEE-RPI4/blob/main/Makefile) into your working directory and run the command:

```
make
```

This Makefile is responsible to not only to compile the ARM Trusted Firmware and the Trusted OS, but also to **concatenate this two binaries into one binary to be loaded in the memory**.

---

# Setup the Raspberry Pi 4

### Configure the config.txt file

The Raspberry Pi uses a configuration file instead of the BIOS you would expect to find on a conventional PC. The system configuration parameters, which would traditionally be edited and stored using a BIOS, are stored instead in an optional text file named **config.txt**. For more information, please see [here](https://www.raspberrypi.com/documentation/computers/config_txt.html).

First, copy the [config.txt](https://github.com/joaopeixoto13/OPTEE-RPI4/blob/main/config.txt) file and past them into the working directory.

In a nutshell, after enable the UART and configure the system as 64-bit, the parameter `armstub` is configure as **bl31-bl32.bin**, which is exactly the output binary generated by the compilation of the ARM Trusted Firmware and the Trusted OS.

This parameter has extremely importance because the corresponding file will be loaded at address **0x00** and execute it in **EL3**. For that reason, and as the **BL32 is already attached with the BL31** itself, the **system will be able to load the Secure Payload, which is located the Trusted OS Kernel**.

The image below ilustrates the Secure Boot sequence:

![alt text](https://github.com/joaopeixoto13/OPTEE-RPI4/blob/main/Images/SecureBoot.png)

Therefore, the kernel image is defined and the device tree address is specified. 

Finnaly, the Initial RAM File System `initramfs` is defined and placed in the end of the device tree. This parameter is responsible to mount the Normal World (Rich OS) root filesystem.

### Setup the SD Card

Insert the SD Card and type:

```
sudo dd if=output/images/sdcard.img of=/dev/mmcblk0 
```

**Note**: This command is responsible to copy the image file generated to our slot SD card (with the ID of `mmcblk0`). However, the ID can change, and the command has the folling characteristics:
- `if` means `input file`, and refers where the image file is stored
- `of` means `output file`, and referes where the image will be copy

In this specific case, after the copy process, remove the SD card from the computer and put into the Raspberry Pi 4.

### Ethernet Configuration

In yours PC, go to:
```
Settings ==> Network ==> Wired (Ethernet Connectiopn) ==> IPv4
(And disable "automatic (dhcp)" and select "share to other computers")
```

```
Remove the Ethernet and connect again
```

To visualize the assigned DHCP IPs, type:
```
arp -a
```

**Note**: In this case, we assume that Raspberry IP is `10.42.0.94`

Open one terminal (T1) (CTRL+ALT+T) and type:
```
ssh root@10.42.0.94 (Connect via SSH the host (our computer) to Raspberry (our client))
```

Open one second terminal (T2) (CTRL+ALT+T), navigate to your Client Application and Trusted Application directory and type:
```
scp client_aplication.rs root@10.42.0.94:/etc
scp trusted_aplication_uuid.ta root@10.42.0.94:/etc
```

**Note**: The *.rs* means a Rust file and the trusted_aplication_uuid means the *UUID* and are used as example.  

Open the first terminal (T1) and type:
```
cd /lib/
mkdir optee_armtz
cp /etc/trusted_aplication_uuid.ta optee_armtz
```

This will create the ARM Trustzone directory wich the **TEE-Suplicant** will find the Trusted Application.

To visualize if the OPTEE Client library exists, run the following command:

```
find -name "optee_client.so"
```

If you were successful, you are ready to execute your application, by typing:
```
cd /etc
./client_aplication.rs
```

![Result](https://github.com/joaopeixoto13/OPTEE-RPI4/blob/main/Images/Result.png)

### Serial Port Configuration (UART)

First, to get serial console for our board, we need to install some serial terminal program:

```
sudo apt install -y picocom
```

In order to get to work, we must add the permission to the dialog user, even using with sudo:

```
sudo usermod -a -G dialout $USER
```

Check if the dialout is on the user group:

```
groups $USER
```

Add the baudrate and the local where the board is connected on our computer:

```
picocom -b 115200 /dev/tty/ACM0
```

**Note**: If you **haven't the correct output messages**, please `Reset` the board with the associated button.

If everything works, we must have one `buildroot login prompt` and you can see all the **Boot** messages.
