[CmdletBinding()]

param (
    [Parameter(Mandatory=$True)][string[]]$ComputerName,
    [Parameter(Mandatory=$True)][string]$SourceDirectory,
    [int]$ThrottleLimit = 16
)

#region - Get live hosts
$LiveHosts = $ComputerName | ForEach-Object -Parallel {
    if (Test-Connection -ComputerName $_ -count 1 -quiet -ErrorAction SilentlyContinue) {
        return $_   #return computer name to LiveHosts list if responded to ping
    }
} -Throttlelimit $ThrottleLimit
#endregion

#region - Copy files to target computer local drive
$LiveHosts | ForEach-Object -Parallel {
    # Remove old bios update files
    if (test-path -path "\\$_\C$\SWSetup\BiosUpdate") {
        remove-Item -Recurse -Force -path "\\$_\C$\SWSetup\BiosUpdate"
        Write-host -Message "$_ - Removed old files."
    }
    # Copy bios update files
    Copy-Item -Recurse -Force -Path $Using:SourceDirectory -Destination "\\$_\C$\SWSetup\BiosUpdate"
} -Throttlelimit $ThrottleLimit
#endregion

#region - HP Firmware Update
Invoke-Command -ComputerName $LiveHosts -ScriptBlock {
    write-host "$ENV:COMPUTERNAME starting bios update."
    start-process -filepath "C:\SWSetup\BiosUpdate\HPFirmwareUpdRec64.exe" `
                  -ArgumentList "-s","-pC:\SWSetup\BiosUpdate\pass.key","-fC:\SWSetup\BiosUpdate","-b","-r" `
                  -Wait
    write-host "$ENV:COMPUTERNAME finished bios update."
} -ThrottleLimit $ThrottleLimit -AsJob
#endregion

break

foreach($computer in $LiveHosts) {

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
        remove-Item -Recurse -force -path 'c:\swsetup\biosupdate'
    } 
    Write-Verbose -Message "$Computer - BIOS update complete. Cleaning up session."
    
    # Close PowerShell session.
    $session | Remove-PSSession
}

#################################




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