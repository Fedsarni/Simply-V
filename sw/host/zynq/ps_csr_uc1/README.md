# PS CSR UC1 (Zynq-7000)

PS side of the CSR test UC1 (point 4: load and run program), without GDB and OpenOCD.
The program runs bare-metal on the Cortex-A9 #0 of the Zynq-7000 PS and drives Simply-V through the CSR (`hw/xilinx/rtl/simplyv_csr.sv`), reached through `M_AXI_GP0`, with the host driver `sw/host/zynq/lib/simplyv_csr_host.h`.
The CPU side is in `sw/SoC/examples/ps_csr_uc1`.

The PS loads the CPU program itself, as the memory image (`.bin`) and not as the ELF:
`build_ps_app.py` turns `sw/SoC/examples/ps_csr_uc1/bin/ps_csr_uc1.bin` into `cpu_program.h`, an array of 32-bit words.
Then:
1. the PS sends RESET CPU and checks that STATUS is IDLE;
2. the PS sends LOAD PROGRAM with the boot address (start of `BRAM_0`), copies the program there and reads it back;
3. the PS writes the input value and sends LOAD INPUT DATA with PTR_IN and PTR_OUT;
4. the PS sends RUN, the CPU starts from the boot address, writes the bitwise NOT at PTR_OUT and writes DONE in RT_STATUS;
5. the PS waits for DONE and checks the output.

The CSR controls the reset of the CPU only with `CORE_CV32E40P` (and the other CPUs with a reset from `rv_socket`), not with `CORE_MICROBLAZEV_RV32`.

## Build

Requirements: Simply-V configured and built for the `zynq` profile with `CORE_CV32E40P`.

Build the CPU program first, since the PS program includes its `.bin`:
```
make -C sw/SoC/examples/ps_csr_uc1
```

Then build the PS program with the Vitis Python API:
```
vitis -s sw/host/zynq/build_ps_app.py ps_csr_uc1
```
The ELF is `sw/host/zynq/ps_csr_uc1/bin/ps_csr_uc1/build/ps_csr_uc1.elf`.

## Run

1. `make -C hw/xilinx program_bitstream`: after it, Simply-V is in BUSY and the CPU runs the default program in `BRAM_0`.
2. `xsdb hw/xilinx/scripts/load_binary/xsdb_run_elf.tcl - - - sw/host/zynq/ps_csr_uc1/bin/ps_csr_uc1/build/ps_csr_uc1.elf`

## Expected output

On the Simply-V UART:
```
[CPU] Start (program loaded by the PS)
[CPU] PTR_IN 0x00008000, PTR_OUT 0x00008004
[CPU] Read 0xcafe0125, wrote 0x3501feda
[CPU] RT_STATUS <- DONE
```

On the PS UART (115200 baud), with the size of the program in place of `<N>`:
```
[PS] CSR at 0x40060000, STATUS BUSY
[PS] RESET CPU       -> STATUS IDLE
[PS] LOAD PROGRAM    -> STATUS IDLE (<N> bytes at BOOT_ADDR 0x00000000, 0 errors on read back)
[PS] LOAD INPUT DATA -> STATUS IDLE (input 0xCAFE0125, PTR_IN 0x00008000, PTR_OUT 0x00008004)
[PS] RUN             -> STATUS BUSY
[PS] Wait            -> STATUS DONE
[PS] Output 0x3501FEDA at PTR_OUT
[PS] Test passed
```
