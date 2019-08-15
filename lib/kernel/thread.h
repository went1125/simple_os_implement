#ifndef __KERNEL_THREAD_H
#define __KERNEL_THREAD_H
#include "stdint.h"
#include "list.h"

typedef void thread_func(void*);

typedef enum {
    TASK_RUNNING,
    TASK_READY,
    TASK_BLOCKED,
    TASK_WAITING,
    TASK_HANGING,
    TASK_DIED
}task_status;

struct intr_stack {
    uint32_t vec_no; //Map to kernel.S Marco VECTOR push %1 intr number.
    uint32_t edi;
    uint32_t esi;
    uint32_t ebp;
    uint32_t esp_dummy;
    uint32_t ebx;
    uint32_t edx;
    uint32_t ecx;
    uint32_t eax;
    uint32_t gs;
    uint32_t fs;
    uint32_t es;
    uint32_t ds;

    /* Low to hight level stack*/
    uint32_t err_code;
    void (*eip) (void);
    uint32_t cs;
    uint32_t eflags;
    void* esp;
    uint32_t ss;
};

struct thread_stack {
    uint32_t ebp;
    uint32_t ebx;
    uint32_t edi;
    uint32_t esi;

    void (*eip) (thread_func* func, void* func_arg);
    void (*unused_retaddr);

    thread_func* function;
    void* func_arg;
};

//PCB
struct task_struct {
    uint32_t* self_kstack;
    task_status status;
    uint8_t priority;
    uint8_t ticks;
    char name[16];
    uint32_t elapsed_ticks;
    struct list_elem general_tag;
    struct list_elem all_list_tag;
    uint32_t* pgdir;
    uint32_t stack_magic; //Stack boundary.
};

struct task_struct* thread_start(char* name, int prio, thread_func function, void* func_arg);
void schedule();
void thread_init();
void thread_block(task_status stat);
void thread_unblock(struct task_struct* pthread);
struct task_struct* running_thread();

#endif
