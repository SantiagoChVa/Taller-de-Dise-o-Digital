README — tb_bus_driver.sv

Descripción
Testbench desarrollado para verificar el funcionamiento del módulo 
bus_driver del sistema RISC-V implementado en FPGA.

El testbench valida la correcta decodificación del mapa de memoria,
la comunicación con la RAM y el acceso a los periféricos simulados,
manteniendo la política de latencia de 1 ciclo utilizada en el sistema.

Funcionamiento
El testbench genera un reloj de simulación y un reset inicial para
probar diferentes operaciones de lectura y escritura.

Se implementa un modelo simplificado de:
- RAM
- periph_hub

El modelo de periféricos responde según la dirección recibida:
- 0x02000 → retorna un valor fijo para switches
- 0x02004 → registro de LEDs

La RAM simulada permite verificar escrituras y lecturas con latencia
de un ciclo, igual que el comportamiento esperado en el hardware real.

Pruebas realizadas
1. Escritura en RAM
   Verifica que el bus pueda escribir correctamente en memoria.

2. Lectura desde RAM
   Comprueba que los datos escritos puedan recuperarse correctamente.

3. Escritura al registro de LEDs
   Verifica que las escrituras dirigidas a periféricos actualicen
   correctamente el registro correspondiente.

4. Lectura del registro de switches
   Comprueba que el módulo retorne correctamente los datos esperados
   desde periféricos.

5. Lecturas consecutivas
   Verifica que no existan ciclos extra de latencia no deseados.

Resultado esperado
Se espera que:
- Las direcciones sean decodificadas correctamente.
- Las señales de escritura se activen únicamente en el destino correcto.
- Los datos leídos desde RAM y periféricos coincidan con los valores esperados.
- La latencia del sistema permanezca en un ciclo.

Archivos relacionados
- bus_driver.sv
- periph_hub.sv
- ram_datos (modelo/IP Core)

Herramientas utilizadas
- SystemVerilog
- Vivado Simulator / XSIM

Frecuencia utilizada
CLK_PERIOD = 10 ns
Frecuencia equivalente = 100 MHz
