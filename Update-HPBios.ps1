[CmdletBinding()]

param (
    [Parameter(Mandatory=$True)][string[]]$ComputerName,
    [Parameter(Mandatory=$True)][string]$SourceDirectory
)

foreach($computer in $ComputerName) {

    # Check if host is online.
    if (-not (Test-Connection -ComputerName $computer -count 1 -quiet -ErrorAction SilentlyContinue)) {
        Write-verbose -Message "$Computer offline. Skipping to next host."
        continue
    }
    # Check and remove old BiosUpdate folder on target host.
    if (test-path -path "\\$Computer\C$\SWSetup\BiosUpdate") {
        remove-Item -Recurse -Force -path "\\$Computer\C$\SWSetup\BiosUpdate"
        Write-Verbose -Message "$Computer - Removed old files."
    }
    # Copy items to target machine's local drive.
    Copy-Item -Recurse -Force -Path "$SourceDirectory" -Destination "\\$Computer\C$\SWSetup\BiosUpdate"
    Write-Verbose -Message "$Computer - Copied files."

    # Establish PowerShell session with target host.
    try {
        $session = New-PSSession -ComputerName $computer
    } catch {
        write-verbose -message "Error establishing PowerShell session with $computer. Skipping to next host."
        continue
    }

    # TODO - Device model and BIOS version checks.

    # Run HP Firmware Update executable.
    Invoke-Command -Session $session -ScriptBlock {
        start-process -filepath "C:\SWSetup\BiosUpdate\HPFirmwareUpdRec64.exe" `
                      -ArgumentList "-s","-pC:\SWSetup\BiosUpdate\pass.key","-fC:\SWSetup\BiosUpdate","-b","-r" `
                      -Wait
    } 
    Write-Verbose -Message "$Computer - BIOS update complete. Cleaning up session."
    
    # Close PowerShell session.
    $session | Remove-PSSession
}




# NOTES
# & .\HpqPswd64.exe /f"Password.key" /p"passwordhere" /s
# Must be ran as admin and not while remoted into another machine; double hop issues if you do.

#region - Live computers
# Write-Verbose -Message "Computer names input: $ComputerName"
# $liveComputers = @()
# foreach ($computer in $ComputerName) {
#     if (Test-Connection -ComputerName $computer -count 1 -quiet -ErrorAction SilentlyContinue) {
#         $liveComputers += $computer
#         Write-Verbose -Message "$Computer added to list of live hosts."
#     }
# }
#endregion

# REFERENCES
# HP Download Library: https://www.hp.com/us-en/solutions/client-management-solutions/download.html
# https://www.configjon.com/hp-bios-settings-management/