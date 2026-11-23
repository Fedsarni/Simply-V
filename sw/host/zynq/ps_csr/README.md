# PS CSR (Zynq-7000)

PS side of the CSR test (point 4, UC2: same program, new input data).
The program runs bare-metal on the Cortex-A9 #0 of the Zynq-7000 PS and drives Simply-V through the CSR (`hw/xilinx/rtl/simplyv_csr.sv`), reached through `M_AXI_GP0`.
The CPU side is in `sw/SoC/examples/ps_csr`.

The two drivers are header-only:
- host: `src/simplyv_csr_host.h` (Cortex-A9 #0);
- runtime: `sw/SoC/lib/simplyv/inc/simplyv_csr.h` (CPU of Simply-V).

The test runs the CPU program twice, first from BUSY (after GDB) and then from DONE:
1. the PS sends RESET CPU and checks that STATUS is IDLE;
2. the PS writes the input value in `BRAM_0` and sends LOAD INPUT DATA with PTR_IN and PTR_OUT;
3. the PS sends RUN, the CPU reads PTR_IN, writes the bitwise NOT at PTR_OUT and writes DONE in RT_STATUS;
4. the PS waits for DONE and checks the output.

The CSR controls the reset of the CPU only with `CORE_CV32E40P` (and the other CPUs with a reset from `rv_socket`), not with `CORE_MICROBLAZEV_RV32`.

## Build

Requirements: Simply-V configured and built for the `zynq` profile with `CORE_CV32E40P`.

Build the PS program with the Vitis Python API:
```
vitis -s sw/host/zynq/build_ps_app.py ps_csr
```
The ELF is `sw/host/zynq/ps_csr/bin/ps_csr/build/ps_csr.elf`.

Build the CPU program:
```
make -C sw/SoC/examples/ps_csr
```

## Run

Use the PL-first sequence in `hw/xilinx/doc/PROGRAM_LOADING.md`, with `EXAMPLE=ps_csr`:
1. `make -C hw/xilinx program_bitstream`
2. `make -C hw/xilinx openocd_run` and `make -C hw/xilinx gdb_run EXAMPLE=ps_csr GDB_MODE=detach`, then close OpenOCD
3. `xsdb hw/xilinx/scripts/load_binary/xsdb_run_elf.tcl - - - sw/host/zynq/ps_csr/bin/ps_csr/build/ps_csr.elf`

The PS-first sequence does not apply: the PS would send RUN before GDB loads the CPU program.

## Expected output

On the Simply-V UART:
```
[CPU] Start
[CPU] PTR_IN 0x00000000, PTR_OUT 0x00000000
[CPU] No pointers from the PS, waiting
[CPU] Start
[CPU] PTR_IN 0x00008000, PTR_OUT 0x00008004
[CPU] Read 0xcafe0123, wrote 0x3501fedc
[CPU] RT_STATUS <- DONE
[CPU] Start
[CPU] PTR_IN 0x00008000, PTR_OUT 0x00008004
[CPU] Read 0xcafe0124, wrote 0x3501fedb
[CPU] RT_STATUS <- DONE
```

On the PS UART (115200 baud):
```
[PS] CSR at 0x40060000
[PS] --- Run 0, STATUS BUSY ---
[PS] RESET CPU       -> STATUS IDLE
[PS] LOAD INPUT DATA -> STATUS IDLE (input 0xCAFE0123, PTR_IN 0x00008000, PTR_OUT 0x00008004)
[PS] RUN             -> STATUS BUSY
[PS] Wait            -> STATUS DONE
[PS] Output 0x3501FEDC at PTR_OUT
[PS] --- Run 1, STATUS DONE ---
[PS] RESET CPU       -> STATUS IDLE
[PS] LOAD INPUT DATA -> STATUS IDLE (input 0xCAFE0124, PTR_IN 0x00008000, PTR_OUT 0x00008004)
[PS] RUN             -> STATUS BUSY
[PS] Wait            -> STATUS DONE
[PS] Output 0x3501FEDB at PTR_OUT
[PS] Test passed
```
