[CmdletBinding()]

param (
    [Parameter(Mandatory=$True)][string[]]$ComputerName,
    [string]$SourceDirectory = 'C:\SWSetup\SP136575'
)

#region - Live computers
Write-Verbose -Message "Computer names input: $ComputerName"
$liveComputers = @()
foreach ($computer in $ComputerName) {
    if (Test-Connection -ComputerName $computer -count 1 -quiet -ErrorAction SilentlyContinue) {
        $liveComputers += $computer
        Write-Verbose -Message "$Computer added to list of live hosts."
    }
}
#endregion

#region - Copy files to remote computers
#Note: couldnt figure out how to implement this in the script block due to double-hop issues with permissions to network shares
foreach($computer in $liveComputers) {
    if (test-path -path "\\$Computer\C$\SWSetup\BiosUpdate") {
        remove-Item -Recurse -Force -path "\\$Computer\C$\SWSetup\BiosUpdate"
    }
    Copy-Item -Recurse -Force -Path "$SourceDirectory" -Destination "\\$Computer\C$\SWSetup\BiosUpdate"
    Write-Verbose -Message "$Computer - Copied files."
}
#endregion


$ScriptBlock = {
    $VerbosePreference='Continue'

    #region - Registry fix????
    $RegistryPath = 'HKLM:\Software\Microsoft\Cryptography\Protect\Providers\df9d8cd0-1501-11d1-8c7a-00c04fc297eb'
    Get-Item -Path $RegistryPath | New-ItemProperty -Name ProtectionPolicy -Value 1 -PropertyType dword
    #endregion

    $Command = "C:\SWSetup\BiosUpdate\HPFirmwareUpdRec64.exe -s -pPassword.key -fC:\SWSetup\BiosUpdate -r -b"
    write-Verbose -message "Command: $Command"
    Invoke-Expression -command $Command -Verbose
    start-sleep -seconds 20  

}

Invoke-Command -ComputerName $liveComputers -ScriptBlock $ScriptBlock -ThrottleLimit 1
# & .\HpqPswd64.exe /f"c:\Password.key" /p"passwordhere" /s



# NOTES
# Using the HP Bios Setup Password (HpqPswd64.exe), create a password file. Set working directory to the extracted
# directory before executing the command. It will create the Password.key file in the same directory.
# Example: & .\HpqPswd64.exe /f"Password.key" /p"passwordhere" /s


# REFERENCES
# HP Download Library: https://www.hp.com/us-en/solutions/client-management-solutions/download.html
# https://www.configjon.com/hp-bios-settings-management/