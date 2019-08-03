#include "print.h"
#include "init.h"
#include "debug.h"

int main() {
    put_str("Kernel Start.\n");
    init_all();
    ASSERT(1 == 2);
    asm volatile("sti");
    while(1);
}
