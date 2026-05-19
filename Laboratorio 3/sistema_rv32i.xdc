## =============================================================================
## sistema_rv32i.xdc — Nexys4 DDR (Artix-7 XC7A100T)
## NOTA: rst_ext_i está conectado al botón CPU RESET (pin C12).
##       Ese botón es ACTIVO BAJO en la Nexys4 DDR.
##       La inversión se hace en top.sv con: assign rst_btn = ~rst_ext_i
## =============================================================================

## Reloj principal 100 MHz
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { clk_in1 }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_in1 }];

## Reset — botón CPU RESET, activo bajo (la inversión está en top.sv)
set_property -dict { PACKAGE_PIN C12  IOSTANDARD LVCMOS33 } [get_ports { rst_ext_i }];

## UART
set_property -dict { PACKAGE_PIN D4   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }];
set_property -dict { PACKAGE_PIN C4   IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }];

## Switches sw_i[15:0]
set_property -dict { PACKAGE_PIN J15  IOSTANDARD LVCMOS33 } [get_ports { sw_i[0]  }];
set_property -dict { PACKAGE_PIN L16  IOSTANDARD LVCMOS33 } [get_ports { sw_i[1]  }];
set_property -dict { PACKAGE_PIN M13  IOSTANDARD LVCMOS33 } [get_ports { sw_i[2]  }];
set_property -dict { PACKAGE_PIN R15  IOSTANDARD LVCMOS33 } [get_ports { sw_i[3]  }];
set_property -dict { PACKAGE_PIN R17  IOSTANDARD LVCMOS33 } [get_ports { sw_i[4]  }];
set_property -dict { PACKAGE_PIN T18  IOSTANDARD LVCMOS33 } [get_ports { sw_i[5]  }];
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports { sw_i[6]  }];
set_property -dict { PACKAGE_PIN R13  IOSTANDARD LVCMOS33 } [get_ports { sw_i[7]  }];
set_property -dict { PACKAGE_PIN T8   IOSTANDARD LVCMOS18 } [get_ports { sw_i[8]  }];
set_property -dict { PACKAGE_PIN U8   IOSTANDARD LVCMOS18 } [get_ports { sw_i[9]  }];
set_property -dict { PACKAGE_PIN R16  IOSTANDARD LVCMOS33 } [get_ports { sw_i[10] }];
set_property -dict { PACKAGE_PIN T13  IOSTANDARD LVCMOS33 } [get_ports { sw_i[11] }];
set_property -dict { PACKAGE_PIN H6   IOSTANDARD LVCMOS33 } [get_ports { sw_i[12] }];
set_property -dict { PACKAGE_PIN U12  IOSTANDARD LVCMOS33 } [get_ports { sw_i[13] }];
set_property -dict { PACKAGE_PIN U11  IOSTANDARD LVCMOS33 } [get_ports { sw_i[14] }];
set_property -dict { PACKAGE_PIN V10  IOSTANDARD LVCMOS33 } [get_ports { sw_i[15] }];

## LEDs led_o[15:0]
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS33 } [get_ports { led_o[0]  }];
set_property -dict { PACKAGE_PIN K15  IOSTANDARD LVCMOS33 } [get_ports { led_o[1]  }];
set_property -dict { PACKAGE_PIN J13  IOSTANDARD LVCMOS33 } [get_ports { led_o[2]  }];
set_property -dict { PACKAGE_PIN N14  IOSTANDARD LVCMOS33 } [get_ports { led_o[3]  }];
set_property -dict { PACKAGE_PIN R18  IOSTANDARD LVCMOS33 } [get_ports { led_o[4]  }];
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports { led_o[5]  }];
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports { led_o[6]  }];
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports { led_o[7]  }];
set_property -dict { PACKAGE_PIN V16  IOSTANDARD LVCMOS33 } [get_ports { led_o[8]  }];
set_property -dict { PACKAGE_PIN T15  IOSTANDARD LVCMOS33 } [get_ports { led_o[9]  }];
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports { led_o[10] }];
set_property -dict { PACKAGE_PIN T16  IOSTANDARD LVCMOS33 } [get_ports { led_o[11] }];
set_property -dict { PACKAGE_PIN V15  IOSTANDARD LVCMOS33 } [get_ports { led_o[12] }];
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports { led_o[13] }];
set_property -dict { PACKAGE_PIN V12  IOSTANDARD LVCMOS33 } [get_ports { led_o[14] }];
set_property -dict { PACKAGE_PIN V11  IOSTANDARD LVCMOS33 } [get_ports { led_o[15] }];

## =============================================================================
## SPI — ADXL362 (acelerómetro integrado en la Nexys4 DDR)
## Pines dedicados del ADXL362 según la master XDC de Digilent (Nexys4 DDR).
## El ADXL362 comparte bus SPI con el conector JA en algunas revisiones;
## en la Nexys4 DDR los pines dedicados son los siguientes:
## =============================================================================
set_property -dict { PACKAGE_PIN E15  IOSTANDARD LVCMOS33 } [get_ports { acl_miso_i }];
set_property -dict { PACKAGE_PIN F14  IOSTANDARD LVCMOS33 } [get_ports { acl_mosi_o }];
set_property -dict { PACKAGE_PIN F15  IOSTANDARD LVCMOS33 } [get_ports { acl_sck_o  }];
set_property -dict { PACKAGE_PIN D15  IOSTANDARD LVCMOS33 } [get_ports { acl_cs_n_o }];
