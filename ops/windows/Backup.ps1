. (Join-Path $PSScriptRoot 'Common.ps1')
$destination = Join-Path $stateRoot ('backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $destination -Force | Out-Null
& icacls.exe $destination /inheritance:r /grant:r ('{0}:(OI)(CI)F' -f [Security.Principal.WindowsIdentity]::GetCurrent().Name) '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Cannot protect the backup directory.' }
$stopped = $false
try {
    $stopped = $true
    Run-Docker ($compose + @('stop','backend','bot')) 'Pause writers for backup' | Out-Null
    Run-Docker ($compose + @('exec','-T','postgres','pg_dump','-U','firstcase','-d','firstcase_production','-Fc','-f','/tmp/firstcase-backup.dump')) 'Back up database' 180 | Out-Null
    Run-Docker ($compose + @('cp','postgres:/tmp/firstcase-backup.dump',(Join-Path $destination 'database.dump'))) 'Copy database backup' | Out-Null
    # Use the existing container, without starting a new application or migrations.
    $container = Invoke-ServerCommand $docker ($compose + @('ps','-a','-q','backend')) -Label 'Find uploads volume' -TimeoutSeconds 15 -Quiet
    Run-Docker @('run','--rm','--volumes-from',$container.Stdout.Trim(),'--volume',($destination + ':/backup'),'--entrypoint','python','firstcase-production-backend','-c',"import tarfile; t=tarfile.open('/backup/uploads.tar.gz','w:gz'); t.add('/data/uploads',arcname='uploads'); t.close()") 'Back up uploads' 180 | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot '.env.production') -Destination $destination
    if (Test-Path (Join-Path $stateRoot 'deployment.json')) { Copy-Item -LiteralPath (Join-Path $stateRoot 'deployment.json') -Destination $destination }
} finally {
    # start reuses the old containers even when newer images have already been built.
    if ($stopped) { Run-Docker ($compose + @('start','backend','bot')) 'Resume existing writers' | Out-Null }
}
Write-Host ('Backup: ' + $destination) -ForegroundColor Green
return $destination
