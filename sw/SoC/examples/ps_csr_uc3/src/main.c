// Author: Federica Sarnataro
// Description:
//   CPU side of the CSR test UC3 (Zynq profile): a stuck program.
//   The program is copied by the PS at the boot address and started with RUN, then it
//   increments a counter at PTR_OUT forever and never writes DONE.
//   The PS side is sw/host/zynq/ps_csr_uc3.

#include "simplyv.h"
#include <stdint.h>
#include "ps_csr_uc3.h"

int main()
{
    // Initialize HAL
    simplyv_init();

    volatile uint32_t * counter = (volatile uint32_t *)csr_get_ptr_out();

    // Only one print, then count at once: the UART is slow
    printf("[CPU] Start (UC3: stuck program), counting forever at PTR_OUT 0x%08x\n\r",
           (uint32_t)(uintptr_t)counter);

    while (1) {
        *counter = *counter + 1;
    }

    return SIMPLYV_OK;
}
