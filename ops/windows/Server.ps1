param(
    [ValidateSet('start','update','status','logs','backup','restart','stop','setup','help')]
    [string]$Action = 'start'
)
. (Join-Path $PSScriptRoot 'Common.ps1')
Set-Location $repoRoot
$deployLock = $null
$previousRevision = $env:APP_REVISION
$switched = $false
$restoreImages = $false
$images = @{}
try {
    if ($Action -eq 'help') {
        Write-Host 'server.cmd start | update | status | logs | backup | restart | stop | setup'
        exit 0
    }
    if ($Action -in @('start','update','backup','restart','stop','setup')) {
        try { $deployLock = [IO.File]::Open((Join-Path $stateRoot 'deploy.lock'),'OpenOrCreate','ReadWrite','None') }
        catch { throw 'Another server operation is running. Wait for it to finish.' }
    }
    if ($Action -eq 'setup') {
        & (Join-Path $PSScriptRoot 'Setup-Access.ps1')
        exit 0
    }
    Wait-Docker
    Run-Docker ($compose + @('config','--quiet')) 'Validate production settings' 15 | Out-Null
    switch ($Action) {
        'status' {
            Run-Docker ($compose + @('ps')) 'Containers' 15 | Out-Null
            if (Test-Path (Join-Path $stateRoot 'deployment.json')) { Get-Content (Join-Path $stateRoot 'deployment.json') | Out-Host }
            Test-Application | Out-Null
        }
        'logs' { & $docker @compose logs --tail 100 --follow backend frontend bot; if ($LASTEXITCODE -ne 0) { throw 'Unable to read logs.' } }
        'backup' { & (Join-Path $PSScriptRoot 'Backup.ps1') | Out-Null }
        'stop' { Run-Docker ($compose + @('stop')) 'Stop application (keep data)' | Out-Null }
        'restart' {
            Run-Docker ($compose + @('restart','backend','frontend','bot')) 'Restart application' | Out-Null
            Run-Docker ($compose + @('up','-d','--no-build','--wait','--wait-timeout','180')) 'Wait for application' 240 | Out-Null
            Test-Application | Out-Null
            Enable-PublicAccess
        }
        'start' {
            Run-Docker ($compose + @('up','-d','--no-build','--wait','--wait-timeout','180')) 'Start application' 240 | Out-Null
            Test-Application | Out-Null
            Enable-PublicAccess
        }
        'update' {
            $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
            $git = if ($gitCommand) { $gitCommand.Source } else {
                Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe'
            }
            if (-not (Test-Path $git)) { throw 'Install Git for Windows, then run server.cmd update again.' }
            $dirty = Invoke-ServerCommand $git @('status','--porcelain') -Quiet -Label 'Check local changes'
            if (-not [string]::IsNullOrWhiteSpace($dirty.Stdout)) { throw 'Local changes exist. Commit or preserve them before updating; no files were overwritten.' }
            $branch = Invoke-ServerCommand $git @('branch','--show-current') -Quiet -Label 'Check branch'
            if ($branch.Stdout.Trim() -ne 'main') { throw 'Server updates require the main branch.' }
            Run-Docker ($compose + @('config','--quiet')) 'Validate existing configuration' 15 | Out-Null
            Invoke-ServerCommand $git @('pull','--ff-only','origin','main') -Label 'Get latest main from GitHub' -TimeoutSeconds 180 -ShowOutput | Out-Null
            $revision = (Invoke-ServerCommand $git @('rev-parse','HEAD') -Quiet -Label 'Read commit').Stdout.Trim()
            $env:APP_REVISION = $revision
            $statePath = Join-Path $stateRoot 'deployment.json'
            if (Test-Path $statePath) {
                $deployed = Get-Content $statePath -Raw | ConvertFrom-Json
                if ($deployed.Revision -eq $revision) {
                    $localBase = Test-Application
                    $live = Invoke-RestMethod ($localBase + '/build-info.json') -TimeoutSec 10
                    if ($live.revision -eq $revision) {
                        Write-Host ('Already deployed: ' + $revision) -ForegroundColor Green
                        Enable-PublicAccess
                        break
                    }
                }
            }
            Run-Docker @('build','--progress','plain','--target','verify','-f','frontend/Dockerfile','-t','firstcase-frontend-verified','.') 'Analyze and test frontend' 1200 | Out-Null
            $testCompose = @('compose','-p','firstcase-tests','-f',(Join-Path $repoRoot 'ops\compose.test.yml'))
            try {
                Run-Docker ($testCompose + @('up','-d','--wait','postgres')) 'Start isolated test database' 120 | Out-Null
                Run-Docker ($testCompose + @('run','--rm','--build','backend')) 'Lint and test backend' 900 | Out-Null
            } finally {
                Run-Docker ($testCompose + @('down')) 'Remove isolated test containers' 60 | Out-Null
            }
            foreach ($service in @('backend','frontend','bot')) {
                $container = Invoke-ServerCommand $docker ($compose + @('ps','-a','-q',$service)) -Label 'Read existing container' -Quiet
                if (-not [string]::IsNullOrWhiteSpace($container.Stdout)) {
                    $oldImage = Invoke-ServerCommand $docker @('inspect','--format','{{.Image}}',$container.Stdout.Trim()) -Quiet -Label 'Read rollback image'
                    $images[$service] = $oldImage.Stdout.Trim()
                    Run-Docker @('tag',$images[$service],('firstcase-production-' + $service + ':rollback')) ('Preserve ' + $service) 15 | Out-Null
                }
            }
            $restoreImages = $true
            Run-Docker ($compose + @('build')) 'Build production images' 1200 | Out-Null
            $backup = $null
            if ($images.ContainsKey('backend')) { $backup = & (Join-Path $PSScriptRoot 'Backup.ps1') }
            $switched = $true
            Run-Docker ($compose + @('up','-d','--no-build','--wait','--wait-timeout','180')) 'Deploy and wait for health checks' 240 | Out-Null
            $base = Test-Application
            $live = Invoke-RestMethod ($base + '/build-info.json') -TimeoutSec 15
            if ($live.revision -ne $revision) { throw 'Frontend revision does not match the deployed commit.' }
            [pscustomobject]@{Revision=$revision;UpdatedAt=[DateTime]::UtcNow.ToString('o');Backup=$backup;TestsPassed=$true} |
                ConvertTo-Json -Depth 4 | Set-Content $statePath -Encoding UTF8
            $switched = $false
            $restoreImages = $false
            Enable-PublicAccess
            Write-Host ('Updated successfully: ' + $revision) -ForegroundColor Green
        }
    }
} catch {
    $failure = $_.Exception.Message
    if ($restoreImages -and $images.Count) {
        Write-Warning 'Deployment failed. Restoring previous application images; database is retained.'
        try {
            foreach ($service in $images.Keys) {
                Run-Docker @('tag',$images[$service],('firstcase-production-' + $service + ':latest')) ('Restore ' + $service) 15 | Out-Null
            }
            if ($switched) {
                Run-Docker ($compose + @('up','-d','--no-build','--wait','--wait-timeout','180')) 'Restore previous application' 240 | Out-Null
            }
        } catch { Write-Warning ('Rollback needs attention: ' + $_.Exception.Message) }
    }
    $failure | Set-Content (Join-Path $logRoot 'last-error.txt')
    Write-Host ('Server operation failed: ' + $failure) -ForegroundColor Red
    exit 1
} finally {
    $env:APP_REVISION = $previousRevision
    if ($deployLock) { $deployLock.Dispose() }
}
