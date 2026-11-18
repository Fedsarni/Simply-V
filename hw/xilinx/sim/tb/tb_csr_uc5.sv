// Author: Federica Sarnataro
// Description: UC5 - Recovery from ERROR.
//              In ERROR every command but RESET ALL is ignored; RESET ALL -> BUSY with registers at default.
//              ERROR is reached both with an illegal command and with a runtime error.
`timescale 1ns/1ps

module tb_csr_uc5;
    `include "tb_csr_common.svh"

    task automatic recover(string ctx);
        // Every command but RESET ALL is ignored, the runtime cannot leave ERROR
        for (int c = 0; c < 16; c++) begin
            if (c == RESET_ALL) continue;
            cmd(c);
            check_status($sformatf("%s cmd %0d ignored", ctx, c), ERROR);
        end
        rt(DONE);
        check_status({ctx, " runtime DONE ignored"}, ERROR);

        cmd(RESET_ALL);
        wait_pulse();
        check_status({ctx, " RESET ALL"}, BUSY);
        check_outputs(BUSY, ctx);
        check_reg(ctx, A_BOOT, BOOT_RST);
        check_reg(ctx, A_PIN,  0);
        check_reg(ctx, A_POUT, 0);
    endtask

    initial begin
        tb_start();

        // ERROR from an illegal command (UC4), with registers written before
        cmd(RESET_CPU); cmd(LOAD_PROGRAM); wr_reg(A_BOOT, 32'h0000_2000);
        cmd(LOAD_INPUT_DATA); wr_reg(A_PIN, 32'h1000_0000); wr_reg(A_POUT, 32'h1000_1000);
        cmd(HALT);
        check_status("UC5 illegal command", ERROR);
        recover("UC5 after illegal command");

        // ERROR from the runtime
        rt(ERROR);
        check_status("UC5 runtime ERROR", ERROR);
        recover("UC5 after runtime ERROR");

        check("UC5 RESET ALL pulses", pulses, 2);
        tb_finish("UC5");
    end
endmodule
