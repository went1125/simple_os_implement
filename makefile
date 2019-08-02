MAKE = make all
SUB_DIRS = ./kernel/asm ./kernel/c

MBR_IMG = mbr.bin
LOADER = loader.bin
KERNEL_IMG = kernel.bin

KERNEL_ENTRY_ADDRESS = 0xc0001500
KERNEL_ENTRY_SECTION = main

LD = ld
LD_FLAGS = -m elf_i386 -Ttext $(KERNEL_ENTRY_ADDRESS) -e $(KERNEL_ENTRY_SECTION)
LINK_OBJS = ./build/main.o ./build/print.o ./build/kernel.o ./build/interrupt.o ./build/init.o ./build/timer.o

NASM = nasm

all: $(SUB_DIRS) $(KERNEL_IMG) $(MBR_IMG) $(LOADER)

$(SUB_DIRS):
	$(MAKE) -C $@

$(KERNEL_IMG):
	$(LD) $(LD_FLAGS) -o ./build/$@ $(LINK_OBJS)

$(MBR_IMG):
	$(NASM) -I boot/include/ -o boot/$(MBR_IMG) boot/mbr.S

$(LOADER):
	$(NASM) -I boot/include/ -o boot/$(LOADER) boot/loader.S

.PHONY: $(SUB_DIRS) clean

clean:
	rm -f ./build/*.o ./build/*.bin ./boot/*.bin ./boot/*.o
