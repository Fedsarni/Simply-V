// Author: Federica Sarnataro
// Description:
//   CPU side of the CSR test UC5 (Zynq profile): after the recovery from ERROR,
//   this program is copied by the PS at the boot address and started with RUN.
//   1. Read PTR_IN and PTR_OUT from the CSR
//   2. Read the input value, write its bitwise NOT at PTR_OUT
//   3. Write DONE in RT_STATUS, then stop in WFI
//   The PS side is sw/host/zynq/ps_csr_uc5.

#include "simplyv.h"
#include <stdint.h>
#include "ps_csr_uc5.h"

int main()
{
    // Initialize HAL
    simplyv_init();

    printf("[CPU] Start (UC5: after RESET ALL)\n\r");

    uintptr_t ptr_in  = csr_get_ptr_in();
    uintptr_t ptr_out = csr_get_ptr_out();
    printf("[CPU] PTR_IN 0x%08x, PTR_OUT 0x%08x\n\r", (uint32_t)ptr_in, (uint32_t)ptr_out);

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
