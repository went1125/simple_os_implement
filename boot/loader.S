%include "boot.inc"
LOADER_STACK_TOP equ LOADER_BASE_ADDR
SECTION LOADER vstart=LOADER_BASE_ADDR
    jmp loader_start
    ;Setting GDT and Descriptors
    GDT_BASE: dd  0x00000000
              dd  0x00000000

    CODE_DESC: dd  0x0000ffff
               dd  DESC_CODE_HIGH4

    DATA_STACK_DESC: dd  0x0000ffff
                     dd  DESC_DATA_HIGH4

    VIDEO_DESC: dd  0x80000007
                dd  DESC_VIDEO_HIGH4

    GDT_SIZE equ $ - GDT_BASE
    GDT_LIMIT equ GDT_SIZE - 1
    times 60 dq 0

    total_mem_bytes dd 0 ; 0xb00 use to store max memory.
    ;Setting Selectors
    SELECTOR_CODE equ (0x0001 << 3) + TI_GDT + RPL0
    SELECTOR_DATA equ (0x0002 << 3) + TI_GDT + RPL0
    SELECTOR_VIDEO equ (0x0003 << 3) + TI_GDT + RPL0

    ;Setting GDT_PTR
    gdt_ptr dw  GDT_LIMIT
            dd  GDT_BASE

    ards_buf times 244 db 0
    ards_nr dw 0 ; number of ards rows.
    ;Setting message

    loader_start:
        ;Calculate memory size Using bios int0x15 E820h function.
        xor ebx, ebx ;initialize ebx to 0.
        mov edx, 0x534d4150 ;SMAP validation.
        mov di, ards_buf
        .e820_function:
            mov eax, 0x0000e820
            mov ecx, 20
            int 0x15
            jc .e801_function ; if cf bit is set just use e801 function.
            add di, cx
            inc word [ards_nr]
            cmp ebx, 0
            jnz .e820_function
        ;find max(base_add_low + length_low) from ards(max memory size).
        mov cx, [ards_nr]
        mov ebx, ards_buf
        xor edx, edx ;using edx to store the max size, so init to zero first.
        .find_max_mem_area:
            mov eax, [ebx]
            add eax, [ebx+8]
            add ebx, 20
            cmp edx, eax
            jge .next_ards
            mov edx, eax
        .next_ards:
            loop .find_max_mem_area
            jmp .mem_get_ok

        .e801_function:
            mov ax, 0xe801
            int 0x15
            jc .e88_function ;if e88_function fail, jump to e88 function.
            ; Calculate low 15MB memory
            mov cx, 0x400
            mul cx
            shl edx, 16
            and eax, 0x0000ffff
            or edx, eax
            add edx, 0x100000
            mov esi, edx
            ;Calculate above 16MB memory
            xor eax, eax
            mov ax, bx
            mov ecx, 0x10000
            mul ecx
            add esi, eax
            mov edx, esi
            jmp .mem_get_ok

        .e88_function:
            mov ah, 0x88
            int 0x15
        ;    jc .error_hlt
            and eax, 0x0000ffff
            mov cx, 0x400
            mul cx
            shl edx, 16
            or edx, eax
            add edx, 0x100000

        .mem_get_ok:
            mov [total_mem_bytes], edx

        ;Start entering protected mode.
        ;Step1. Open A20
        in al, 0x92
        or al, 0000_0010b
        out 0x92, al
        ;Step2. Load GDT
        lgdt [gdt_ptr]
        ;Step3. Setting cr0 bit0
        mov eax, cr0
        or eax, 0x00000001
        mov cr0, eax

        jmp dword SELECTOR_CODE:p_mode_start

    [bits 32]
    p_mode_start:
        mov ax, SELECTOR_DATA
        mov ds, ax
        mov es, ax
        mov ss, ax
        mov esp, LOADER_STACK_TOP
        mov ax, SELECTOR_VIDEO
        mov gs, ax

        mov byte [gs:160], 'P'

        ;Read kernel to memory.
        mov eax, KERNEL_START_SECTOR
        mov ebx, KERNEL_BIN_BASE_ADDR
        mov ecx, 200
        call rd_disk_m32 ; read kernel.bin(ELF) to memory
        ;Create page and transform to page mode.
        call setup_page
        sgdt [gdt_ptr]
        mov ebx, [gdt_ptr+2]
        or dword [ebx + 0x18 + 4], 0xc0000000
        add dword [gdt_ptr + 2], 0xc0000000
        add esp, 0xc0000000
        ;Store pdt to cr3
        mov eax, PAGE_DIR_TABLE_POS
        mov cr3, eax
        ;Setting page enable bit on cr0
        mov eax, cr0
        or eax, 0x80000000
        mov cr0, eax
        ;reload gdt
        lgdt [gdt_ptr]
        mov byte [gs:160], 'V'
        jmp SELECTOR_CODE:enter_kernel

        enter_kernel:
            call kernel_init
        ;    jmp $
            mov esp, 0xc009f000
            jmp KERNEL_ENTRY_POINT

        rd_disk_m32:
            ;back up data
            mov esi, eax
            mov edi, ecx

            ;Step1. Setting sector account to disk I/O register.
            mov edx, 0x1f2
            mov al, cl
            out dx, al
            mov eax, esi
            ;Step2. Setting LBA address to disk I/O register.
            ;LBA address 7~0 bits setting.
            mov edx, 0x1f3
            out dx, al
            ;LBA address 15~8 bits setting.
            mov cl, 8
            shr eax, cl
            mov edx, 0x1f4
            out dx, al
            ;LBA address 23~16 bits setting.
            shr eax, cl
            mov edx, 0x1f5
            out dx, al
            ;LBA address 24~27 bits setting and LBA mode setting(device register).
            shr eax, cl
            and al, 0x0f
            or al, 0xe0
            mov edx, 0x1f6
            out dx, al
            ;Step3. Setting command to disk I/O register.
            mov edx, 0x1f7
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
            mov eax, edi
            mov edx, 256
            mul edx
            mov ecx, eax
            mov edx, 0x1f0
            .go_on_read:
                in ax, dx
                mov [ebx], eax
                add ebx, 2
                loop .go_on_read
                ret

        setup_page: ;Create PDE and PTE.
            mov ecx, 4096; 4K
            mov esi, 0
            .clear_page_dir:; clear the page dir table
                mov byte [PAGE_DIR_TABLE_POS+esi], 0
                inc esi
                loop .clear_page_dir

            .create_pde:; Create page dir table
                mov eax, PAGE_DIR_TABLE_POS
                add eax, 0x1000 ;Now eax is the first pde pos.
                mov ebx, eax
                or eax, PG_US_U | PG_RW_R | PG_P ;user process pde attribute initialize
                mov [PAGE_DIR_TABLE_POS + 0x0], eax
                mov [PAGE_DIR_TABLE_POS + 768*4], eax
                sub eax, 0x1000
                mov [PAGE_DIR_TABLE_POS + 1023*4], eax ; Last pde is pdt itself.

            mov ecx, 256 ; 1MB / 4kb = 256(Kernel store on first physical 1MB memory address)
            mov esi, 0
            mov edx, PG_US_U | PG_RW_W | PG_P
            .create_pte:
                mov [ebx+esi*4], edx
                add edx, 4096
                inc esi
                loop .create_pte

            mov eax, PAGE_DIR_TABLE_POS
            add eax, 0x2000 ;Second PDE pos
            or eax, PG_US_U | PG_RW_R | PG_P
            mov ebx, PAGE_DIR_TABLE_POS
            mov ecx, 254
            mov esi, 769
            .create_kernel_pde:
                mov [ebx+esi*4], eax
                inc esi
                add eax, 4096
                loop .create_kernel_pde
                ret

        kernel_init: ; Parsing ELF format and read kenel to memory.
            xor eax, eax
            xor ebx, ebx ;store ph address.
            xor ecx, ecx ;store the number of ph
            xor edx, edx ;store ph size.

            mov dx, [KERNEL_BIN_BASE_ADDR + 42] ;mapping to e_phentsize from elf header.

            mov ebx, [KERNEL_BIN_BASE_ADDR + 28] ;mapping to e_phoff from elf header.
            add ebx, KERNEL_BIN_BASE_ADDR ;get the first program header.

            mov cx, [KERNEL_BIN_BASE_ADDR + 44] ;mapping to e_phnum from elf header.
            .each_segment:
                cmp byte [ebx + 0], 0
                je .PTNULL
                push dword [ebx + 16] ;mapping to p_filesize from program header.(Prameter 3 to mem_cpy)
                mov eax, [ebx + 4] ; mapping to p_offset from program header.
                add eax, KERNEL_BIN_BASE_ADDR
                push eax ;Segment physical address(Prameter 2 to mem_cpy)
                push dword [ebx + 8] ;Target address(Prameter 3 to mem_cpy)
                call mem_cpy
                add esp, 12

            .PTNULL:
                add ebx, edx
                loop .each_segment
                ret

            mem_cpy: ;(dst, src, size)
                cld
                push ebp
                mov ebp, esp
                push ecx
                ;Get Parameter.
                mov edi, [ebp + 8]
                mov esi, [ebp + 12]
                mov ecx, [ebp + 16]
                rep movsb
                ; Recovering.
                pop ecx
                pop ebp
                ret
