CC = gcc
C_INCLUDE_GLOBAL = ../../lib
C_INCLUDE_KERNEL = ../../lib/kernel
C_FLAGS = -I $(C_INCLUDE_GLOBAL) -I $(C_INCLUDE_KERNEL) -c -m32 -fno-builtin -fno-stack-protector

OBJS = interrupt.o init.o main.o

all:$(OBJS)

%.o: %.c
	$(CC) $(C_FLAGS) -o ../../build/$@ $<
