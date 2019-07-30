NASM = nasm
NASM_FLAGS = -f elf

OBJS = print.o kernel.o

all: $(OBJS)

%.o: %.S
	$(NASM) $(NASM_FLAGS) -o ../../build/$@ $<
