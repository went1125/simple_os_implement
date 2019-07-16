all: mbr.bin loader.bin

mbr.bin:
	nasm -I include/ -o mbr.bin mbr.S

loader.bin:
	nasm -I include/ -o loader.bin loader.S

clean:
	rm -f *.bin
