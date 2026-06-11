# Laboratorio 3 – Acelerómetro SPI sobre RISC-V en FPGA

## Descripción

Extensión del sistema empotrado del Lab 2: se integra un acelerómetro ADXL362 al procesador PicoRV32 (RV32I) corriendo sobre la FPGA Nexys 4 DDR. La comunicación con el acelerómetro se realiza mediante un periférico SPI diseñado en SystemVerilog, controlado por firmware escrito enteramente en ensamblador RISC-V. Los datos de los ejes X/Y/Z se transmiten por UART hacia un sintetizador en Python que genera audio con pitch bend en tiempo real según la inclinación de la tarjeta.

## Funcionamiento

El firmware inicializa el ADXL362 vía SPI, entra en modo de medición y lee continuamente los registros de aceleración (XDATA, YDATA, ZDATA). Los valores se envían por UART a una aplicación de teclado virtual (`Teclado.py`) que mapea el movimiento de la FPGA a variaciones de pitch bend en las notas generadas.

## Video de demostración

Enlace al funcionamiento del sistema: (https://youtu.be/VJhffOY8G8k)

## Integrantes

Jose Emanuel VS · Santiago Chavarría A · Andrés Madrigal C · Thomas Reed V
