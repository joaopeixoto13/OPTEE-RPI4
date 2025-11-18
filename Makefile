# Define the paths
OPTEE_RPI4_DIR := ${PWD}# Adjust this path as necessary to point to your OPTEE-RPI4 directory
TFA_DIR := ${OPTEE_RPI4_DIR}/arm-trusted-firmware
RPI4_TFA_DIR := ${TFA_DIR}/plat/rpi/rpi4
OPTEE_OS_DIR := ${OPTEE_RPI4_DIR}/optee_os
TOOLCHAIN_DIR := ${OPTEE_RPI4_DIR}/toolchains/aarch64/bin

.PHONY: all clean

all: 	
	# Compile the ARM Trusted Firmware
	@echo "Compiling the ARM Trusted Firmware"
	make -C ${TFA_DIR} \
	  CROSS_COMPILE=${TOOLCHAIN_DIR}/aarch64-none-linux-gnu- \
	  PLAT=rpi4 \
	  SPD=opteed \
	  DEBUG=1

	# Compile the Trusted OS
	@echo "Compiling the Trusted OS"

	make -C ${OPTEE_OS_DIR} \
	  CROSS_COMPILE=${TOOLCHAIN_DIR}/aarch64-none-linux-gnu- \
	  PLATFORM=rpi4 \
	  CFG_ARM64_core=y \
	  CFG_USER_TA_TARGETS=ta_arm64 \
	  CFG_DT=y

	# Change to the ARM Trusted Firmware directory to access the 'bl31.bin'
	mkdir -p ${RPI4_TFA_DIR}/build

	# Copy the binary
	cp ${TFA_DIR}/build/rpi4/debug/bl31.bin ${OPTEE_RPI4_DIR}/bl31-pad.tmp

	# Truncate the binary to 128k bytes
	truncate --size=128K ${OPTEE_RPI4_DIR}/bl31-pad.tmp

	# Concatenate the bl31 with the bl32 (or tee-pager_v2)
	cat ${OPTEE_RPI4_DIR}/bl31-pad.tmp ${OPTEE_OS_DIR}/out/arm-plat-rpi4/core/tee-pager_v2.bin > ${OPTEE_RPI4_DIR}/bl31-bl32.bin
	rm ${OPTEE_RPI4_DIR}/bl31-pad.tmp
	@echo "Success"
	
clean:
	# Clean the ARM Trusted Firmware
	@echo "Cleaning the ARM Trusted Firmware"
	make -C ${TFA_DIR} clean
	
	# Clean the Trusted OS
	@echo "Cleaning the Trusted OS"
	make -C ${OPTEE_OS_DIR} clean
	
	@echo "Success"