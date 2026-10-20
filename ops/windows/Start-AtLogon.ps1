$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$logDirectory = Join-Path $repoRoot '.server\logs'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
& (Join-Path $PSScriptRoot 'Server.ps1') start *> (Join-Path $logDirectory 'autostart.log')
exit $LASTEXITCODE
