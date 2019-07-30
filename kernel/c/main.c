#include "print.h"
#include "init.h"

int main() {
    put_str("Kernel Start.\n");
    init_all();
    asm volatile("sti");
    while(1);
}
