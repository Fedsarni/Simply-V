// Author: Federica Sarnataro
// Description:
//   CPU side of the CSR test (Zynq profile).
//   1. Read PTR_IN and PTR_OUT from the CSR
//   2. Read the input value, write its bitwise NOT at PTR_OUT
//   3. Write DONE in RT_STATUS, then stop in WFI
//   The PS side is sw/host/zynq/ps_csr.

#include "simplyv.h"
#include <stdint.h>
#include "ps_csr.h"

int main()
{
    // Initialize HAL
    simplyv_init();

    printf("[CPU] Start\n\r");

    uintptr_t ptr_in  = csr_get_ptr_in();
    uintptr_t ptr_out = csr_get_ptr_out();
    printf("[CPU] PTR_IN 0x%08x, PTR_OUT 0x%08x\n\r", (uint32_t)ptr_in, (uint32_t)ptr_out);

    // First start after loading with GDB: the PS has not written the pointers yet.
    // Stop in WFI without writing to memory, the PS will send RESET CPU and RUN
    if ( (ptr_in == 0) || (ptr_out == 0) ) {
        printf("[CPU] No pointers from the PS, waiting\n\r");
        return SIMPLYV_OK;
    }

    volatile uint32_t * in  = (volatile uint32_t *)ptr_in;
    volatile uint32_t * out = (volatile uint32_t *)ptr_out;
    uint32_t value = *in;

    // Answer with the bitwise NOT
    *out = ~value;
    printf("[CPU] Read 0x%08x, wrote 0x%08x\n\r", value, ~value);

    // Tell the PS as the last step: after DONE the PS can reset the CPU at any time
    printf("[CPU] RT_STATUS <- DONE\n\r");
    csr_done();

    // Return to caller (WFI)
    return SIMPLYV_OK;
}
