#!/bin/bash
# =============================================================================
# Simply-V — CSR test suite on the Zynq-7000 PS (Pynq-Z1) from WSL
#
# For each test sw/host/zynq/ps_csr_uc<N>: resets the system, programs the
# bitstream, initializes the PS and runs the PS program on the Cortex-A9 #0
# with XSDB (xsdb_run_elf.tcl), then checks the PS UART for "[PS] Test passed".
# The PS program loads the CPU program by itself through the CSR, so GDB,
# OpenOCD and usbipd are not needed. Each test starts from the power-on state.
#
# Usage (from the repository root, after `source settings.sh zynq`, with the
# bitstream and the programs already built, see sw/host/zynq/ps_csr_uc1/README.md):
#   bash ci/hil_csr_suite_wsl.sh [TEST ...]       # default: all ps_csr_uc*
#
# Environment (default in brackets). Paths for XSDB are Windows paths:
#   REPO_WIN          repository root [wslpath -m of the current directory]
#   XILINX_BITSTREAM  bitstream [$REPO_WIN/hw/xilinx/build/simplyv.runs/impl_1/simplyv.bit]
#   PS7_INIT          ps7_init.tcl [the one of the build]
#   PS_ELF            PS ELF, {T} is the test name [$REPO_WIN/sw/host/zynq/{T}/bin/{T}/build/{T}.elf]
#   XSDB_BAT          xsdb.bat [C:\AMDDesignTools\2025.2\Vivado\bin\xsdb.bat]
#   PS_UART           serial port of the PS UART on Windows [COM4]
#   CPU_UART          serial port of the Simply-V UART in WSL, optional [/dev/ttyUSB0 if present]
#   TEST_TIMEOUT      seconds for each test [60]
# The PS UART must not be open in another program.
# =============================================================================
set -u
set -o pipefail

REPO_WIN="${REPO_WIN:-$(wslpath -m "$PWD")}"
XILINX_BITSTREAM="${XILINX_BITSTREAM:-$REPO_WIN/hw/xilinx/build/simplyv.runs/impl_1/simplyv.bit}"
PS7_INIT="${PS7_INIT:-$REPO_WIN/hw/xilinx/build/simplyv.gen/sources_1/ip/xlnx_ps_wrapper/src/xlnx_ps_wrapper_bd_ps7_0/ps7_init.tcl}"
# (not with ${PS_ELF:-...}: the } of {T} would close the expansion)
[ -n "${PS_ELF:-}" ] || PS_ELF="$REPO_WIN/sw/host/zynq/{T}/bin/{T}/build/{T}.elf"
XSDB_BAT="${XSDB_BAT:-C:\\AMDDesignTools\\2025.2\\Vivado\\bin\\xsdb.bat}"
PS_UART="${PS_UART:-COM4}"
CPU_UART="${CPU_UART:-/dev/ttyUSB0}"
TEST_TIMEOUT="${TEST_TIMEOUT:-60}"
LOG_DIR=/tmp/csr_suite
CPU_UART_PID=""

cleanup() {
    [ -n "$CPU_UART_PID" ] && kill "$CPU_UART_PID" 2>/dev/null
    taskkill.exe /IM hw_server.exe /F >/dev/null 2>&1
}
trap cleanup EXIT

fail() { echo "[CSR] FAIL: $*"; exit 1; }

command -v taskkill.exe >/dev/null   || fail "taskkill.exe not found in PATH"
command -v powershell.exe >/dev/null || fail "powershell.exe not found in PATH"
mkdir -p "$LOG_DIR"

# Tests: from the arguments, or all the PS programs ps_csr_uc*
if [ $# -gt 0 ]; then
    TESTS="$*"
else
    TESTS="$(cd sw/host/zynq && ls -d ps_csr_uc* 2>/dev/null | sort | tr '\n' ' ')"
fi
[ -n "$TESTS" ] || fail "no test found in sw/host/zynq/ps_csr_uc*"
echo "[CSR] Tests: $TESTS"
echo "[CSR] Bitstream: $XILINX_BITSTREAM"

RESULTS=""
FAILED=0
for T in $TESTS; do
    ELF="${PS_ELF//\{T\}/$T}"
    PS_LOG="$LOG_DIR/${T}_ps.log"
    CPU_LOG="$LOG_DIR/${T}_cpu.log"
    XSDB_LOG="$LOG_DIR/${T}_xsdb.log"
    : > "$PS_LOG"; : > "$CPU_LOG"; : > "$XSDB_LOG"
    echo "[CSR] ===== $T ====="

    # Simply-V UART, if available
    CPU_UART_PID=""
    if [ -r "$CPU_UART" ]; then
        stty -F "$CPU_UART" 9600 cs8 -cstopb -parenb raw -echo 2>/dev/null
        cat "$CPU_UART" > "$CPU_LOG" &
        CPU_UART_PID=$!
    fi

    # PS UART: read until the end of the test or the timeout
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$REPO_WIN/ci/read_uart.ps1" \
        -Port "$PS_UART" -Timeout "$TEST_TIMEOUT" > "$PS_LOG" 2>&1 &
    PS_UART_PID=$!
    sleep 2

    # System reset, bitstream, PS init and PS program
    taskkill.exe /IM hw_server.exe /F >/dev/null 2>&1
    ( cd /mnt/c && \
      XILINX_HW_SERVER_HOST=127.0.0.1 XILINX_HW_SERVER_PORT=3121 \
      WSLENV=XILINX_HW_SERVER_HOST:XILINX_HW_SERVER_PORT \
      cmd.exe /c "$XSDB_BAT $REPO_WIN/hw/xilinx/scripts/load_binary/xsdb_run_elf.tcl - $XILINX_BITSTREAM $PS7_INIT $ELF" ) \
      > "$XSDB_LOG" 2>&1
    grep -q "Starting PS execution" "$XSDB_LOG" || echo "[CSR] XSDB did not start the PS program (see $XSDB_LOG)"

    wait "$PS_UART_PID"
    sleep 1
    [ -n "$CPU_UART_PID" ] && kill "$CPU_UART_PID" 2>/dev/null
    CPU_UART_PID=""

    tr -d '\r' < "$PS_LOG" | sed 's/^/    /'
    if grep -q "\[PS\] Test passed" "$PS_LOG"; then
        RESULTS="$RESULTS$T PASS\n"
    else
        RESULTS="$RESULTS$T FAIL\n"
        FAILED=$((FAILED + 1))
    fi
done

echo "[CSR] ===== Results (logs in $LOG_DIR) ====="
printf "$RESULTS" | sed 's/^/[CSR]   /'
if [ "$FAILED" -ne 0 ]; then
    fail "$FAILED test(s) failed"
fi
echo "[CSR] PASS"
