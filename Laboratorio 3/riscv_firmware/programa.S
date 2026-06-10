# programPSP_corregido.S
# EL3313 Lab 3 - ADXL362 por SPI + UART
# RV32I puro, sin .rodata
#
# Mapa de memoria:
#   LEDs       0x02004
#   UART_CTRL  0x02010   bit0=TX_BUSY  bit1=RX_READY
#   UART_TX    0x02018
#   SPI_CTRL   0x02020   write: bit[7:4]=cmd  bit[0]=start
#                         read:  bit[1]=busy   bit[0]=start(autoclear)
#   SPI_TX     0x02028   write: bit[15:8]=reg_addr  bit[7:0]=dato
#   SPI_RX     0x02028   read:  bit[7:0]=byte recibido (byte 3 de trama)
#   SPI_DATA   0x0202C   read:  bit[15:8]=byte2  bit[7:0]=byte3
#   RAM base   0x40000
#
# Protocolo spi_master (3 bytes fijos por transacción):
#   cmd=0 (WRITE): envía [0x0A, reg_addr, dato]
#   cmd=1 (READ) : envía [0x0B, reg_addr, 0x00] → respuesta en SPI_RX[7:0]
#
# DIFERENCIA CLAVE con el .S anterior:
#   El hardware NO acepta byte a byte. Una transacción = 3 bytes completos.
#   Para WRITE: cargar SPI_TX con {reg_addr, dato}, escribir SPI_CTRL con cmd=0,start=1
#   Para READ : cargar SPI_TX con {reg_addr, 0x00}, escribir SPI_CTRL con cmd=1,start=1
#   Luego esperar busy=0 leyendo SPI_CTRL[1], luego leer resultado de SPI_RX o SPI_DATA.

.section .text
.global _start

_start:
        # Stack al final de RAM
        lui     sp, 0x40
        addi    sp, sp, 1024

        # s4 = base UART = 0x02010
        lui     s4, 0x2
        addi    s4, s4, 16

        # s5 = base SPI_CTRL = 0x02020
        lui     s5, 0x2
        addi    s5, s5, 32

        # s6 = base RAM = 0x40000
        lui     s6, 0x40

        # LEDs = 0xAAAA para indicar arranque
        lui     t0, 0x2
        addi    t0, t0, 4
        lui     t1, 0xB
        addi    t1, t1, -1366
        sw      t1, 0(t0)

        # Mensaje: "ADXL\r\n"
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

        # Leer DEVID (reg 0x00) y mostrarlo: "ID=XX\r\n"
        li      a0, 73
        jal     ra, uart_tx
        li      a0, 68
        jal     ra, uart_tx
        li      a0, 61
        jal     ra, uart_tx
        li      a0, 0x00            # reg_addr = 0x00 (DEVID)
        jal     ra, adxl_read_reg   # retorna valor en a0
        jal     ra, print_hex8
        jal     ra, newline

main_loop:
        jal     ra, adxl_read_xyz   # retorna X en s0, Y en s1, Z en s2

        sw      s0, 0(s6)
        sw      s1, 4(s6)
        sw      s2, 8(s6)

        # "X="
        li      a0, 88
        jal     ra, uart_tx
        li      a0, 61
        jal     ra, uart_tx
        mv      a0, s0
        jal     ra, print_int

        # ",Y="
        li      a0, 44
        jal     ra, uart_tx
        li      a0, 89
        jal     ra, uart_tx
        li      a0, 61
        jal     ra, uart_tx
        mv      a0, s1
        jal     ra, print_int

        # ",Z="
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

# =============================================================================
# uart_tx: envía el byte en a0 por UART esperando que TX_BUSY=0
# Usa s4 = base UART (0x02010)
# UART_TX está en offset +8 desde s4 (0x02018)
# UART_CTRL está en offset  0 desde s4 (0x02010)
# =============================================================================
uart_tx:
        lw      t1, 0(s4)           # leer UART_CTRL
        andi    t1, t1, 1           # bit0 = TX_BUSY
        bnez    t1, uart_tx         # esperar si ocupado
        sw      a0, 8(s4)           # escribir en UART_TX (0x02018)
        ret

newline:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      a0, 13
        jal     ra, uart_tx
        li      a0, 10
        jal     ra, uart_tx
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

# =============================================================================
# spi_write_reg: escribe dato a1 en registro a0 del ADXL362
#   cmd=0 (WRITE): spi_master envía [0x0A, a0(reg_addr), a1(dato)]
#   Protocolo:
#     1. SPI_TX[15:8] = reg_addr,  SPI_TX[7:0] = dato
#     2. SPI_CTRL = 0x00000001  (cmd=0=WRITE, start=1)
#     3. Poll SPI_CTRL[1] hasta busy=0
# =============================================================================
spi_write_reg:
        # Construir SPI_TX = {reg_addr[7:0], dato[7:0]}
        andi    t0, a0, 0xFF        # t0 = reg_addr
        slli    t0, t0, 8           # t0 = reg_addr << 8
        andi    t1, a1, 0xFF        # t1 = dato
        or      t0, t0, t1          # t0 = {reg_addr, dato}
        sw      t0, 8(s5)           # PASO 1: SPI_TX (s5+8 = 0x02028)

        li      t0, 1               # cmd=0(WRITE), start=1 → 0x00000001
        sw      t0, 0(s5)           # PASO 2: SPI_CTRL (s5+0 = 0x02020)

spi_wr_busy:
        lw      t0, 0(s5)           # PASO 3: leer SPI_CTRL
        andi    t0, t0, 2           # bit[1] = busy
        bnez    t0, spi_wr_busy     # esperar
        ret

# =============================================================================
# spi_read_reg: lee el registro a0 del ADXL362, retorna valor en a0
#   cmd=1 (READ): spi_master envía [0x0B, a0(reg_addr), 0x00]
#   Protocolo:
#     1. SPI_TX[15:8] = reg_addr,  SPI_TX[7:0] = 0x00
#     2. SPI_CTRL = 0x00000011  (cmd=1=READ en bits[7:4], start=1 en bit[0])
#     3. Poll SPI_CTRL[1] hasta busy=0
#     4. Leer SPI_DATA (0x0202C) → byte recibido en bits[7:0]
# =============================================================================
spi_read_reg:
        andi    t0, a0, 0xFF        # t0 = reg_addr
        slli    t0, t0, 8           # t0 = reg_addr << 8
                                    # dato = 0x00 (OR con 0)
        sw      t0, 8(s5)           # PASO 1: SPI_TX (0x02028)

        li      t0, 0x11            # cmd=1(READ) en bits[7:4]=0001, start=1
        sw      t0, 0(s5)           # PASO 2: SPI_CTRL (0x02020)

spi_rd_busy:
        lw      t0, 0(s5)           # PASO 3: leer SPI_CTRL
        andi    t0, t0, 2           # bit[1] = busy
        bnez    t0, spi_rd_busy     # esperar

        lw      a0, 12(s5)           # PASO 4: SPI_DATA (0x0202C) → a0[7:0]
        andi    a0, a0, 0xFF        # retornar solo byte recibido
        ret

# =============================================================================
# adxl_write_reg: wrapper público — a0=reg_addr, a1=dato
# =============================================================================
adxl_write_reg:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        jal     ra, spi_write_reg
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

# =============================================================================
# adxl_read_reg: wrapper público — a0=reg_addr, retorna valor en a0
# =============================================================================
adxl_read_reg:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        jal     ra, spi_read_reg
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

# =============================================================================
# adxl_init: secuencia de inicialización del ADXL362
#   1. Soft reset: reg 0x1F = 0x52
#   2. Measurement mode: reg 0x2D = 0x02
# =============================================================================
adxl_init:
        addi    sp, sp, -4
        sw      ra, 0(sp)

        li      a0, 0x1F            # reg SOFT_RESET
        li      a1, 0x52            # valor reset
        jal     ra, adxl_write_reg
        jal     ra, delay_long      # esperar estabilización

        li      a0, 0x2D            # reg POWER_CTL
        li      a1, 0x02            # measurement mode
        jal     ra, adxl_write_reg
        jal     ra, delay_long

        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

# =============================================================================
# adxl_read_xyz: lee X, Y, Z de 12 bits cada uno
#   Usa spi_read_reg repetidamente:
#     reg 0x0E = XDATA_L,  reg 0x0F = XDATA_H
#     reg 0x10 = YDATA_L,  reg 0x11 = YDATA_H
#     reg 0x12 = ZDATA_L,  reg 0x13 = ZDATA_H
#   Retorna: s0=X(sign-ext 12b), s1=Y, s2=Z
# =============================================================================
adxl_read_xyz:
        addi    sp, sp, -4
        sw      ra, 0(sp)

        # X low byte
        li      a0, 0x0E
        jal     ra, spi_read_reg
        mv      t3, a0              # t3 = XDATA_L

        # X high byte
        li      a0, 0x0F
        jal     ra, spi_read_reg
        slli    t4, a0, 8           # t4 = XDATA_H << 8
        or      s0, t3, t4          # s0 = {XDATA_H, XDATA_L}
        slli    s0, s0, 20          # sign-extend 12 bits
        srai    s0, s0, 20

        # Y low byte
        li      a0, 0x10
        jal     ra, spi_read_reg
        mv      t3, a0

        # Y high byte
        li      a0, 0x11
        jal     ra, spi_read_reg
        slli    t4, a0, 8
        or      s1, t3, t4
        slli    s1, s1, 20
        srai    s1, s1, 20

        # Z low byte
        li      a0, 0x12
        jal     ra, spi_read_reg
        mv      t3, a0

        # Z high byte
        li      a0, 0x13
        jal     ra, spi_read_reg
        slli    t4, a0, 8
        or      s2, t3, t4
        slli    s2, s2, 20
        srai    s2, s2, 20

        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

# =============================================================================
# print_int: imprime entero con signo en a0
# =============================================================================
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
        addi    sp, sp, -4
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

# =============================================================================
# print_hex8: imprime byte en a0 como dos dígitos hex
# =============================================================================
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
        li      t0, 200000
        blt     a0, t0, phd_num
        addi    a0, a0, 55
        j       phd_send
phd_num:
        addi    a0, a0, 48
phd_send:
        j       uart_tx

# =============================================================================
# Delays
# =============================================================================
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
