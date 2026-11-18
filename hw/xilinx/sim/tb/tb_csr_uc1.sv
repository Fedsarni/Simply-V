// Author: Federica Sarnataro
// Description: UC1 - Load and run program.
//              RESET CPU -> LOAD PROGRAM -> LOAD INPUT DATA -> RUN -> runtime DONE,
//              first after the PoR (BUSY), then again from DONE.
`timescale 1ns/1ps

module tb_csr_uc1;
    `include "tb_csr_common.svh"

    initial begin
        tb_start();

        for (int i = 0; i < 2; i++) begin
            automatic string ctx = (i == 0) ? "UC1 from BUSY" : "UC1 from DONE";
            check_status({ctx, " precondition"}, (i == 0) ? BUSY : DONE);

            cmd(RESET_CPU);        check_status({ctx, " RESET CPU"}, IDLE);        check_outputs(IDLE, ctx);
            cmd(LOAD_PROGRAM);     wr_reg(A_BOOT, 32'h0000_2000 + i);
            check_status({ctx, " LOAD PROGRAM"}, IDLE);
            check({ctx, " boot_addr_o"}, boot_addr, 32'h0000_2000 + i);
            cmd(LOAD_INPUT_DATA);  wr_reg(A_PIN, 32'h1000_0000 + i); wr_reg(A_POUT, 32'h1000_1000 + i);
            check_status({ctx, " LOAD INPUT DATA"}, IDLE);
            cmd(RUN);              check_status({ctx, " RUN"}, BUSY);              check_outputs(BUSY, ctx);

            // Runtime: reads the pointers, then writes DONE
            check_reg(ctx, A_PIN,  32'h1000_0000 + i);
            check_reg(ctx, A_POUT, 32'h1000_1000 + i);
            rt(DONE);              check_status({ctx, " runtime DONE"}, DONE);     check_outputs(DONE, ctx);
        end

        tb_finish("UC1");
    end
endmodule
