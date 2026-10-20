$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$stateRoot = Join-Path $repoRoot '.server'
$logRoot = Join-Path $stateRoot 'logs'
New-Item -ItemType Directory -Force -Path $stateRoot,$logRoot | Out-Null
$dockerCommand = Get-Command docker.exe -ErrorAction SilentlyContinue
$docker = if ($dockerCommand) { $dockerCommand.Source } else {
    Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'
}
if (-not (Test-Path -LiteralPath $docker)) { throw 'Docker Desktop CLI was not found.' }
$compose = @('compose','--project-directory',$repoRoot,'--env-file',(Join-Path $repoRoot '.env.production'),'-f',(Join-Path $repoRoot 'docker-compose.prod.yml'))
. (Join-Path $PSScriptRoot 'Native-Command.ps1')

function Run-Docker([string[]]$DockerArgs, [string]$Label, [int]$Timeout = 120, [switch]$AllowFailure) {
    Invoke-ServerCommand $docker $DockerArgs -Label $Label -TimeoutSeconds $Timeout -ShowOutput -AllowFailure:$AllowFailure
}

function Wait-Docker {
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    $desktop = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'
    $started = $false
    do {
        $probe = Invoke-ServerCommand $docker @('info','--format','{{.ServerVersion}}') -Label 'Docker readiness' -TimeoutSeconds 8 -Quiet -AllowFailure
        if ($probe.ExitCode -eq 0) { return }
        if (-not $started -and (Test-Path -LiteralPath $desktop)) {
            Start-Process -FilePath $desktop -WindowStyle Hidden
            $started = $true
        }
        Write-Host 'Waiting for Docker Desktop...'
        Start-Sleep -Seconds 3
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Docker Desktop did not become available in 120 seconds.'
}

function Get-ServerSettings {
    $settings = @{}
    $envFile = Join-Path $repoRoot '.env.production'
    if (-not (Test-Path -LiteralPath $envFile)) { throw 'Create .env.production using docs/server.md.' }
    foreach ($line in Get-Content -LiteralPath $envFile) {
        if ($line -match '^\s*([A-Z_][A-Z_0-9]*)=(.*)$') {
            $settings[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
        }
    }
    return $settings
}

function Test-Application {
    $settings = Get-ServerSettings
    $port = if ($settings['WEB_PORT']) { $settings['WEB_PORT'] } else { '8080' }
    $base = 'http://127.0.0.1:' + $port
    $health = Invoke-RestMethod ($base + '/health/ready') -TimeoutSec 15
    $config = Invoke-RestMethod ($base + '/api/v1/config') -TimeoutSec 15
    $categories = Invoke-RestMethod ($base + '/api/v1/categories') -TimeoutSec 15
    if ($health.status -ne 'ok' -or $config.mode -ne 'production') { throw 'Production health check failed.' }
    if ($categories.total -lt 1) { throw 'The category catalogue is empty. Run server.cmd update.' }
    Write-Host ('Production healthy; categories: ' + $categories.total) -ForegroundColor Green
    Write-Host ('Application: ' + $settings['PUBLIC_WEBAPP_URL'])
    return $base
}

function Enable-PublicAccess {
    $tailscale = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (-not (Test-Path -LiteralPath $tailscale)) { Write-Warning 'Install/sign into Tailscale to enable public access.'; return }
    $settings = Get-ServerSettings
    $port = if ($settings['WEB_PORT']) { $settings['WEB_PORT'] } else { '8080' }
    $result = Invoke-ServerCommand $tailscale @('funnel','--bg','--yes',$port) -Label 'Public HTTPS Funnel' -TimeoutSeconds 30 -ShowOutput -AllowFailure
    if ($result.ExitCode -ne 0) { Write-Warning 'Local application is running; Funnel needs attention. See the URL printed above.' }
}
