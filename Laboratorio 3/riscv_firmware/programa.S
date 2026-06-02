# programa.S
# EL3313 Lab 3 - Prueba inicial ADXL362 por SPI + UART
# RV32I puro, sin .rodata
#
# Mapa:
#   LEDs       0x02004
#   UART_CTRL  0x02010   bit0 = TX_BUSY, bit1 = RX_READY
#   UART_TX    0x02018
#   SPI_CTRL   0x02020   bit0 = SPI_BUSY, bit1 = RX_READY
#   SPI_TX     0x02028   bit[7:0] = dato, bit[8] = CS_HOLD
#   SPI_RX     0x0202C
#   RAM base   0x40000

.section .text
.global _start

_start:
        # Stack al final aproximado de RAM
        lui     sp, 0x40
        addi    sp, sp, 1024

        # Base UART = 0x02010
        lui     s4, 0x2
        addi    s4, s4, 16

        # Base SPI = 0x02020
        lui     s5, 0x2
        addi    s5, s5, 32

        # Base RAM = 0x40000
        lui     s6, 0x40

        # LEDs = 0xAAAA para indicar arranque
        lui     t0, 0x2
        addi    t0, t0, 4
        lui     t1, 0xB
        addi    t1, t1, -1366
        sw      t1, 0(t0)

        # Mensaje corto: A D X L \r \n
        li      a0, 65
        jal     ra, uart_tx
        li      a0, 68
        jal     ra, uart_tx
        li      a0, 88
        jal     ra, uart_tx
        li      a0, 76
        jal     ra, uart_tx
        jal     ra, newline

        # Inicializar ADXL362
        jal     ra, adxl_init

        # Leer ID register 0x00 y enviarlo en hex
        li      a0, 73
        jal     ra, uart_tx
        li      a0, 68
        jal     ra, uart_tx
        li      a0, 61
        jal     ra, uart_tx
        li      a0, 0x00
        jal     ra, adxl_read_reg
        jal     ra, print_hex8
        jal     ra, newline

main_loop:
        jal     ra, adxl_read_xyz

        # Guardar X/Y/Z en RAM
        sw      s0, 0(s6)
        sw      s1, 4(s6)
        sw      s2, 8(s6)

        # X=
        li      a0, 88
        jal     ra, uart_tx
        li      a0, 61
        jal     ra, uart_tx
        mv      a0, s0
        jal     ra, print_int

        # ,Y=
        li      a0, 44
        jal     ra, uart_tx
        li      a0, 89
        jal     ra, uart_tx
        li      a0, 61
        jal     ra, uart_tx
        mv      a0, s1
        jal     ra, print_int

        # ,Z=
        li      a0, 44
        jal     ra, uart_tx
        li      a0, 90
        jal     ra, uart_tx
        li      a0, 61
        jal     ra, uart_tx
        mv      a0, s2
        jal     ra, print_int

        jal     ra, newline
        jal     ra, delay_10ms
        j       main_loop

uart_tx:
        lw      t1, 0(s4)
        andi    t1, t1, 1
        bnez    t1, uart_tx
        sw      a0, 8(s4)
        ret

newline:
        addi    sp, sp, 1024
        sw      ra, 0(sp)
        li      a0, 13
        jal     ra, uart_tx
        li      a0, 10
        jal     ra, uart_tx
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

print_int:
        addi    sp, sp, -16
        sw      ra, 12(sp)
        sw      s7, 8(sp)
        sw      s8, 4(sp)

        mv      s7, a0
        li      s8, 0

        bge     s7, zero, pi_pos
        li      a0, 45
        jal     ra, uart_tx
        sub     s7, zero, s7

pi_pos:
        bnez    s7, pi_push
        li      a0, 48
        jal     ra, uart_tx
        j       pi_done

pi_push:
        beqz    s7, pi_pop
        li      t1, 10
        li      t0, 0
        mv      t2, s7

pi_div:
        blt     t2, t1, pi_dend
        sub     t2, t2, t1
        addi    t0, t0, 1
        j       pi_div

pi_dend:
        addi    t2, t2, 48
        addi    sp, sp, 1024
        sw      t2, 0(sp)
        addi    s8, s8, 1
        mv      s7, t0
        j       pi_push

pi_pop:
        beqz    s8, pi_done
        lw      a0, 0(sp)
        addi    sp, sp, 4
        addi    s8, s8, -1
        jal     ra, uart_tx
        j       pi_pop

pi_done:
        lw      ra, 12(sp)
        lw      s7, 8(sp)
        lw      s8, 4(sp)
        addi    sp, sp, 16
        ret

print_hex8:
        addi    sp, sp, -8
        sw      ra, 4(sp)
        sw      a0, 0(sp)

        srli    a0, a0, 4
        andi    a0, a0, 0xF
        jal     ra, print_hex_digit

        lw      a0, 0(sp)
        andi    a0, a0, 0xF
        jal     ra, print_hex_digit

        lw      ra, 4(sp)
        addi    sp, sp, 8
        ret

print_hex_digit:
        li      t0, 10
        blt     a0, t0, phd_num
        addi    a0, a0, 55
        j       phd_send

phd_num:
        addi    a0, a0, 48

phd_send:
        jal     ra, uart_tx
        ret

# ============================================================
# SPI compatible con spi_master.sv actual
#
# SPI base s5 = 0x02020
#   0(s5)  = SPI_CTRL
#   8(s5)  = SPI_TX
#   12(s5) = SPI_DATA
#
# WRITE:
#   SPI_TX   <- {reg_addr, dato}
#   SPI_CTRL <- 0x01
#
# READ:
#   SPI_TX   <- {reg_addr, 0x00}
#   SPI_CTRL <- 0x11
# ============================================================

spi_wait_done:
        # Esperar a que busy suba
spi_wait_start:
        lw      t0, 0(s5)
        andi    t0, t0, 2
        beqz    t0, spi_wait_start

        # Esperar a que busy baje
spi_wait_finish:
        lw      t0, 0(s5)
        andi    t0, t0, 2
        bnez    t0, spi_wait_finish

        ret


adxl_write_reg:
        addi    sp, sp, -4
        sw      ra, 0(sp)

        # a0 = registro
        # a1 = dato
        slli    t0, a0, 8
        andi    t1, a1, 0xFF
        or      t0, t0, t1

        # SPI_TX = {reg_addr, data}
        sw      t0, 8(s5)

        # SPI_CTRL = 0x01 -> WRITE + start
        li      t1, 0x01
        sw      t1, 0(s5)

        jal     ra, spi_wait_done

        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret


adxl_read_reg:
        addi    sp, sp, -4
        sw      ra, 0(sp)

        # a0 = registro
        slli    t0, a0, 8

        # SPI_TX = {reg_addr, 0x00}
        sw      t0, 8(s5)

        # SPI_CTRL = 0x11 -> READ + start
        li      t1, 0x11
        sw      t1, 0(s5)

        jal     ra, spi_wait_done

        # Leer dato recibido
        lw      a0, 12(s5)
        andi    a0, a0, 0xFF

        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret


adxl_init:
        addi    sp, sp, -4
        sw      ra, 0(sp)

        # SOFT_RESET = 0x52 en registro 0x1F
        li      a0, 0x1F
        li      a1, 0x52
        jal     ra, adxl_write_reg
        jal     ra, delay_long

        # POWER_CTL = 0x02 en registro 0x2D
        li      a0, 0x2D
        li      a1, 0x02
        jal     ra, adxl_write_reg
        jal     ra, delay_long

        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret


adxl_read_xyz:
        addi    sp, sp, -4
        sw      ra, 0(sp)

        # X low = 0x0E
        li      a0, 0x0E
        jal     ra, adxl_read_reg
        mv      t3, a0

        # X high = 0x0F
        li      a0, 0x0F
        jal     ra, adxl_read_reg
        slli    t4, a0, 8
        or      s0, t3, t4
        slli    s0, s0, 20
        srai    s0, s0, 20

        # Y low = 0x10
        li      a0, 0x10
        jal     ra, adxl_read_reg
        mv      t3, a0

        # Y high = 0x11
        li      a0, 0x11
        jal     ra, adxl_read_reg
        slli    t4, a0, 8
        or      s1, t3, t4
        slli    s1, s1, 20
        srai    s1, s1, 20

        # Z low = 0x12
        li      a0, 0x12
        jal     ra, adxl_read_reg
        mv      t3, a0

        # Z high = 0x13
        li      a0, 0x13
        jal     ra, adxl_read_reg
        slli    t4, a0, 8
        or      s2, t3, t4
        slli    s2, s2, 20
        srai    s2, s2, 20

        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret
delay_10ms:
        li      t0, 25000

d10_loop:
        addi    t0, t0, -1
        bnez    t0, d10_loop
        ret

delay_long:
        li      t0, 200000

dl_loop:
        addi    t0, t0, -1
        bnez    t0, dl_loop
        ret
