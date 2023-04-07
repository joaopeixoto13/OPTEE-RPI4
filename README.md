# Description

The Raspberry Pi 4 is an inexpensive single-board computer that contains four Arm Cortex-A72 cores. However, at the current time (April 7, 2023), this plataform does not support thge Trusted OS capable of running *secure* services in a TEE enclosure. Note that this port will not became the system secure, because in Raspberry PI boards, all of the memory used is DRAM, which is available from both the Non-Secure and Secure State. 
