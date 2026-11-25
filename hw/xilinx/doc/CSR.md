# Simply-V CSR

The CSR block lets an external master (the host) use Simply-V as a co-processing device: the host loads a program and its data, starts the CPU and waits for the end of the job.
The program running on the Simply-V CPU (the runtime) reads where its data are and reports the end of the job through the same block.

- RTL: `hw/xilinx/rtl/simplyv_csr.sv`, an AXI4-Lite slave on the MBUS (behind an AXI4 to AXI4-Lite converter).
- Host driver: `sw/host/zynq/lib/simplyv_csr_host.h` (Cortex-A9 #0 of the Zynq-7000 PS).
- Runtime driver: `sw/SoC/lib/simplyv/inc/simplyv_csr.h` (CPU of Simply-V), included by `simplyv.h` when `CSR_IS_ENABLED`.

## Address

| Seen by | Address |
| --- | --- |
| Simply-V CPU, JTAG-to-AXI | `0x60000` (`_peripheral_CSR_start` in `simplyv_conf.h`) |
| Zynq-7000 PS | `0x40060000` (`PS_M_AXI_GP0_BASEADDR + _peripheral_CSR_start`) |

The address comes from the `CSR` column of `config/configs/<profile>/config_mbus.csv`.

## Registers

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | COMMAND | W (reads 0) | Command to execute |
| `0x04` | STATUS | R | State of Simply-V. A write answers SLVERR and is ignored |
| `0x08` | BOOT_ADDR | RW | Boot address of the CPU, used at the next RUN |
| `0x0C` | PTR_IN | RW | Address of the input data, as seen by the CPU |
| `0x10` | PTR_OUT | RW | Address of the output data, as seen by the CPU |
| `0x14` | RT_STATUS | W (reads 0) | Runtime only: DONE or ERROR, accepted only in BUSY |

Any other offset answers SLVERR.
The host driver does not write STATUS and does not know RT_STATUS: only the commands and the runtime change the state.

## Commands and states

| Command | Code | Effect |
| --- | --- | --- |
| RESET CPU | 1 | Stops the CPU (held in reset), to load a new program or new data: IDLE |
| LOAD PROGRAM | 2 | Tells that the host is writing the program and BOOT_ADDR |
| LOAD INPUT DATA | 3 | Tells that the host is writing the input data, PTR_IN and PTR_OUT |
| RUN | 4 | Starts the CPU from BOOT_ADDR: BUSY |
| RESET ALL | 5 | As the power-on: registers to their default, BUSY |
| HALT (OPTIONAL) | 6 | Suspends the CPU, RUN resumes it |

| State | Code |
| --- | --- |
| IDLE | 0 |
| BUSY | 1 |
| DONE | 2 |
| ERROR | 3 |
| HALT | 4 |

A command is the whole 32-bit word: any other value (for example `0x104`) is illegal.

Next state for each command (an illegal command leads to ERROR):

| State | RESET CPU | LOAD PROGRAM | LOAD INPUT DATA | RUN | RESET ALL | HALT |
| --- | --- | --- | --- | --- | --- | --- |
| BUSY | IDLE | ERROR | ERROR | ERROR | BUSY | HALT (*) |
| DONE | IDLE | ERROR | ERROR | ERROR | BUSY | ERROR |
| IDLE | ERROR | IDLE | IDLE | BUSY | BUSY | ERROR |
| HALT | IDLE | ERROR | ERROR | BUSY | BUSY | ERROR |
| ERROR | ERROR | ERROR | ERROR | ERROR | BUSY | ERROR |

(*) Only if the CSR is built with `HALT_EN = 1`. In the SoC `HALT_EN = 0`, so HALT leads to ERROR.

From BUSY, the runtime writes DONE or ERROR in RT_STATUS.
After the power-on reset Simply-V is in BUSY. RESET ALL is the only way out of ERROR.

## Effect on the SoC

- **CPU reset**: the CPU is held in reset only in IDLE. RUN releases it and the CPU starts from BOOT_ADDR.
  For the CPUs with MEM ports (CV32E40P, Ibex, PicoRV32), the reset goes through `mem_reset_guard` (`hw/xilinx/rtl/mem_reset_guard.sv`): a request already sent to the MEM-to-AXI bridge is completed and the CPU is released only when the bridges are idle, so RESET CPU is safe also while the CPU is using the bus.
- **Boot address**: BOOT_ADDR goes to the boot address input of the CPU.
- **RESET ALL**: the CSR registers go back to their default and the CPU is reset for 16 cycles. The reset of the whole SoC is not connected yet.

Not all the CPUs use the CSR outputs (`hw/xilinx/rtl/rv_socket.sv`):

| CPU | Reset from the CSR | Boot address from the CSR |
| --- | --- | --- |
| CV32E40P, Ibex, CV64A6 | yes | yes |
| PicoRV32 | yes | no |
| MicroBlaze-V | no (reset from the debug module) | no |

## Drivers

Host (`simplyv_csr_host.h`):

| Function | Description |
| --- | --- |
| `csr_status()` | Read STATUS |
| `csr_reset_cpu()` | RESET CPU |
| `csr_load_program(boot_addr)` | LOAD PROGRAM, then BOOT_ADDR |
| `csr_load_input_data(ptr_in, ptr_out)` | LOAD INPUT DATA, then PTR_IN and PTR_OUT |
| `csr_run()` | RUN |
| `csr_wait(max_polls)` | Read STATUS until DONE or ERROR, or return `CSR_TIMEOUT` after `max_polls` reads |
| `csr_reset_all()` | RESET ALL |

Runtime (`simplyv_csr.h`):

| Function | Description |
| --- | --- |
| `csr_get_ptr_in()` | Read PTR_IN |
| `csr_get_ptr_out()` | Read PTR_OUT |
| `csr_done()` | Write DONE in RT_STATUS |
| `csr_error()` | Write ERROR in RT_STATUS |

The pointers are always addresses seen by the CPU: the host adds its own base (for the PS, `PS_M_AXI_GP0_BASEADDR`) to reach the same memory.

## Use cases

| Use case | Host sequence | Test on the PS |
| --- | --- | --- |
| UC1: load and run a program | RESET CPU, LOAD PROGRAM (copy the `.bin` at BOOT_ADDR), LOAD INPUT DATA, RUN, wait DONE | `sw/host/zynq/ps_csr_uc1` |
| UC2: same program, new data | RESET CPU, LOAD INPUT DATA, RUN, wait DONE | `sw/host/zynq/ps_csr_uc2` |
| UC3: stuck program | wait ends with `CSR_TIMEOUT` in BUSY, then RESET CPU | `sw/host/zynq/ps_csr_uc3` |
| UC4: illegal command | a command in the wrong state (LOAD PROGRAM in BUSY): ERROR | `sw/host/zynq/ps_csr_uc4` |
| UC5: recovery from ERROR | from ERROR: RESET CPU is ignored, RESET ALL (BUSY), then as UC1 | `sw/host/zynq/ps_csr_uc5` |

The program is loaded as its memory image (`.bin`, from `make -C sw/SoC/examples/<program>`), not as the ELF: `build_ps_app.py` turns it into `cpu_program.h` for the PS program.
Each test has a README with the build, the run and the expected output.
`ci/hil_csr_suite_wsl.sh` runs all of them in a row on the Pynq-Z1 and prints PASS or FAIL for each one.
These are functional tests: on the board one illegal command is enough, all the combinations of state and command are tested in simulation (`tb_csr_fsm`).

## Simulation

```
vivado -mode batch -source <abs path>/hw/xilinx/sim/tb/run_csr_tb.tcl
```
It runs the CSR testbenches (`tb_csr_*`, with the AXI VIP) and the `mem_reset_guard` testbench.
