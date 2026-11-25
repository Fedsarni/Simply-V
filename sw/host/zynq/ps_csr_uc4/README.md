# PS CSR UC4 (Zynq-7000)

PS side of the CSR test UC4 (point 4: illegal command and recovery), without GDB and OpenOCD.
The CPU side is in `sw/SoC/examples/ps_csr_uc4`: the same job as in `ps_csr_uc1`.

The PS:
1. sends LOAD PROGRAM in BUSY, an illegal command, and checks that STATUS is ERROR;
2. sends RESET CPU and checks that STATUS stays ERROR;
3. sends RESET ALL, the only way out of ERROR, and checks that STATUS is BUSY;
4. loads and runs the CPU program as in `ps_csr_uc1`, to show that Simply-V works again.

## Build and run

As in `sw/host/zynq/ps_csr_uc1/README.md`, with `ps_csr_uc4` in place of `ps_csr_uc1`.

## Expected output

On the Simply-V UART:
```
[CPU] Start (UC4: after RESET ALL)
[CPU] PTR_IN 0x00008000, PTR_OUT 0x00008004
[CPU] Read 0xcafe0127, wrote 0x3501fed8
[CPU] RT_STATUS <- DONE
```

On the PS UART (115200 baud), with the size of the program in place of `<N>`:
```
[PS] CSR at 0x40060000, STATUS BUSY
[PS] LOAD PROGRAM in BUSY (illegal) -> STATUS ERROR
[PS] RESET CPU in ERROR             -> STATUS ERROR
[PS] RESET ALL                      -> STATUS BUSY
[PS] --- Load and run after the recovery ---
[PS] RESET CPU       -> STATUS IDLE
[PS] LOAD PROGRAM    -> STATUS IDLE (<N> bytes at BOOT_ADDR 0x00000000, 0 errors on read back)
[PS] LOAD INPUT DATA -> STATUS IDLE (input 0xCAFE0127, PTR_IN 0x00008000, PTR_OUT 0x00008004)
[PS] RUN             -> STATUS BUSY
[PS] Wait            -> STATUS DONE
[PS] Output 0x3501FED8 at PTR_OUT
[PS] Test passed
```
