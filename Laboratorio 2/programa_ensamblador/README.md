# Programa ensamblador RISC-V

Programa principal en ensamblador RV32I para el microcontrolador del Laboratorio 2.

## Descripción

El programa corre indefinidamente en el microcontrolador y realiza lo siguiente:

1. Inicializa los LEDs en 0xAAAA para indicar que el sistema está listo
2. Espera recibir una expresión por UART con el formato: `número + número` o `número - número`
3. Hace eco de cada carácter recibido
4. Al recibir Enter calcula el resultado y lo envía por UART

## Archivos

- `programa.S` — código fuente en ensamblador RV32I
- `programa.coe` — programa compilado para cargar en la ROM de Vivado
- `programa.hex` — programa en formato hex
- `link.ld` — linker script, define que el programa arranca en 0x0000
- `Makefile` — automatiza la compilación
- `hex2coe.py` — convierte programa.hex a programa.coe

## Compilar

```bash
make
```

## Mapa de memoria usado

| Dirección | Periférico |
|-----------|------------|
| 0x02004   | LEDs |
| 0x02010   | UART control |
| 0x02018   | UART TX |
| 0x0201C   | UART RX |

## Herramientas

- Toolchain: `riscv64-unknown-elf-gcc` versión 15.2.0
- Arquitectura: RV32I (sin extensiones M, F ni C)
