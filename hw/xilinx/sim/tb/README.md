# simplyv_csr testbenches

Testbenches of `hw/xilinx/rtl/simplyv_csr.sv`, simulated with Vivado xsim.
The AXI VIP is the AXI4-Lite master and plays both the host and the runtime.

| Testbench    | Content |
|--------------|---------|
| `tb_csr_uc1` | UC1 Load and run program (after the PoR and from DONE) |
| `tb_csr_uc2` | UC2 New input data |
| `tb_csr_uc3` | UC3 Stuck program |
| `tb_csr_uc4` | UC4 Illegal command |
| `tb_csr_uc5` | UC5 Recovery from ERROR |
| `tb_csr_fsm` | Every state x every command, runtime writes to RT_STATUS, registers, SLVERR |

`tb_csr_common.svh` holds the AXI VIP, the DUT and the common tasks.

Run all the testbenches (or only some, with `-tclargs`):

```
source settings.sh <profile>
vivado -mode batch -source $(pwd)/hw/xilinx/sim/tb/run_csr_tb.tcl
vivado -mode batch -source $(pwd)/hw/xilinx/sim/tb/run_csr_tb.tcl -tclargs tb_csr_uc1 tb_csr_uc4
```
