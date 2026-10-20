param(
    [string]$Installer = (Join-Path $PSScriptRoot '..\..\.server\installers\tailscale-amd64.msi'),
    [string]$PublicKey = (Join-Path $PSScriptRoot '..\..\.server\ssh\firstcase_ed25519.pub')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
Start-Transcript -Path (Join-Path $logRoot 'server-setup.log') -Append
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this script as Administrator.'
    }
    if (-not (Test-Path -LiteralPath $PublicKey)) { throw 'Supply -PublicKey pointing to your SSH public key.' }
    if (-not (Test-Path 'C:\Program Files\Tailscale\tailscale.exe')) {
        if ((Get-AuthenticodeSignature -LiteralPath $Installer).Status -ne 'Valid') { throw 'Invalid installer signature.' }
        $install = Invoke-ServerCommand "$env:WINDIR\System32\msiexec.exe" @('/i',$Installer,'/qn','/norestart','/L*v',(Join-Path $logRoot 'tailscale-install.log')) -TimeoutSeconds 180 -Label 'Install Tailscale' -AllowFailure
        if ($install.ExitCode -notin @(0,3010)) { throw ('Tailscale installation failed: ' + $install.ExitCode) }
    }
    Set-Service Tailscale -StartupType Automatic
    Start-Service Tailscale
    'Tailscale installed.' | Set-Content (Join-Path $logRoot 'tailscale-ready.txt')

    # Do not use Windows Capability/DISM here: Windows servicing blocked the first deployment.
    $sshService = Get-CimInstance Win32_Service -Filter "Name='sshd'" -ErrorAction SilentlyContinue
    $sshBinary = $null
    if ($sshService -and $sshService.PathName -match '^"?(.+?sshd\.exe)"?(?:\s|$)') {
        if (Test-Path -LiteralPath $matches[1]) { $sshBinary = $matches[1] }
    }
    if ($sshBinary) {
        $currentClient = Join-Path (Split-Path $sshBinary -Parent) 'ssh.exe'
        $serverVersion = (Get-Item -LiteralPath $sshBinary).VersionInfo.FileVersion
        $clientVersion = if (Test-Path -LiteralPath $currentClient) { (Get-Item -LiteralPath $currentClient).VersionInfo.FileVersion } else { '' }
        if (-not $clientVersion -or $clientVersion -ne $serverVersion) {
            Write-Host ('OpenSSH component mismatch: server=' + $serverVersion + ', client=' + $clientVersion + '. Installing a matching Microsoft package.') -ForegroundColor Yellow
            $sshBinary = $null
        }
    }
    if (-not $sshBinary) {
        Write-Host '--> Download official Microsoft OpenSSH ZIP (limit 90s)'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        $zip = Join-Path $logRoot 'OpenSSH-Win64-10.0.0.0p2.zip'
        $expectedHash = '23f50f3458c4c5d0b12217c6a5ddfde0137210a30fa870e98b29827f7b43aba5'
        if (-not (Test-Path -LiteralPath $zip) -or (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
            Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/PowerShell/Win32-OpenSSH/releases/download/10.0.0.0p2-Preview/OpenSSH-Win64.zip' -OutFile $zip -TimeoutSec 90
        }
        if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) { throw 'Microsoft OpenSSH archive checksum mismatch.' }
        $expanded = Join-Path $logRoot 'openssh-package'
        Expand-Archive -LiteralPath $zip -DestinationPath $expanded -Force
        $source = Join-Path $expanded 'OpenSSH-Win64'
        if ((Get-AuthenticodeSignature -LiteralPath (Join-Path $source 'sshd.exe')).Status -ne 'Valid') { throw 'Invalid OpenSSH executable signature.' }
        $sshBin = 'C:\Program Files\FirstCaseOpenSSH'
        New-Item -ItemType Directory -Path $sshBin -Force | Out-Null
        Copy-Item -Path (Join-Path $source '*') -Destination $sshBin -Recurse -Force
        $oldService = Get-Service sshd -ErrorAction SilentlyContinue
        if ($oldService -and $oldService.Status -ne 'Stopped') {
            Invoke-ServerCommand "$env:WINDIR\System32\sc.exe" @('stop','sshd') -TimeoutSeconds 10 -Label 'Stop old SSH service' -AllowFailure -ShowOutput | Out-Null
            $oldService.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Stopped,[TimeSpan]::FromSeconds(30))
        }
        Invoke-ServerCommand "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $sshBin 'install-sshd.ps1')) -TimeoutSeconds 90 -Label 'Register OpenSSH services' -ShowOutput | Out-Null
        $sshBinary = Join-Path $sshBin 'sshd.exe'
    }
    $sshBin = Split-Path $sshBinary -Parent
    $existingService = Get-Service sshd -ErrorAction SilentlyContinue
    if ($existingService -and $existingService.Status -ne 'Stopped') {
        $existingService.Stop()
        $existingService.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Stopped,[TimeSpan]::FromSeconds(20))
    }
    $sshRoot = Join-Path $env:ProgramData 'ssh'
    New-Item -ItemType Directory -Force -Path $sshRoot | Out-Null
    $configPath = Join-Path $sshRoot 'sshd_config'
    if (Test-Path -LiteralPath $configPath) {
        Copy-Item -LiteralPath $configPath -Destination (Join-Path $logRoot ('sshd_config-before-' + (Get-Date -Format yyyyMMddHHmmss)))
    }
    @'
Port 22
AddressFamily any
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
AllowUsers admin
AuthorizedKeysFile __PROGRAMDATA__/ssh/firstcase_authorized_keys
StrictModes yes
MaxAuthTries 3
LoginGraceTime 30
AllowAgentForwarding no
AllowTcpForwarding yes
Subsystem sftp internal-sftp
'@ | Set-Content -LiteralPath $configPath -Encoding ascii
    if (-not (Test-Path -LiteralPath $PublicKey)) { throw 'Public key has not been created yet.' }
    $keyText = (Get-Content -LiteralPath $PublicKey -Raw).Trim()
    if ($keyText -notmatch '^ssh-(ed25519|rsa) [A-Za-z0-9+/=]+(?: .*)?$') { throw 'Invalid public key format.' }
    $authorized = Join-Path $sshRoot 'firstcase_authorized_keys'
    Set-Content -LiteralPath $authorized -Value $keyText -Encoding ascii
    & icacls.exe $authorized /inheritance:r /grant:r '*S-1-5-18:(F)' '*S-1-5-32-544:(F)' | Out-Host
    & icacls.exe $authorized /setowner '*S-1-5-32-544' | Out-Host
    Invoke-ServerCommand (Join-Path $sshBin 'ssh-keygen.exe') @('-A') -TimeoutSeconds 20 -Label 'Prepare SSH host keys' | Out-Null
    Invoke-ServerCommand $sshBinary @('-t') -TimeoutSeconds 15 -Label 'Validate SSH configuration' | Out-Null
    Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP','sshd' -ErrorAction SilentlyContinue | Disable-NetFirewallRule
    if (-not (Get-NetFirewallRule -Name 'FirstCase-SSH-Tailscale' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'FirstCase-SSH-Tailscale' -DisplayName 'FirstCase SSH over Tailscale only' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22 -RemoteAddress '100.64.0.0/10','fd7a:115c:a1e0::/48' -Profile Any | Out-Host
    }
    New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
    New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force | Out-Null
    Set-Service sshd -StartupType Automatic
    $controller = Get-Service sshd
    $controller.Start()
    try {
        $controller.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Running,[TimeSpan]::FromSeconds(30))
    } catch {
        $diagnosticPath = Join-Path $logRoot 'ssh-service-diagnostics.txt'
        @('sshd service failed to reach Running.',('Binary: '+$sshBinary),('Version: '+(Get-Item -LiteralPath $sshBinary).VersionInfo.FileVersion)) | Set-Content $diagnosticPath
        & "$env:WINDIR\System32\sc.exe" queryex sshd | Out-File $diagnosticPath -Append
        Get-WinEvent -FilterHashtable @{LogName='OpenSSH/Operational';StartTime=(Get-Date).AddMinutes(-15)} -MaxEvents 8 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,Message | Format-List | Out-File $diagnosticPath -Append
        throw ('SSH service did not start. Diagnostics saved to '+$diagnosticPath)
    }
    & sc.exe failure sshd reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Host
    & powercfg.exe /query SCHEME_CURRENT SUB_SLEEP | Set-Content (Join-Path $logRoot 'power-before.txt')
    & powercfg.exe /change standby-timeout-ac 0
    & powercfg.exe /change hibernate-timeout-ac 0
    & powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
    & powercfg.exe /setactive SCHEME_CURRENT
    $keyPath = [IO.Path]::ChangeExtension($PublicKey, $null)
    $knownHosts = (Join-Path $logRoot 'firstcase-known-hosts').Replace('\','/')
    $probe = Invoke-ServerCommand (Join-Path $sshBin 'ssh.exe') @('-i',$keyPath,'-o','BatchMode=yes','-o','PasswordAuthentication=no','-o','StrictHostKeyChecking=accept-new','-o',('UserKnownHostsFile='+$knownHosts),'-o','ConnectTimeout=8','admin@127.0.0.1','whoami') -TimeoutSeconds 20 -Label 'Verify SSH key login locally' -ShowOutput
    $ts = Invoke-ServerCommand 'C:\Program Files\Tailscale\tailscale.exe' @('status','--json') -TimeoutSeconds 15 -Label 'Read remote SSH address'
    $status = $ts.Stdout | ConvertFrom-Json
    $address = $status.Self.DNSName.TrimEnd('.')
    [pscustomobject]@{ Address=$address; LocalLoginVerified=($probe.ExitCode -eq 0); User=$probe.Stdout.Trim(); Command=('ssh -i firstcase_ed25519 admin@'+$address) } | ConvertTo-Json | Set-Content (Join-Path $stateRoot 'ssh-status.json') -Encoding utf8
    Write-Host ('SSH: ssh -i firstcase_ed25519 admin@' + $address) -ForegroundColor Green
    'Complete' | Set-Content (Join-Path $logRoot 'server-setup-complete.txt')
} catch {
    $_.Exception.Message | Set-Content (Join-Path $logRoot 'server-setup-error.txt')
    throw
} finally { Stop-Transcript }
