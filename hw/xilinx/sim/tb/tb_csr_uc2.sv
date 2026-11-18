// Author: Federica Sarnataro
// Description: UC2 - New input data (same program).
//              From DONE: RESET CPU -> LOAD INPUT DATA -> RUN -> runtime DONE, BOOT_ADDR unchanged.
`timescale 1ns/1ps

module tb_csr_uc2;
    `include "tb_csr_common.svh"

    initial begin
        tb_start();

        // Precondition: program loaded and run once (UC1), Simply-V in DONE
        cmd(RESET_CPU); cmd(LOAD_PROGRAM); wr_reg(A_BOOT, 32'h0000_2000);
        cmd(LOAD_INPUT_DATA); wr_reg(A_PIN, 32'h1000_0000); wr_reg(A_POUT, 32'h1000_1000);
        cmd(RUN); rt(DONE);
        check_status("UC2 precondition", DONE);

        // New input data, twice
        for (int i = 1; i <= 2; i++) begin
            cmd(RESET_CPU);        check_status("UC2 RESET CPU", IDLE);
            cmd(LOAD_INPUT_DATA);  wr_reg(A_PIN, 32'h1000_0000 + 32'h100 * i); wr_reg(A_POUT, 32'h1000_1000 + 32'h100 * i);
            check_status("UC2 LOAD INPUT DATA", IDLE);
            cmd(RUN);              check_status("UC2 RUN", BUSY);
            check("UC2 boot_addr_o unchanged", boot_addr, 32'h0000_2000);
            check_reg("UC2", A_PIN,  32'h1000_0000 + 32'h100 * i);
            check_reg("UC2", A_POUT, 32'h1000_1000 + 32'h100 * i);
            rt(DONE);              check_status("UC2 runtime DONE", DONE);
        end

        tb_finish("UC2");
    end
endmodule
