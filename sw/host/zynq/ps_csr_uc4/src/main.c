// PS side of the CSR test UC4 (Zynq profile, point 4): illegal command.
// After the power-on Simply-V is in BUSY. The Cortex-A9 #0 sends LOAD PROGRAM, which is legal
// only in IDLE: the CSR must answer with STATUS = ERROR. The recovery from ERROR is UC5.
// There is no CPU program: the CPU only has to be running (BUSY), as after the power-on.
// All the combinations of state and command are tested in simulation (tb_csr_fsm).
#include <stdint.h>
#include "xil_printf.h"
#include "simplyv_csr_host.h"

// Name of a state, for the prints
static const char *state_name(uint32_t status)
{
    switch (status) {
        case CSR_ST_IDLE:  return "IDLE";
        case CSR_ST_BUSY:  return "BUSY";
        case CSR_ST_DONE:  return "DONE";
        case CSR_ST_ERROR: return "ERROR";
        case CSR_ST_HALT:  return "HALT";
        default:           return "UNKNOWN";
    }
}

int main(void)
{
    uint32_t status;

    // Precondition: BUSY, as after the power-on
    status = csr_status();
    xil_printf("[PS] CSR at 0x%08x, STATUS %s\r\n", (uint32_t)CSR_HOST_BASEADDR, state_name(status));
    if (status != CSR_ST_BUSY) {
        xil_printf("[PS] ERROR: expected BUSY\r\n");
        return 1;
    }

    // Illegal command: LOAD PROGRAM in BUSY
    csr_load_program((uint32_t)_peripheral_BRAM_0_start);
    status = csr_status();
    xil_printf("[PS] LOAD PROGRAM in BUSY (illegal) -> STATUS %s\r\n", state_name(status));
    if (status != CSR_ST_ERROR) {
        xil_printf("[PS] ERROR: expected ERROR\r\n");
        return 1;
    }

    xil_printf("[PS] Test passed\r\n");
    return 0;
}
