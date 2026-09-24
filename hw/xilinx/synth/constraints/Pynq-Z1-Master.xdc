## Pynq-Z1-Master.xdc
## Adapted for Simply-V (embedded profile, PL-only) from the Digilent PYNQ-Z1
## Rev. C master XDC. Port names match hw/xilinx/synth/constraints/Arty-A7-100T-Master.xdc
## so the same RTL top-level (simplyv.sv) works unmodified.

## Clock signal - 125 MHz (PL fabric clock, always present, no PS needed)
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sys_clock_i }]; #Sch=sysclk
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0.000 4.000} [get_ports { sys_clock_i }];

## System reset - BTN0 (dirty workaround: used as resetn source for xlnx_clk_wiz,
## whose `locked` output is then used as system reset - see sys_master.sv).
## Board default: released (0) at power-up, so the system starts on its own
## without needing anyone to press it - required for unattended CI/HIL.
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { sys_reset_i }]; #Sch=btn[0]

## Switches (only 2 available on Pynq-Z1, vs 4 on Arty - adjust gpio_in_i width if needed)
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[0] }]; #Sch=sw[0]
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[1] }]; #Sch=sw[1]

## LEDs
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[0] }]; #Sch=led[0]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[1] }]; #Sch=led[1]
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[2] }]; #Sch=led[2]
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[3] }]; #Sch=led[3]

## UART via external FTDI on Pmod Header JA (Pynq's onboard USB-UART is wired to
## PS MIO14/15, unreachable in PL-only - see FTDI notes in doc/UART_CONNECTION.md).
## Using ja[0]/ja[1] for TX/RX; wire the FTDI module's RX to ja[0] (FPGA TX) and
## TX to ja[1] (FPGA RX).
set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }]; #Pmod JA pin 1 (ja[0])
set_property -dict { PACKAGE_PIN Y19   IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]; #Pmod JA pin 2 (ja[1])