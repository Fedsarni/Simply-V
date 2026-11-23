// Author: Federica Sarnataro
// Description:
//   Runtime side of the Simply-V CSR (hw/xilinx/rtl/simplyv_csr.sv), for the CPU of Simply-V.
//   The runtime reads the data pointers written by the host and reports the end of the job.
//   The host side is in sw/host/zynq/ps_csr/src/simplyv_csr_host.h.

#ifndef __SIMPLYV_CSR_H__
#define __SIMPLYV_CSR_H__

#include <stdint.h>
#include "simplyv_conf.h"
#include "io.h"

// CSR base address
#define CSR_BASEADDR ((uintptr_t)_peripheral_CSR_start)

// Registers used by the runtime
#define CSR_PTR_IN    (CSR_BASEADDR + 0x0Cu) // Pointer to the input data
#define CSR_PTR_OUT   (CSR_BASEADDR + 0x10u) // Pointer to the output data
#define CSR_RT_STATUS (CSR_BASEADDR + 0x14u) // End of the job, accepted only in BUSY

// Values for RT_STATUS, same codes as STATUS
#define CSR_RT_DONE  (2u)
#define CSR_RT_ERROR (3u)

// Read the pointer to the input data
static inline uintptr_t csr_get_ptr_in(void)
{
    return (uintptr_t)ioread32(CSR_PTR_IN);
}

// Read the pointer to the output data
static inline uintptr_t csr_get_ptr_out(void)
{
    return (uintptr_t)ioread32(CSR_PTR_OUT);
}

// End of the job: STATUS goes from BUSY to DONE
static inline void csr_done(void)
{
    iowrite32(CSR_RT_STATUS, CSR_RT_DONE);
}

// Error in the job: STATUS goes from BUSY to ERROR
static inline void csr_error(void)
{
    iowrite32(CSR_RT_STATUS, CSR_RT_ERROR);
}

#endif // __SIMPLYV_CSR_H__
