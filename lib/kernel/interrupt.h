#ifndef __LIB_KERNEL_INTERRUPT_H
#define __LIB_KERNEL_INTERRUPT_H

typedef void* intr_hadnler;
void idt_init();

typedef enum {
    INTR_OFF,
    INTR_ON
} intr_status;

intr_status intr_get_status();
intr_status intr_set_status(intr_status status);
intr_status intr_enable();
intr_status intr_disable();

#endif
