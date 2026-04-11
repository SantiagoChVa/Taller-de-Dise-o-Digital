.section .text
.global _start

# Direcciones de periféricos
.equ UART_CTRL,  0x02010
.equ UART_TX,    0x02018
.equ UART_RX,    0x0201C
.equ LEDS,       0x02004

_start:
    li sp, 0x0007FFFC

    # LEDs en 0xAAAA = sistema listo
    li t0, LEDS
    li t1, 0xAAAA
    sw t1, 0(t0)

main_loop:
    call uart_getchar
    mv a0, a0
    call uart_putchar
    j main_loop

# ── uart_getchar: espera y retorna byte en a0 ──
uart_getchar:
    li t0, UART_CTRL
wait_rx:
    lw t1, 0(t0)
    andi t1, t1, 2          # bit 1 = new_rx
    beq t1, zero, wait_rx
    li t0, UART_RX
    lw a0, 0(t0)            # leer byte recibido
    li t0, UART_CTRL
    lw t1, 0(t0)
    andi t1, t1, 0xFFFFFFFD # limpiar bit 1
    sw t1, 0(t0)
    ret

# ── uart_putchar: envía byte en a0 ──
uart_putchar:
    li t0, UART_TX
    sw a0, 0(t0)            # escribir byte a enviar
    li t0, UART_CTRL
    lw t1, 0(t0)
    ori t1, t1, 1           # bit 0 = send
    sw t1, 0(t0)
wait_tx:
    lw t1, 0(t0)
    andi t1, t1, 1          # esperar que bit 0 vuelva a 0
    bne t1, zero, wait_tx
    ret
