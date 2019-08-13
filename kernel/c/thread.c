#include "thread.h"
#include "stdint.h"
#include "string.h"
#include "global.h"
#include "memory.h"
#include "debug.h"
#include "interrupt.h"
#include "print.h"

#define PG_SIZE 4096

struct task_struct* main_thread; // main thread PCB.
struct list thread_ready_list; //ready queue tag
struct list thread_all_list; // all thread quere tag
static struct list_elem* thread_tag;

extern void switch_to(struct task_struct* cur, struct task_struct* next);

struct task_struct* running_thread() {
    uint32_t esp;
    asm("mov %%esp, %0": "=g"(esp));
    return (struct task_struct*)(esp & 0xfffff000);
}

static void kernel_thead(thread_func* function, void* func_arg) {
    intr_enable();
    function(func_arg);
}

void thread_create(struct task_struct* pthread, thread_func function, void* func_arg) {
    pthread->self_kstack -= (sizeof(struct intr_stack) + sizeof(struct thread_stack));

    struct thread_stack* kthread_stack = (struct thread_stack*)pthread->self_kstack;
    kthread_stack->eip = kernel_thead;
    kthread_stack->function = function;
    kthread_stack->func_arg = func_arg;
    kthread_stack->ebp = kthread_stack->ebx = kthread_stack->esi = kthread_stack->edi = 0;
}

void init_thread(struct task_struct* pthread, char* name, int prio) {
    memset(pthread, 0, sizeof(*pthread));
    strcpy(pthread->name, name);

    if(pthread == main_thread) {
        pthread->status = TASK_RUNNING;
    }
    else {
        pthread->status = TASK_READY;
    }

    pthread->status = TASK_RUNNING;
    pthread->priority = prio;
    pthread->self_kstack = (uint32_t*)((uint32_t)pthread + PG_SIZE);
    pthread->ticks = prio;
    pthread->elapsed_ticks = 0;
    pthread->pgdir = NULL;
    pthread->stack_magic = 0x19870916;
}

struct task_struct* thread_start(char* name, int prio, thread_func function, void* func_arg) {
    struct task_struct* thread = get_kernel_pages(1);

    init_thread(thread, name, prio);
    thread_create(thread, function, func_arg);

    ASSERT(!elem_find(&thread_ready_list, &thread->general_tag));
    list_append(&thread_ready_list, &thread->general_tag);

    ASSERT(!elem_find(&thread_all_list, &thread->all_list_tag));
    list_append(&thread_all_list, &thread->all_list_tag);

    /*asm volatile("movl %0, %%esp; pop %% ebp; pop %%ebx; pop %%edi; pop %%esi; \
                    ret": : "g"(thread->self_kstack) : "memory");*/
    return thread;
}

static void make_main_thread(void) {
    main_thread = running_thread();
    init_thread(main_thread, "main", 31);

    ASSERT(!elem_find(&thread_all_list, &main_thread->all_list_tag));
    list_append(&thread_all_list, &main_thread->all_list_tag);
}

void schedule() {
    ASSERT(intr_get_status() == INTR_OFF);

    struct task_struct* cur = running_thread();
    if(cur->status == TASK_RUNNING) {
        ASSERT(!elem_find(&thread_ready_list, &cur->general_tag));
        cur->ticks = cur->priority;
        list_append(&thread_ready_list, &cur->general_tag);
        cur->status = TASK_READY;
    }
    else {

    }
    ASSERT(!list_empty(&thread_ready_list));
    thread_tag = NULL;
    thread_tag = list_pop(&thread_ready_list);
    struct task_struct* next = elem2entry(struct task_struct, general_tag, thread_tag);
    next->status = TASK_RUNNING;
    switch_to(cur, next);
}

void thread_init() {
    put_str("thread_init start\n");
    list_init(&thread_ready_list);
    list_init(&thread_all_list);
    make_main_thread();
    put_str("thread_init done\n");
}
