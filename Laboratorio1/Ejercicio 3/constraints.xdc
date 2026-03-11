## CLOCK
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 [get_ports clk]

## SWITCHES
set_property PACKAGE_PIN J15 [get_ports {level[0]}]
set_property PACKAGE_PIN L16 [get_ports {level[1]}]
set_property PACKAGE_PIN M13 [get_ports {level[2]}]
set_property PACKAGE_PIN R15 [get_ports {level[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {level[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {level[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {level[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {level[3]}]

## LED
set_property PACKAGE_PIN H17 [get_ports pwm_out]
set_property IOSTANDARD LVCMOS33 [get_ports pwm_out]
