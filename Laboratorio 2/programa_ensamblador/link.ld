/* Linker script para programa RV32I */
/* Define el mapa de memoria del programa en la ROM */

SECTIONS {
    . = 0x00000000;          /* El programa arranca en la dirección 0x0000 de la ROM */
    .text : { *(.text*) }    /* Sección de código: instrucciones del programa */
    .data : { *(.data*) }    /* Sección de datos inicializados */
    .bss  : { *(.bss*)  }    /* Sección de datos no inicializados */
}
