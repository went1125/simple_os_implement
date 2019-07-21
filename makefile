all: mbr.bin loader.bin kernel.bin

mbr.bin:
	nasm -I boot/include/ -o boot/mbr.bin boot/mbr.S

loader.bin:
	nasm -I boot/include/ -o boot/loader.bin boot/loader.S

kernel.bin: kernel.o
	ld -m elf_i386 kernel/kernel.o -Ttext 0xc0001500 -e main -o kernel/kernel.bin

kernel.o:
	gcc -c -m32 -o kernel/kernel.o kernel/main.c

clean:
	rm -f boot/*.bin kernel/*.bin kernel/*.o
