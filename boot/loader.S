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

        ;Create PDE and PTE.
        mov ecx, 4096; 4K
        mov esi, 0
        setup_page:
            .clear_page_dir:; clear the page dir table
                mov byte [PAGE_DIR_TABLE_POS+esi], 0
                inc esi
                loop .clear_page_dir

            .create_pde:; Create page dir table
                mov eax, PAGE_DIR_TABLE_POS
                add eax, 0x1000 ;Now eax is the first page pos.
                mov ebx, eax
                or eax, PG_US_U | PG_RW_R | PG_P ;user process pde attribute initialize
                mov [PAGE_DIR_TABLE_POS + 0x0], eax
                mov [PAGE_DIR_TABLE_POS + 768*4], eax
                sub eax, 0x1000
                mov [PAGE_DIR_TABLE_POS + 1024*4 - 4], eax ; Last pde is pdt itself.

            mov ecx, 256 ; 1MB / 4kb = 256(Kernel store on first 1MB memory address)
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
        jmp $
