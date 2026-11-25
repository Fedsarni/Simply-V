// Author: Federica Sarnataro
// Description:
//   Data shared between the Zynq-7000 PS and the Simply-V CPU in the CSR test UC5, in BRAM_0.
//   Used by sw/SoC/examples/ps_csr_uc5 (CPU side) and sw/host/zynq/ps_csr_uc5 (PS side).
//   The CPU program is at the boot address (start of BRAM_0), the data after it at
//   _peripheral_BRAM_0_start + PS_CSR_DATA_OFFSET, as in ps_csr_uc1.

#ifndef PS_CSR_UC5_H
#define PS_CSR_UC5_H

// Offset of the data from the base of BRAM_0: the CPU program must end before it
#define PS_CSR_DATA_OFFSET (0x8000u)

// Data words (32-bit), in order
enum {
    PS_CSR_IN = 0, // PS : input value
    PS_CSR_OUT,    // CPU: output value (bitwise NOT of PS_CSR_IN)
    PS_CSR_NUM_WORDS
};

// Value written by the PS
#define PS_CSR_TEST_VALUE (0xCAFE0128u)

#endif // PS_CSR_UC5_H
