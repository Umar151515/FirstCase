function ConvertTo-WindowsArgument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-ServerCommand {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 30,
        [string]$Label = 'Command',
        [switch]$ShowOutput,
        [switch]$AllowFailure,
        [switch]$Quiet
    )
    $logRoot = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))) '.server\logs'
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
    $logName = 'native-' + ($Label -replace '[^a-zA-Z0-9]', '-') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $outFile = Join-Path $logRoot ($logName + '.out.log')
    $errFile = Join-Path $logRoot ($logName + '.err.log')
    $argumentLine = (@($Arguments | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' ')
    if (-not $Quiet) { Write-Host ('--> ' + $Label) }
    $process = Start-Process -FilePath $FilePath -ArgumentList $argumentLine -WindowStyle Hidden -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    # PowerShell 5.1 needs a retained process handle to report ExitCode reliably.
    $processHandle = $process.Handle
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $outCount = 0
    $errCount = 0
    $lastProgress = 0
    $timedOut = $false
    while ($true) {
        if ($ShowOutput) {
            $lines = @(Get-Content -LiteralPath $outFile -ErrorAction SilentlyContinue)
            for ($i = $outCount; $i -lt $lines.Count; $i++) { Write-Host $lines[$i] }
            $outCount = $lines.Count
            $lines = @(Get-Content -LiteralPath $errFile -ErrorAction SilentlyContinue)
            for ($i = $errCount; $i -lt $lines.Count; $i++) { Write-Host $lines[$i] }
            $errCount = $lines.Count
        }
        if ($process.HasExited) { break }
        if ($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            # Terminate only our command, never Windows servicing.
            try { $process.Kill(); $process.WaitForExit(5000) | Out-Null } catch {}
            break
        }
        if (-not $Quiet -and $watch.Elapsed.TotalSeconds -ge ($lastProgress + 15)) {
            $lastProgress = [int]$watch.Elapsed.TotalSeconds
            Write-Host ('    ' + $Label + ': waiting ' + $lastProgress + 's (limit ' + $TimeoutSeconds + 's)')
        }
        $process.WaitForExit(250) | Out-Null
    }
    if (-not $timedOut) { $process.WaitForExit() }
    $stdout = [string](Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue)
    $stderr = [string](Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
    if ($ShowOutput) {
        $lines = @($stdout -split '\r?\n')
        for ($i = $outCount; $i -lt $lines.Count; $i++) { if ($lines[$i]) { Write-Host $lines[$i] } }
        $lines = @($stderr -split '\r?\n')
        for ($i = $errCount; $i -lt $lines.Count; $i++) { if ($lines[$i]) { Write-Host $lines[$i] } }
    }
    $code = if ($timedOut) { 124 } else { $process.ExitCode }
    $process.Dispose()
    if (($timedOut -or $code -ne 0) -and -not $AllowFailure) {
        if ($timedOut) { throw ($Label + ' exceeded ' + $TimeoutSeconds + ' seconds. Details: ' + $outFile) }
        $detail = ([string]$stderr).Trim()
        if ($detail.Length -gt 1200) { $detail = $detail.Substring($detail.Length - 1200) }
        throw ($Label + ' failed (exit ' + $code + '). ' + $detail + ' Log: ' + $outFile)
    }
    return [pscustomobject]@{ ExitCode=$code; Stdout=$stdout; Stderr=$stderr; TimedOut=$timedOut; Log=$outFile }
}
