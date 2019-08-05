#include "print.h"
#include "init.h"
#include "debug.h"
#include "stdint.h"
#include "memory.h"

int main() {
    put_str("Kernel Start.\n");
    init_all();
    void* addr = get_kernel_pages(3);
    put_str("\n get_kernel_pages start vaddr is ");
    put_int((uint32_t)addr);
    put_str("\n");
//    ASSERT(1 == 2);
//    asm volatile("sti");
    while(1);
}
