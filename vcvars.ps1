function Invoke-VSDevEnvironment {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
            $installationPath = & $vswhere -prerelease -legacy -latest -property installationPath
            $Command = Join-Path $installationPath "Common7\Tools\vsdevcmd.bat"
        & "${env:COMSPEC}" /s /c "`"$Command`" -no_logo && set" | Foreach-Object {
                if ($_ -match '^([^=]+)=(.*)') {
                    [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
                }
            }
}
Invoke-VSDevEnvironment