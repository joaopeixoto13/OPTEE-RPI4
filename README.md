# Description

The Raspberry Pi 4 is an inexpensive single-board computer that contains four Arm Cortex-A72 cores. However, at the current time (April 7, 2023), this plataform does not support the Trusted OS capable of running *secure* services in a TEE enclosure. Note that this port will not became the system secure, because in Raspberry PI boards, all of the memory used is DRAM, which is available from both the Non-Secure and Secure State. To make the system safe, both in terms of the CPU and in terms of memory and peripherals, a **Hypervisor** must be used to overcome the defects inherent in the board itself, which have already been mentioned.

However, this port will show all the steps, from the generation of the **Rich Operating System**, to the compilation of the **ARM TRusted Firmware** and the **Trusted OS** to run OPTEE on the board.

---

## Generate the Rich Operating System

First, it is necessary to generate the unsecured, or rich, operating system in order to run the Client Application. 

For this, [Buildroot](https://buildroot.org/) was used, which is nothing more than a simple and easy to use tool to generate embedded Linux systems through cross-compilation.
