# PS CSR UC4 (Zynq-7000)

PS side of the CSR test UC4 (point 4: illegal command), without GDB and OpenOCD.
There is no CPU program: after the power-on the CPU is running and Simply-V is in BUSY.

The PS:
1. checks that STATUS is BUSY, as after the power-on;
2. sends LOAD PROGRAM, legal only in IDLE, and checks that STATUS is ERROR.

The recovery from ERROR is UC5 (`sw/host/zynq/ps_csr_uc5`).
All the combinations of state and command are tested in simulation (`hw/xilinx/sim/tb/tb_csr_fsm.sv`).

## Build and run

As in `sw/host/zynq/ps_csr_uc1/README.md`, with `ps_csr_uc4` in place of `ps_csr_uc1`.
There is no CPU program to build: skip `make -C sw/SoC/examples/...`.

## Expected output

On the PS UART (115200 baud):
```
[PS] CSR at 0x40060000, STATUS BUSY
[PS] LOAD PROGRAM in BUSY (illegal) -> STATUS ERROR
[PS] Test passed
```
