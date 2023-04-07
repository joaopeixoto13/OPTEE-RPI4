# Description

The Raspberry Pi 4 is an inexpensive single-board computer that contains four Arm Cortex-A72 cores. However, at the current time (April 7, 2023), this plataform does not support the Trusted OS capable of running *secure* services in a TEE enclosure. Note that this port will not became the system secure, because in Raspberry PI boards, all of the memory used is DRAM, which is available from both the Non-Secure and Secure State. To make the system safe, both in terms of the CPU and in terms of memory and peripherals, a **Hypervisor** must be used to overcome the defects inherent in the board itself, which have already been mentioned.

However, this port will show all the steps, from the generation of the **Rich Operating System**, to the compilation of the **ARM TRusted Firmware** and the **Trusted OS** to run [OPTEE](https://www.op-tee.org/) on the board.

---

# Generate the Rich Operating System

First, it is necessary to generate the unsecured, or rich, operating system in order to run the Client Application. 

For this, [Buildroot](https://buildroot.org/) was used, which is nothing more than a simple and easy to use tool to generate embedded Linux systems through cross-compilation.

Open a console and write:

```
mkdir OPTEE-RPI4
cd OPTEE-RPI4/
```
Check the [BuildRoot User Manual](https://buildroot.org/downloads/manual/manual.html), in order to veriufy if all mandatoy packages are installed. 
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

The default configuration should be good enough, but we gonna change some configurations:

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

(*This step can take about ~1h to be completed on a laptop with an INtel i7-9750H processor*)

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
(Change "**TTY port**" to "**ttyAMA0**" and **baudrate to 115200**) (Change the serial port and baudrate)
```

**Note**: The `Trusted Execution Environment support` provides all the drivers to establish the communication between the Secure and NOn-SEcure World (more known as *Secure Monitor*). This driver will be built as module (*optee.ko*) by default and included in rootfs.

---

# Generate the ARM Trusted Firmware

In this case, although ARM offers the [Firmware](https://github.com/ARM-software/arm-trusted-firmware) support to Raspberry Pi 4 platform, 

First, we need to fork (or download) the existing ARM Trusted Firmware from the offcial ARM Github website:

```
cd OPTEE-RPI4
git clone git@github.com:ARM-software/arm-trusted-firmware.git

cd /arm-trusted-firmware/plat/rpi/rpi4
```

Next, 
