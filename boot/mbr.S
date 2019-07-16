%include "boot.inc"

SECTION MBR vstart=0x7c00
    ; initialize sreg by cs.
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00
    mov ax, 0xb800
    mov gs, ax

    ;Using INT 0x10 no.6 clear the screen.
    mov ax, 0x600
    mov bx, 0x700
    mov cx, 0
    mov dx, 0x184f
    int 0x10

    ;Using 0xb8000(gs) memory to map gpu.
    mov byte [gs:0x00], '1'
    mov byte [gs:0x01], 0xA4

    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0xA4

    mov byte [gs:0x04], 'M'
    mov byte [gs:0x05], 0xA4

    mov byte [gs:0x06], 'B'
    mov byte [gs:0x07], 0xA4

    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xA4

    mov eax, LOADER_START_SECTOR ;LBA Sector address.
    mov bx, LOADER_BASE_ADDR ;Address to be writed.
    mov cx, 4 ; Sector account.
    call rd_disk_m16 ;Start writing.

    jmp LOADER_BASE_ADDR

    rd_disk_m16:
        ;back up data
        mov esi, eax
        mov di, cx

        ;Step1. Setting sector account to disk I/O register.
        mov dx, 0x1f2
        mov al, cl
        out dx, al
        mov eax, esi

        ;Step2. Setting LBA address to disk I/O register.
        ;LBA address 7~0 bits setting.
        mov dx, 0x1f3
        out dx, al
        ;LBA address 15~8 bits setting.
        mov cl, 8
        shr eax, cl
        mov dx, 0x1f4
        out dx, al
        ;LBA address 23~16 bits setting.
        shr eax, cl
        mov dx, 0x1f5
        out dx, al
        ;LBA address 24~27 bits setting and LBA mode setting(device register).
        shr eax, cl
        and al, 0x0f
        or al, 0xe0
        mov dx, 0x1f6
        out dx, al

        ;Step3. Setting command to disk I/O register.
        mov dx, 0x1f7
        mov al, 0x20
        out dx, al

        ;Step4. Check disk status
        .not_ready:
            nop ;delay
            in al, dx
            and al, 0x88
            cmp al, 0x08
            jnz .not_ready

        ;Step5. Reading data from disk I/O register.
        mov ax, di
        mov dx, 256
        mul dx
        mov cx, ax
        mov dx, 0x1f0
        .go_on_read:
            in ax, dx
            mov [bx], ax
            add bx, 2
            loop .go_on_read
            ret

    times 510-($-$$) db 0
    db 0x55, 0xaa
