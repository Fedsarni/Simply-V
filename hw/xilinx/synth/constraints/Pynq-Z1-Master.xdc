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

## Switches (only 2 physical switches on Pynq-Z1, vs 4 on Arty)
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[0] }]; #Sch=sw[0]
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[1] }]; #Sch=sw[1]

## LEDs
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[0] }]; #Sch=led[0]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[1] }]; #Sch=led[1]
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[2] }]; #Sch=led[2]
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[3] }]; #Sch=led[3]

## gpio_in_i/gpio_out_o are fixed 16-bit buses in simplyv_pkg.sv (not board-specific).
## Pynq-Z1 only has 2 switches + 4 LEDs physically available, so the remaining bits
## are constrained here to spare Shield Digital I/O pins (not wired to anything
## external) purely to satisfy the placer - Vivado's IO Clock Placer fails outright
## on a partially-locked wide IO bus on this Zynq part (unlike on Arty's pure
## Artix-7, where the unconstrained bits are auto-placed without error).
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[2]  }]; #Shield IO0 (spare, unconnected)
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[3]  }]; #Shield IO1 (spare, unconnected)
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[4]  }]; #Shield IO2 (spare, unconnected)
set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[5]  }]; #Shield IO3 (spare, unconnected)
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[6]  }]; #Shield IO4 (spare, unconnected)
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[7]  }]; #Shield IO5 (spare, unconnected)
set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[8]  }]; #Shield IO6 (spare, unconnected)
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[9]  }]; #Shield IO7 (spare, unconnected)
set_property -dict { PACKAGE_PIN V17   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[10] }]; #Shield IO8 (spare, unconnected)
set_property -dict { PACKAGE_PIN V18   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[11] }]; #Shield IO9 (spare, unconnected)
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[12] }]; #Shield IO10 (spare, unconnected)
set_property -dict { PACKAGE_PIN R17   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[13] }]; #Shield IO11 (spare, unconnected)
set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[14] }]; #Shield IO12 (spare, unconnected)
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[15] }]; #Shield IO13 (spare, unconnected)

set_property -dict { PACKAGE_PIN U5    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[4]  }]; #Shield IO26 (spare, unconnected)
set_property -dict { PACKAGE_PIN V5    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[5]  }]; #Shield IO27 (spare, unconnected)
set_property -dict { PACKAGE_PIN V6    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[6]  }]; #Shield IO28 (spare, unconnected)
set_property -dict { PACKAGE_PIN U7    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[7]  }]; #Shield IO29 (spare, unconnected)
set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[8]  }]; #Shield IO30 (spare, unconnected)
set_property -dict { PACKAGE_PIN U8    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[9]  }]; #Shield IO31 (spare, unconnected)
set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[10] }]; #Shield IO32 (spare, unconnected)
set_property -dict { PACKAGE_PIN V10   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[11] }]; #Shield IO33 (spare, unconnected)
set_property -dict { PACKAGE_PIN W10   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[12] }]; #Shield IO34 (spare, unconnected)
set_property -dict { PACKAGE_PIN W6    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[13] }]; #Shield IO35 (spare, unconnected)
set_property -dict { PACKAGE_PIN Y6    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[14] }]; #Shield IO36 (spare, unconnected)
set_property -dict { PACKAGE_PIN Y7    IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[15] }]; #Shield IO37 (spare, unconnected)

## UART via external FTDI on Pmod Header JA (Pynq's onboard USB-UART is wired to
## PS MIO14/15, unreachable in PL-only - see FTDI notes in doc/UART_CONNECTION.md).
## Using ja[0]/ja[1] for TX/RX; wire the FTDI module's RX to ja[0] (FPGA TX) and
## TX to ja[1] (FPGA RX).
set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }]; #Pmod JA pin 1 (ja[0])
set_property -dict { PACKAGE_PIN Y19   IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]; #Pmod JA pin 2 (ja[1])
