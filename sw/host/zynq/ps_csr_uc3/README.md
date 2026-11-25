# PS CSR UC3 (Zynq-7000)

PS side of the CSR test UC3 (point 4: stuck program), without GDB and OpenOCD.
The CPU side is in `sw/SoC/examples/ps_csr_uc3`: it increments a counter at PTR_OUT forever and never writes DONE.

The PS loads and runs the CPU program as in `ps_csr_uc1`, then:
1. `csr_wait()` ends with a timeout, with STATUS still BUSY;
2. the PS checks that the CPU is still running: its counter moves;
3. the PS sends RESET CPU and checks that STATUS is IDLE and the CPU is stopped: its counter does not move.

## Build and run

As in `sw/host/zynq/ps_csr_uc1/README.md`, with `ps_csr_uc3` in place of `ps_csr_uc1`.

## Expected output

On the Simply-V UART:
```
[CPU] Start (UC3: stuck program), counting forever at PTR_OUT 0x00008004
```

On the PS UART (115200 baud), with the size of the program in place of `<N>` and the values of the counter in place of `<a>`, `<b>`, `<c>`:
```
[PS] CSR at 0x40060000, STATUS BUSY
[PS] RESET CPU       -> STATUS IDLE
[PS] LOAD PROGRAM    -> STATUS IDLE (<N> bytes at BOOT_ADDR 0x00000000, 0 errors on read back)
[PS] LOAD INPUT DATA -> STATUS IDLE (PTR_IN 0x00008000, PTR_OUT 0x00008004)
[PS] RUN             -> STATUS BUSY
[PS] Wait            -> TIMEOUT after 3000000 reads, STATUS BUSY
[PS] Counter of the CPU: <a> -> <b>
[PS] RESET CPU       -> STATUS IDLE, counter of the CPU: <c> -> <c>
[PS] Test passed
```
