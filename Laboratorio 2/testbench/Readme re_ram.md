tb_core_ram.sv
Se agrega un testbench en SystemVerilog para verificar la integración funcional entre el núcleo RISC-V, la memoria de programa (ROM), la memoria de datos (RAM) y el módulo bus_driver.

El testbench incluye:
- Generación de señal de reloj de 100 MHz y reset síncrono del sistema
- Instanciación del módulo riscv_core_wrapper como núcleo de procesamiento (DUT principal)
- Instanciación de la memoria ROM con el programa cargado desde archivo .coe
- Instanciación de la memoria RAM para almacenamiento de datos
- Interconexión del núcleo con la RAM mediante el módulo bus_driver
- Deshabilitación controlada del acceso a periféricos (periph_rdata_i en cero)
- Ejecución temporal controlada de la simulación para permitir la operación del programa
- Monitoreo continuo de señales relevantes del sistema (PC, dirección de datos, señal de escritura, datos de entrada y salida)
- Visualización del comportamiento del sistema en tiempo real mediante mensajes de depuración con $display
- Finalización automática de la simulación tras completar el tiempo de ejecución definido
