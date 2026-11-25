# Author: Federica Sarnataro
# Description: Print what arrives on a serial port, until "[PS] Test passed" or "[PS] ERROR:"
#              (plus half a second for the last lines) or until the timeout.
#              Used by ci/hil_csr_suite_wsl.sh for the PS UART.
param(
    [string]$Port    = "COM4",
    [int]   $Baud    = 115200,
    [int]   $Timeout = 60
)

$p = New-Object System.IO.Ports.SerialPort $Port, $Baud, None, 8, One
$p.Open()
$text = ""
$end  = (Get-Date).AddSeconds($Timeout)
try {
    while ((Get-Date) -lt $end) {
        $s = $p.ReadExisting()
        if ($s) {
            [Console]::Out.Write($s)
            $text += $s
        }
        if ($text.Contains("[PS] Test passed") -or $text.Contains("[PS] ERROR:")) {
            Start-Sleep -Milliseconds 500
            [Console]::Out.Write($p.ReadExisting())
            break
        }
        Start-Sleep -Milliseconds 100
    }
} finally {
    $p.Close()
}
