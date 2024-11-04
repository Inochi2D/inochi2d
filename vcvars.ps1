#
# This file must be used by invoking ". .\activate.ps1" from the command line.
# You cannot run it directly.
#

if ($MyInvocation.CommandOrigin -eq 'runspace') {
    Write-Host -f Red "This script cannot be invoked directly."
    Write-Host -f Red "To function correctly, this script file must be 'dot sourced' by calling `". $PSCommandPath`" (notice the dot at the beginning)."
    exit 1
}

function Find-DevShellLauncherPath {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $installationPath = & $vswhere -prerelease -legacy -latest -property installationPath
    return Join-Path $installationPath "Common7\Tools\Launch-VsDevShell.ps1" # Since we are running under Powershell
}

# this dot is criticial to devshell script to update our environment
. $(Find-DevShellLauncherPath) @PSBoundParameters

# Developer PowerShell don't have "No Logo" mode