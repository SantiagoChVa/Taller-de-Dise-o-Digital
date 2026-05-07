tb_core_rom.sv
Se agrega un testbench en SystemVerilog para verificar el funcionamiento del núcleo RISC-V utilizando únicamente la memoria de programa (ROM), sin interacción con memoria de datos ni periféricos.

El testbench incluye:
- Generación de señal de reloj de 100 MHz
- Generación de señal de reset síncrono para inicialización del sistema
- Instanciación del módulo riscv_core_wrapper como unidad bajo prueba (DUT)
- Instanciación de la memoria ROM (rom_programa) cargada desde archivo .coe
- Conexión directa entre el contador de programa (PC) del núcleo y la ROM de instrucciones
- Desactivación del acceso a memoria de datos mediante asignación constante de cero en data_in
- Ejecución controlada de la simulación durante un intervalo de tiempo definido
- Monitoreo continuo del valor del contador de programa (PC) y de la instrucción leída desde ROM
- Visualización del flujo de ejecución del programa mediante mensajes de depuración con $display
- Finalización automática de la simulación tras completar el tiempo de ejecución establecido
