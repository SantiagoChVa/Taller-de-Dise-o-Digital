# Configuración
CROSS = riscv64-unknown-elf
ARCH = rv32i
ABI = ilp32

# Archivos
SRC = programa.S
ELF = programa.elf
HEX = programa.hex
COE = programa.coe

# Compilar
all: $(COE)

$(ELF): $(SRC) link.ld
	$(CROSS)-gcc -march=$(ARCH) -mabi=$(ABI) -nostdlib -T link.ld $(SRC) -o $(ELF)

$(HEX): $(ELF)
	$(CROSS)-objcopy -O verilog $(ELF) $(HEX)

$(COE): $(HEX)
	python3 hex2coe.py

# Limpiar archivos generados
clean:
	rm -f $(ELF) $(HEX) $(COE)

# Ver instrucciones generadas
dump:
	$(CROSS)-objdump -d $(ELF)
