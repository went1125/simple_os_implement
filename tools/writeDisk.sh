dd if=boot/mbr.bin of=hd60M.img bs=512 count=1 conv=notrunc
dd if=boot/loader.bin of=hd60M.img bs=512 count=4 seek=2 conv=notrunc
dd if=kernel/kernel.bin of=hd60M.img bs=512 count=200 seek=9 conv=notrunc
