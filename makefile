all: mbr.bin loader.bin kernel.bin

mbr.bin:
	nasm -I boot/include/ -o boot/mbr.bin boot/mbr.S

loader.bin:
	nasm -I boot/include/ -o boot/loader.bin boot/loader.S

kernel.bin: kernel.o print.o
	ld -m elf_i386 -Ttext 0xc0001500 -e main -o kernel/kernel.bin kernel/kernel.o lib/kernel/print.o

kernel.o:
	gcc -I lib/kernel/ -c -m32 -o kernel/kernel.o kernel/main.c

print.o:
	nasm -f elf -o lib/kernel/print.o lib/kernel/print.S

clean:
	rm -f boot/*.bin kernel/*.bin kernel/*.o
