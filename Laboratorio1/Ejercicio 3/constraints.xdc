## CLOCK
set_property PACKAGE_PIN E3 [get_ports CLK]
set_property IOSTANDARD LVCMOS33 [get_ports CLK]
create_clock -period 10.000 [get_ports CLK]

## SWITCHES
set_property PACKAGE_PIN J15 [get_ports {SW[0]}]
set_property PACKAGE_PIN L16 [get_ports {SW[1]}]
set_property PACKAGE_PIN M13 [get_ports {SW[2]}]
set_property PACKAGE_PIN R15 [get_ports {SW[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {SW[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SW[3]}]

## LED
set_property PACKAGE_PIN H17 [get_ports LED]
set_property IOSTANDARD LVCMOS33 [get_ports LED]
