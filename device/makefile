CC = gcc
C_INCLUDE_DEVICE = ../lib/device
C_INCLUDE_KERNEL = ../lib/kernel
C_INCLUDE_GLOBAL = ../lib

C_FLAGS = -I $(C_INCLUDE_DEVICE) -I $(C_INCLUDE_KERNEL) -I $(C_INCLUDE_GLOBAL) -c -m32 -fno-builtin -fno-stack-protector

OBJS = timer.o console.o keyboard.o

all:$(OBJS)

%.o: %.c
	$(CC) $(C_FLAGS) -o ../build/$@ $<
