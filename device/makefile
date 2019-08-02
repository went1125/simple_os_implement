CC = gcc
C_INCLUDE_DEVICE = ../lib/device
C_FLAGS = -I $(C_INCLUDE_DEVICE) -c -m32 -fno-builtin -fno-stack-protector

OBJS = timer.o

all:$(OBJS)

%.o: %.c
	$(CC) $(C_FLAGS) -o ../build/$@ $<
