#ifndef __KERNEL_SYNC_H
#define __KERNEL_SYNC_H
#include "stdint.h"
#include "thread.h"

struct semaphore {
    uint8_t value;
    struct list waiters;
};

struct lock {
    struct task_struct* holder;
    struct semaphore semaphore;
    uint32_t holder_repeat_nr;
};

void lock_init(struct lock* plock);
void lock_acquire(struct lock* plock);
void lock_release(struct lock* plock);

#endif
