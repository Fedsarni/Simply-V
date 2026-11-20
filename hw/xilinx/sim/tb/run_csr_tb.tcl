# Author: Federica Sarnataro
# Description: Run the simplyv_csr testbenches in Vivado xsim, with the AXI VIP as AXI4-Lite master.
# Usage:
#   vivado -mode batch -source <abs path>/hw/xilinx/sim/tb/run_csr_tb.tcl                        (all the testbenches)
#   vivado -mode batch -source <abs path>/hw/xilinx/sim/tb/run_csr_tb.tcl -tclargs tb_csr_uc1     (only some)
# The project is created in hw/xilinx/sim/tb/build. Exit code 1 if a testbench fails.
# A testbench passes if it reaches $finish and no assertion fails.

set tb_dir      [file dirname [file normalize [info script]]]
set xilinx_root [file normalize ${tb_dir}/../..]

# Testbenches to run
set all_tbs [lsort [lmap f [glob ${tb_dir}/tb_csr_*.sv] {file rootname [file tail $f]}]]
set tbs [expr {[llength $argv] > 0 ? $argv : $all_tbs}]

# Part: from settings.sh if available (the simulation does not depend on it)
set part xc7z020clg400-1
if {[info exists ::env(XILINX_PART_NUMBER)]} { set part $::env(XILINX_PART_NUMBER) }

create_project csr_tb ${tb_dir}/build -force -part ${part}

# DUT
add_files -norecurse ${xilinx_root}/rtl/simplyv_csr.sv
set_property include_dirs [list ${xilinx_root}/rtl/headers ${tb_dir}] [get_filesets sources_1]
set_property include_dirs [list ${xilinx_root}/rtl/headers ${tb_dir}] [get_filesets sim_1]

# AXI VIP master, AXI4-Lite 32 bit
create_ip -name axi_vip -vendor xilinx.com -library ip -module_name axi_vip_mst
set_property -dict [list \
    CONFIG.INTERFACE_MODE {MASTER}   \
    CONFIG.PROTOCOL       {AXI4LITE} \
    CONFIG.ADDR_WIDTH     {32}       \
    CONFIG.DATA_WIDTH     {32}       \
    CONFIG.HAS_PROT       {1}        \
    CONFIG.HAS_WSTRB      {1}        \
] [get_ips axi_vip_mst]
generate_target all [get_ips axi_vip_mst]

# Testbenches
add_files -fileset sim_1 -norecurse [glob ${tb_dir}/tb_csr_*.sv]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

# Run each testbench: PASS if it reaches $finish without errors in the log
set results {}
set failed 0
foreach tb ${tbs} {
    set_property top ${tb} [get_filesets sim_1]
    set result "RESULT ${tb}: simulation error -> FAIL"
    if {![catch {launch_simulation} msg]} {
        set log ${tb_dir}/build/csr_tb.sim/sim_1/behav/xsim/simulate.log
        set errors   0
        set finished 0
        set f [open ${log} r]
        foreach line [split [read ${f}] "\n"] {
            if {[regexp {^Error:|\[TB\]|^ERROR|Fatal} ${line}]} {
                puts "${tb}> ${line}"
                incr errors
            }
            if {[regexp {\$finish called} ${line}]} {
                set finished 1
            }
        }
        close ${f}
        close_sim -force
        if {!${finished}} {
            set result "RESULT ${tb}: \$finish not reached -> FAIL"
        } else {
            set result "RESULT ${tb}: ${errors} errors -> [expr {${errors} == 0 ? "PASS" : "FAIL"}]"
        }
    }
    if {![regexp { -> PASS$} ${result}]} { set failed 1 }
    lappend results ${result}
}

puts "\n==== simplyv_csr testbenches ===="
foreach r ${results} { puts ${r} }
exit ${failed}
