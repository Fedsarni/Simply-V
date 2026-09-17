# =============================================================================
# Simply-V — UART output checker (used by the CI HIL job)
#
# Opens the given serial port, listens for the specified number of seconds,
# and checks whether the expected string (e.g. "Hello World") appears in
# the captured output. Exits 0 on success, 1 on timeout/failure.
# =============================================================================

param(
    [Parameter(Mandatory=$true)][string]$Port,
    [int]$Baud = 9600,
    [int]$TimeoutSeconds = 10,
    [Parameter(Mandatory=$true)][string]$Expected
)

Write-Host "[CI] Opening $Port at $Baud baud, listening for '$Expected' (timeout ${TimeoutSeconds}s)..."

$serial = New-Object System.IO.Ports.SerialPort $Port, $Baud, None, 8, One
$serial.ReadTimeout = 1000
$serial.Open()

$buffer = ""
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)

while ((Get-Date) -lt $deadline) {
    try {
        $chunk = $serial.ReadExisting()
        if ($chunk) {
            $buffer += $chunk
            Write-Host -NoNewline $chunk
        }
    } catch {
        # ReadExisting shouldn't throw, but guard anyway
    }
    if ($buffer -match [regex]::Escape($Expected)) {
        Write-Host ""
        Write-Host "[CI] Found expected string. PASS."
        $serial.Close()
        exit 0
    }
    Start-Sleep -Milliseconds 200
}

$serial.Close()
Write-Host ""
Write-Host "[CI] Timeout reached, expected string not found. FAIL."
Write-Host "[CI] Captured output was:"
Write-Host $buffer
exit 1
