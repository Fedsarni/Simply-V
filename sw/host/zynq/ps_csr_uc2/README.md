# PS CSR UC2 (Zynq-7000)

PS side of the CSR test UC2 (point 4: same program, new input data), without GDB and OpenOCD.
The CPU side is in `sw/SoC/examples/ps_csr_uc2`: the same job as in `ps_csr_uc1`.

The PS loads the CPU program once, as in `ps_csr_uc1`, then runs it 3 times:
1. the first run starts from IDLE, right after LOAD PROGRAM;
2. the next runs start from DONE: RESET CPU, LOAD INPUT DATA with a new input value, RUN, wait for DONE, without loading the program again.

## Build and run

As in `sw/host/zynq/ps_csr_uc1/README.md`, with `ps_csr_uc2` in place of `ps_csr_uc1`, or with the whole CSR test suite (`ci/hil_csr_suite_wsl.sh`).

## Expected output

On the Simply-V UART, for each run (input `0xcafe0123`, `0xcafe0124`, `0xcafe0125`):
```
[CPU] Start (UC2)
[CPU] PTR_IN 0x00008000, PTR_OUT 0x00008004
[CPU] Read 0xcafe0123, wrote 0x3501fedc
[CPU] RT_STATUS <- DONE
```

On the PS UART (115200 baud), with the size of the program in place of `<N>`:
```
[PS] CSR at 0x40060000
[PS] --- Run 0, STATUS BUSY ---
[PS] RESET CPU       -> STATUS IDLE
[PS] LOAD PROGRAM    -> STATUS IDLE (<N> bytes at BOOT_ADDR 0x00000000, 0 errors on read back)
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
[PS] --- Run 2, STATUS DONE ---
...
[PS] Output 0x3501FEDA at PTR_OUT
[PS] Test passed
```
