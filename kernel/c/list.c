#include "list.h"
#include "interrupt.h"
#include "stdint.h"

void list_init(struct list* list) {
    list->head.prev = NULL;
    list->tail.next = NULL;
    list->head.next = &list->tail;
    list->tail.prev = &list->head;
}
void list_insert_before(struct list_elem* before, struct list_elem* elem){
    intr_status old_status = intr_disable(); // disable interrupt.
    before->prev->next = elem;
    elem->prev = before->prev;
    elem->next = before;
    before->prev = elem;
    intr_set_status(old_status);
}
void list_push(struct list* plist, struct list_elem* elem) {
    list_insert_before(plist->head.next, elem);
}

void list_append(struct list* plist, struct list_elem* elem) {
    list_insert_before(&plist->tail, elem);
}

void list_remove(struct list_elem* elem) {
    intr_status old_status = intr_disable();
    elem->prev->next = elem->next;
    elem->next->prev = elem->prev;
    intr_set_status(old_status);
}

struct list_elem* list_pop(struct list* plist) {
    struct list_elem* elem = plist->head.next;
    list_remove(elem);
    return elem;
}

int list_empty(struct list* plist) {
    return (int)(plist->head.next == &plist->tail);
}

uint32_t list_len(struct list* plist) {
    struct list_elem* elem = plist->head.next;
    uint32_t length = 0;
    while(elem != &plist->tail) {
        length++;
        elem = elem->next;
    }
    return length;
}

struct list_elem* list_traversal(struct list* plist, function func, int arg) {
    struct list_elem* elem = plist->head.next;
    if(list_empty(plist)) return NULL;
    while(elem != &plist->tail) {
        if(func(elem, arg)) return elem;
        elem = elem->next;
    }
    return NULL;
}

int elem_find(struct list* plist, struct list_elem* obj_elem) {
    struct list_elem* elem = plist->head.next;
    while(elem != &plist->tail) {
        if(elem == obj_elem) return 1;
        elem = elem->next;
    }
    return 0;
}
