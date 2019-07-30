TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

[bits 32]
section .data
    put_int_buffer dq 0

section .text
    global put_str
    global put_char
    global put_int

    put_int:
        pushad
        mov ebp, esp
        mov eax, [ebp+4*9]
        mov edx, eax
        mov edi, 7
        mov ecx, 8
        mov ebx, put_int_buffer
        .16based_4bits:
            and edx, 0x0000000f
            cmp edx, 9
            jg .is_A2F
            add edx, '0'
            jmp .store
            .is_A2F:
                sub edx, 10
                add edx, 'A'
            .store:
                mov [ebx+edi], dl
                dec edi
                shr eax, 4
                mov edx, eax
                loop .16based_4bits
        .ready_to_print:
            inc edi ; make edi become 0
        .skip_prefix_0:
            cmp edi, 8
            je .full0
            .go_on_skip:
                mov cl, [put_int_buffer+edi]
                inc edi
                cmp cl, '0'
                je .skip_prefix_0
                dec edi
                jmp .put_each_num
        .full0:
            mov cl, '0'
        .put_each_num:
            push ecx
            call put_char
            add esp, 4
            inc edi
            mov cl, [put_int_buffer+edi]
            cmp edi, 8
            jl .put_each_num
            popad
            ret

    put_str:
        push ebx
        push ecx
        xor ecx, ecx ; store parameter using ecx.
        mov ebx, [esp + 12] ; get string start position.
        .goon:
            mov cl, [ebx]
            cmp cl, 0 ; if cur char is '\0'
            jz .str_over
            push ecx
            call put_char
            add esp, 4
            inc ebx
            jmp .goon
        .str_over:
            pop ecx
            pop ebx
            ret

    put_char:
        pushad ;Backup env(push all double).
        mov ax, SELECTOR_VIDEO
        mov gs, ax
        ;get cursor posion high 8 bits using vga ctr.
        mov dx, 0x03d4
        mov al, 0x0e
        out dx, al
        mov dx, 0x3d5
        in al, dx
        mov ah, al
        ;get cursor posion low 8 bits using vga ctr.
        mov dx, 0x03d4
        mov al, 0x0f
        out dx, al
        mov dx, 0x3d5
        in al, dx
        ;get char and handle it.
        mov bx, ax
        mov ecx, [esp + 36] ;pushad store 32bytes caller store ret address 4bytes.
        cmp cl, 0xd
        jz .is_carriage_return
        cmp cl, 0xa
        jz .is_newline
        cmp cl, 0x8
        jz .is_backspace
        jmp .put_other

        .is_backspace:
            dec bx
            shl bx, 1
            mov byte [gs:bx], 0x20
            inc bx
            mov byte [gs:bx], 0x07
            shr bx, 1
            jmp .set_cursor

        .put_other:
            shl bx, 1
            mov byte [gs:bx], cl
            inc bx
            mov byte [gs:bx], 0x07
            shr bx, 1
            inc bx
            cmp bx, 2000
            jl .set_cursor

        .is_newline:
        .is_carriage_return:
            xor dx, dx
            mov ax, bx
            mov si, 80
            div si

            sub bx, dx

        .is_carriage_return_end:
            add bx, 80
            cmp bx, 2000
        .is_newline_end:
            jl .set_cursor

        .roll_screen: ; mov line 1~24 to 0~23 and fill line 24 with blank.
            cld
            mov ecx, 960 ; (2000-80)*2 / 4 = 960
            mov esi, 0xc00b80a0
            mov edi, 0xc00b8000
            rep movsd

            mov ebx, 3840 ;1920*2 line24 first char
            mov ecx, 80
            .cls:
                mov word [gs:ebx], 0x0720
                add ebx, 2
                loop .cls
                mov bx, 1920 ;reset cursor position.

        .set_cursor:
            ;set address high 8 bits to vga ctr reg.
            mov dx, 0x03d4
            mov al, 0x0e
            out dx, al
            mov dx, 0x03d5
            mov al, bh
            out dx, al
            ;set address low 8 bits to vga ctr reg.
            mov dx, 0x03d4
            mov al, 0x0f
            out dx, al
            mov dx, 0x03d5
            mov al, bl
            out dx, al
            .put_char_done:
                popad
                ret
