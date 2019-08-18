#include "interrupt.h"
#include "stdint.h"
#include "global.h"
#include "print.h"
#include "io.h"

#define PIC_M_CTRL 0x20
#define PIC_M_DATA 0x21
#define PIC_S_CTRL 0xa0
#define PIC_S_DATA 0xa1

#define IDT_DESC_CNT 0x30

#define EFLAGS_IF 0x00000200
#define GET_EFLAGS(EFLAGS_VAR) asm volatile("pushfl; popl %0": "=g"(EFLAGS_VAR))

struct gate_desc {
    uint16_t func_offset_low_word;
    uint16_t selector;
    uint8_t dcount;
    uint8_t attribute;
    uint16_t func_offset_high_word;
};
static struct gate_desc idt[IDT_DESC_CNT];

char* intr_name[IDT_DESC_CNT];
intr_hadnler idt_table[IDT_DESC_CNT];
extern intr_hadnler intr_entry_table[IDT_DESC_CNT];

static void make_idt_desc(struct gate_desc* p_gdesc, uint8_t attr, intr_hadnler function) {
    p_gdesc->func_offset_low_word = (uint32_t)function & 0x0000ffff;
    p_gdesc->selector = SELECTOR_K_CODE;
    p_gdesc->dcount = 0;
    p_gdesc->attribute = attr;
    p_gdesc->func_offset_high_word = ((uint32_t)function & 0xffff0000) >> 16;
}

static void idt_desc_init() {
    int i;
    for(i = 0; i < IDT_DESC_CNT; i++) {
        make_idt_desc(&idt[i], IDT_DESC_ATTR_DPL0, intr_entry_table[i]);
    }
    put_str("idt_desc_init done\n");
}

static void pic_init() {
    //Initial master 8259A
    outb(PIC_M_CTRL, 0x11); //ICW1;Edge trigger and mutichip(need ICW4)
    outb(PIC_M_DATA, 0x20); //ICW2; Interupt No.0x20 to 0x27(IRQ0~7)
    outb(PIC_M_DATA, 0x04); //ICW3; IR2 connect to slave chip
    outb(PIC_M_DATA, 0x01); //ICW4 8086 mode, normal EOI

    //Initial slave 8259A
    outb(PIC_S_CTRL, 0x11); //ICW1;Edge trigger and mutichip(need ICW4)
    outb(PIC_S_DATA, 0x28); //ICW2; Interupt No.0x20 to 0x27(IRQ0~7)
    outb(PIC_S_DATA, 0x02); //ICW3; IR2 connect to slave chip
    outb(PIC_S_DATA, 0x01); //ICW4 8086 mode, normal EOI

    /*Open IR0(timer interrupt)*/
    outb(PIC_M_DATA, 0xfd);
    outb(PIC_S_DATA, 0xff);

    put_str("pic_init done\n");
}

static void general_intr_handler(uint8_t vec_nr) {
    if(vec_nr == 0x27 || vec_nr == 0x2f) return;

    g_set_cursor(0);
    int cursor_pos = 0;
    while(cursor_pos++ < 320) put_char(' ');
    g_set_cursor(0);
    put_str("!!!!!!      exception message begin      !!!!!!\n");
    g_set_cursor(88);
    put_str(intr_name[vec_nr]);
    if(vec_nr == 14) {
        int page_fault_vaddr = 0;
        asm ("movl %%cr2, %0": "=r"(page_fault_vaddr));
        put_str("\npage fault addr is ");put_int(page_fault_vaddr);
    }
    put_str("\n!!!!!!      exception message begin      !!!!!!");
    while(1);
}

void register_handler(uint8_t vector_no, intr_hadnler function) {
    idt_table[vector_no] = function;
}

static void exception_init() {
    int i;
    for(i = 0; i < IDT_DESC_CNT; ++i) {
        idt_table[i] = general_intr_handler;
        intr_name[i] = "unknown";
    }
    intr_name[0] = "#DE Divide Error";
    intr_name[1] = "#DB Debug exception";
    intr_name[2] = "NMI Interupt";
    intr_name[3] = "#BP Breakpoint Exception";
    intr_name[4] = "#OF Overflow Exception";
    intr_name[5] = "#BR Bound Range Exceed exception";
    intr_name[6] = "#UD Invalid OPcode Exception";
    intr_name[7] = "#NM Device Not Available Exception";
    intr_name[8] = "#DF Double Fault Exception";
    intr_name[9] = "Coprocessor Segment Overrun";
    intr_name[10] = "#TS Invalid TSS Exception";
    intr_name[11] = "#NP Segment Not Present";
    intr_name[12] = "#SS Stack Fault Exception";
    intr_name[13] = "#GP General Protection Exception";
    intr_name[14] = "#PF Page-Fault Exception";
//    intr_name[15] = "#DE Divide Error";
    intr_name[16] = "#MF x87 FPU Floating-Point Error";
    intr_name[17] = "#AC Alignment Check Exception";
    intr_name[18] = "#MC Machine-Check Exception";
    intr_name[19] = "#XF SIMD Floating-Point Exception";
}

void idt_init() {
    put_str("idt_init start.\n");
    idt_desc_init();
    exception_init();
    pic_init(); // initial 8259A
    uint64_t idt_operand = (sizeof(idt)-1) | (uint64_t)(((uint32_t)idt << 16));
    asm volatile("lidt %0" : : "m" (idt_operand));
    put_str("idt_init done.\n");
}

// Enable interrupt and get previous status.
intr_status intr_enable() {
    intr_status old_status;
    if(INTR_ON == intr_get_status()) {
        old_status = INTR_ON;
        return old_status;
    }
    else {
        old_status = INTR_OFF;
        asm volatile("sti");
        return old_status;
    }
}
// Disable interrupt and get previous status.
intr_status intr_disable() {
    intr_status old_status;
    if(INTR_ON == intr_get_status()) {
        old_status = INTR_ON;
        asm volatile("cli");
        return old_status;
    }
    else {
        old_status = INTR_OFF;
        return old_status;
    }
}

intr_status intr_set_status(intr_status status) {
    return status & INTR_ON ? intr_enable() : intr_disable();
}

intr_status intr_get_status() {
    uint32_t eflags = 0;
    GET_EFLAGS(eflags);
    return (EFLAGS_IF & eflags) ? INTR_ON : INTR_OFF;
}
