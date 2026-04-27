# Programa principal RV32I - Laboratorio 2
# Calcula suma o resta de dos números recibidos por UART

.section .text
.global _start

_start:
        # sp = tope real de RAM 100KB
        lui     sp, 0x59
        addi    sp, sp, -4
        lui     s4, 0x2
        addi    s4, s4, 16         # s4 = 0x02010 (base UART)
        lui     t0, 0x2
        addi    t0, t0, 4          # t0 = 0x02004 (LEDs)
        lui     t1, 0xb
        addi    t1, t1, -1366
        sw      t1, 0(t0)          # LEDs = 0xAAAA (sistema listo)

main_loop:
        li      s0, 0              # acumulador número 1
rf_loop:
        jal     ra, uart_rx        # leer byte
        jal     ra, uart_tx        # eco
        li      t0, 43
        beq     a0, t0, op_plus    # es '+'
        li      t0, 45
        beq     a0, t0, op_minus   # es '-'
        li      t0, 48
        blt     a0, t0, rf_loop    # ignorar si < '0'
        li      t0, 57
        blt     t0, a0, rf_loop    # ignorar si > '9'
        addi    t2, a0, -48        # convertir ASCII a número
        mv      a1, s0
        jal     ra, mul10
        add     s0, a0, t2         # acumular dígito
        j       rf_loop

op_plus:
        li      s1, 1              # operador = suma
        j       rs_init
op_minus:
        li      s1, 0              # operador = resta

rs_init:
        li      s2, 0              # acumulador número 2
rs_loop:
        jal     ra, uart_rx
        jal     ra, uart_tx
        li      t0, 48
        blt     a0, t0, calc       # terminar si < '0'
        li      t0, 57
        blt     t0, a0, calc       # terminar si > '9'
        addi    t2, a0, -48
        mv      a1, s2
        jal     ra, mul10
        add     s2, a0, t2
        j       rs_loop

calc:
        li      a0, 13             # \r
        jal     ra, uart_tx
        li      a0, 10             # \n
        jal     ra, uart_tx
        li      a0, 61             # '='
        jal     ra, uart_tx
        li      a0, 32             # ' '
        jal     ra, uart_tx
        beqz    s1, do_sub
        add     s3, s0, s2
        j       show
do_sub:
        sub     s3, s0, s2
show:
        mv      a0, s3
        jal     ra, print_int
        li      a0, 13
        jal     ra, uart_tx
        li      a0, 10
        jal     ra, uart_tx
        j       main_loop

# uart_rx: espera y retorna byte recibido en a0
uart_rx:
        lw      t1, 0(s4)
        andi    t1, t1, 2          # bit 1 = new_rx
        beqz    t1, uart_rx
        lw      a0, 12(s4)         # leer dato RX
        ret

# uart_tx: espera TX libre y envía byte en a0
uart_tx:
        lw      t1, 0(s4)
        andi    t1, t1, 1          # bit 0 = send
        bnez    t1, uart_tx
        sw      a0, 8(s4)          # escribir dato TX
        ret

# mul10: retorna a1*10 en a0 usando shifts
mul10:
        slli    t0, a1, 3          # a1 * 8
        slli    t1, a1, 1          # a1 * 2
        add     a0, t0, t1         # a1 * 10
        ret

# print_int: envía número en a0 como texto por UART
print_int:
        addi    sp, sp, -16
        sw      ra,  12(sp)
        sw      s5,   8(sp)
        sw      s6,   4(sp)
        mv      s5, a0
        li      s6, 0
        li      t0, 0
        bge     s5, t0, pi_pos
        li      a0, 45             # enviar '-'
        jal     ra, uart_tx
        sub     s5, zero, s5
pi_pos:
        bnez    s5, pi_push
        li      a0, 48             # caso especial: 0
        jal     ra, uart_tx
        j       pi_done
pi_push:
        beqz    s5, pi_pop
        li      t1, 10
        li      t0, 0
        mv      t2, s5
pi_div:
        blt     t2, t1, pi_dend
        sub     t2, t2, t1
        addi    t0, t0, 1
        j       pi_div
pi_dend:
        addi    t2, t2, 48         # convertir a ASCII
        addi    sp, sp, -4
        sw      t2, 0(sp)          # apilar dígito
        addi    s6, s6, 1
        mv      s5, t0
        j       pi_push
pi_pop:
        beqz    s6, pi_done
        lw      a0, 0(sp)
        addi    sp, sp, 4
        addi    s6, s6, -1
        jal     ra, uart_tx
        j       pi_pop
pi_done:
        lw      ra,  12(sp)
        lw      s5,   8(sp)
        lw      s6,   4(sp)
        addi    sp, sp, 16
        ret
