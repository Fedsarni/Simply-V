// Author: Federica Sarnataro
// Description: Complete test of simplyv_csr: every state x every command (table 6.1),
//              runtime writes to STATUS, registers and wrong offsets (SLVERR).
`timescale 1ns/1ps

module tb_csr_fsm;
    `include "tb_csr_common.svh"

    int          states[$];
    int          exp;
    logic [31:0] d;
    logic [1:0]  r;

    initial begin
        tb_start();

        // After the PoR
        check_status("PoR", BUSY);
        check_outputs(BUSY, "PoR");
        check_reg("PoR", A_BOOT, BOOT_RST);
        check("PoR boot_addr_o", boot_addr, BOOT_RST);

        states = '{BUSY, DONE, IDLE, ERROR};
        if (HALT_EN) states.push_back(HALTED);

        // Every state x every command code (0..15: unknown codes are illegal too)
        foreach (states[i]) begin
            for (int c = 0; c < 16; c++) begin
                goto(states[i]);
                cmd(c);
                if (c == RESET_ALL) wait_pulse();
                exp = expected(states[i], c);
                check_status($sformatf("state %0d cmd %0d", states[i], c), exp);
                check_outputs(exp, $sformatf("state %0d cmd %0d", states[i], c));
            end
        end
        // The whole word is the command: 0x104 is not RUN
        goto(IDLE); cmd(32'h0000_0104); check_status("cmd 0x104", ERROR);

        // Runtime writes to STATUS: only DONE or ERROR, only in BUSY
        foreach (states[i]) begin
            for (int v = 0; v < 8; v++) begin
                goto(states[i]);
                rt(v);
                exp = (states[i] == BUSY && (v == DONE || v == ERROR)) ? v : states[i];
                check_status($sformatf("state %0d STATUS <= %0d", states[i], v), exp);
            end
        end

        // Registers
        goto(IDLE);
        wr_reg(A_BOOT, 32'hDEAD_BEE0); wr_reg(A_PIN, 32'h1000_0000); wr_reg(A_POUT, 32'h1000_1000);
        check_reg("rw", A_BOOT, 32'hDEAD_BEE0);
        check("rw boot_addr_o", boot_addr, 32'hDEAD_BEE0);
        check_reg("rw", A_PIN,  32'h1000_0000);
        check_reg("rw", A_POUT, 32'h1000_1000);
        check_reg("COMMAND reads 0", A_CMD, 0);

        // Wrong offsets: SLVERR, no change
        axi_rd(32'h14, d, r);      check("read 0x14 SLVERR",  r, SLVERR);
        axi_wr(32'h40, 32'h5, r);  check("write 0x40 SLVERR", r, SLVERR);
        check_status("wrong offset no change", IDLE);

        // RESET ALL: registers back to default
        cmd(RESET_ALL); wait_pulse();
        check_reg("RESET ALL", A_BOOT, BOOT_RST);
        check_reg("RESET ALL", A_PIN,  0);
        check_reg("RESET ALL", A_POUT, 0);
        check_status("RESET ALL", BUSY);

        check("RESET ALL pulses seen", pulses > 0, 1);
        tb_finish("FSM");
    end
endmodule
