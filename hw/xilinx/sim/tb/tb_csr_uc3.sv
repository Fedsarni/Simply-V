// Author: Federica Sarnataro
// Description: UC3 - Stuck program: the master times out and stops the CPU.
`timescale 1ns/1ps

module tb_csr_uc3;
    `include "tb_csr_common.svh"

    initial begin : stim_proc
        tb_start();
        cmd(RESET_CPU);
        cmd(LOAD_PROGRAM);
        cmd(LOAD_INPUT_DATA);
        cmd(RUN);

        // Polling: the runtime never writes DONE
        repeat (5) begin
            rd(A_STATUS, v_data);
            assert (v_data == BUSY) else $error("[TB] polling: STATUS %0d, expected BUSY", v_data);
        end

        // Timeout of the master
        cmd(RESET_CPU);
        rd(A_STATUS, v_data);
        assert (v_data == IDLE) else $error("[TB] RESET CPU: STATUS %0d, expected IDLE", v_data);
        assert (core_rstn == 1'b0) else $error("[TB] RESET CPU: CPU not in reset");

        $finish;
    end : stim_proc
endmodule
