# Firmware RISC-V para ADXL362 en Nexys4 DDR

Esta carpeta contiene el firmware desarrollado para leer el acelerómetro **ADXL362** integrado en la tarjeta **Nexys4 DDR**, utilizando un procesador **RISC-V RV32I** implementado en FPGA.

El programa inicializa la comunicación **SPI**, configura el acelerómetro, lee continuamente los ejes **X**, **Y** y **Z**, almacena los datos en RAM y los transmite por **UART** para su uso en una computadora o aplicación externa.

## Archivos incluidos

| Archivo        | Descripción                                            |
| -------------- | ------------------------------------------------------ |
| `programa.S`   | Código fuente en ensamblador RISC-V.                   |
| `programa.coe` | Archivo para inicializar la ROM en Vivado.             |
| `Makefile`     | Automatiza la compilación del firmware.                |
| `link.ld`      | Script de enlace del programa.                         |
| `hex2coe.py`   | Convierte el archivo `.hex` generado a formato `.coe`. |

## Funcionamiento general

El firmware realiza las siguientes acciones:

1. Inicializa las direcciones base de UART, SPI y RAM.
2. Enciende los LEDs con `0xAAAA` como indicador de arranque.
3. Inicializa el acelerómetro ADXL362.
4. Lee los registros correspondientes a los ejes X, Y y Z.
5. Guarda los valores leídos en RAM.
6. Envía los datos por UART con el formato:

```text
X=...,Y=...,Z=...
```

## Mapa de memoria

| Elemento  | Dirección |
| --------- | --------: |
| LEDs      | `0x02004` |
| UART_CTRL | `0x02010` |
| UART_TX   | `0x02018` |
| SPI_CTRL  | `0x02020` |
| SPI_TX    | `0x02028` |
| SPI_DATA  | `0x0202C` |
| RAM X     | `0x40000` |
| RAM Y     | `0x40004` |
| RAM Z     | `0x40008` |

## Compilación

Para regenerar el archivo `.coe`:

```bash
make clean
make
```

El flujo de generación es:

```text
programa.S -> programa.elf -> programa.hex -> programa.coe
```


## Salida esperada

El programa envía por UART un mensaje inicial y luego los valores de aceleración:

```text
ADXL
ID=...
X=...,Y=...,Z=...
X=...,Y=...,Z=...
```

Los valores dependen de la orientación física de la tarjeta.

