# Programa principal en ensamblador RV32I
# Laboratorio 2 - Microcontrolador RISC-V
# Recibe una expresión numérica por UART, calcula y responde el resultado
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
    # ── Leer número 1 ──────────────────────
    li s0, 0                # acumulador num1
read_num1:
    call uart_getchar
    call uart_putchar       # eco

    li t0, '+'
    beq a0, t0, got_plus
    li t0, '-'
    beq a0, t0, got_minus

    # acumular dígito: s0 = s0*10 + digito
    li t0, '0'
    sub a0, a0, t0          # a0 = valor numérico del dígito
    mv t2, a0               # guardar dígito en t2
    mv a1, s0
    call mul10              # a0 = s0 * 10
    add s0, a0, t2          # s0 = (s0*10) + dígito
    j read_num1

got_plus:
    li s1, 1                # operador = 1 (suma)
    j read_num2

got_minus:
    li s1, 0                # operador = 0 (resta)

# ── Leer número 2 ──────────────────────
read_num2:
    li s2, 0                # acumulador num2
read_num2_loop:
    call uart_getchar
    call uart_putchar       # eco

    li t0, 0x0D             # Enter
    beq a0, t0, calculate

    # acumular dígito: s2 = s2*10 + digito
    li t0, '0'
    sub a0, a0, t0          # a0 = valor numérico del dígito
    mv t2, a0               # guardar dígito en t2
    mv a1, s2
    call mul10              # a0 = s2 * 10
    add s2, a0, t2          # s2 = (s2*10) + dígito
    j read_num2_loop

# ── Calcular ───────────────────────────
calculate:
    # enviar "\r\n= "
    li a0, 0x0D
    call uart_putchar
    li a0, 0x0A
    call uart_putchar
    li a0, '='
    call uart_putchar
    li a0, ' '
    call uart_putchar

    beq s1, zero, do_sub
    add s3, s0, s2
    j send_result
do_sub:
    sub s3, s0, s2

send_result:
    mv a0, s3
    call uart_print_int

    li a0, 0x0D
    call uart_putchar
    li a0, 0x0A
    call uart_putchar

    j main_loop

# ── mul10: retorna a1*10 en a0 ──
mul10:
    slli t0, a1, 3          # t0 = a1 * 8
    slli t1, a1, 1          # t1 = a1 * 2
    add a0, t0, t1          # a0 = a1 * 10
    ret

# ── div10: divide a0 entre 10 ──
# retorna cociente en a0, resto en a1
div10:
    li t0, 0                # cociente
    li t1, 10
div10_loop:
    blt a0, t1, div10_done
    sub a0, a0, t1
    addi t0, t0, 1
    j div10_loop
div10_done:
    mv a1, a0               # resto
    mv a0, t0               # cociente
    ret

# ── uart_print_int: envía número en a0 como texto ──
uart_print_int:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)

    li t0, 0
    bge a0, t0, print_positive
    # número negativo
    addi sp, sp, -4
    li t1, '-'
    sw t1, 0(sp)
    neg a0, a0

print_positive:
    li s0, 0                # contador dígitos
digit_loop:
    call div10              # a0=cociente, a1=resto
    addi a1, a1, '0'       # resto a ASCII
    addi sp, sp, -4
    sw a1, 0(sp)
    addi s0, s0, 1
    bne a0, zero, digit_loop

    # caso especial: número era 0
    bne s0, zero, send_digits
    li t0, '0'
    addi sp, sp, -4
    sw t0, 0(sp)
    addi s0, s0, 1

send_digits:
    lw a0, 0(sp)
    addi sp, sp, 4
    call uart_putchar
    addi s0, s0, -1
    bne s0, zero, send_digits

    lw ra, 28(sp)
    lw s0, 24(sp)
    lw s1, 20(sp)
    addi sp, sp, 32
    ret

# ── uart_getchar ──
uart_getchar:
    li t0, UART_CTRL
wait_rx:
    lw t1, 0(t0)
    andi t1, t1, 2
    beq t1, zero, wait_rx
    li t0, UART_RX
    lw a0, 0(t0)
    li t0, UART_CTRL
    lw t1, 0(t0)
    andi t1, t1, 0xFFFFFFFD
    sw t1, 0(t0)
    ret

# ── uart_putchar ──
uart_putchar:
    li t0, UART_TX
    sw a0, 0(t0)
    li t0, UART_CTRL
    lw t1, 0(t0)
    ori t1, t1, 1
    sw t1, 0(t0)
wait_tx:
    lw t1, 0(t0)
    andi t1, t1, 1
    bne t1, zero, wait_tx
    ret
