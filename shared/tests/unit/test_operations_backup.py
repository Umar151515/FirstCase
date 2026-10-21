import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

POWERSHELL = shutil.which("powershell.exe")
pytestmark = pytest.mark.skipif(
    os.name != "nt" or POWERSHELL is None, reason="Windows PowerShell backup workflow"
)


@pytest.mark.parametrize(
    "writers,fail_dump",
    [
        ((), False),
        (("backend",), False),
        (("bot",), False),
        (("backend", "bot"), False),
        (("backend",), True),
    ],
)
def test_backup_restores_only_previously_running_writers(tmp_path, writers, fail_dump):
    # Execute the real orchestration with local stubs; no Docker command is started.
    source = Path(__file__).resolve().parents[3] / "ops" / "windows" / "Backup.ps1"
    shutil.copyfile(source, tmp_path / "Backup.ps1")
    (tmp_path / ".env.production").write_text("BACKUP_TEST_ONLY=1\n", encoding="utf-8")
    (tmp_path / "Common.ps1").write_text(
        r"""
$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
$stateRoot = Join-Path $PSScriptRoot 'state'
$compose = @('compose')
$docker = 'never-executed-docker'
function icacls.exe { $global:LASTEXITCODE = 0 }
function Invoke-ServerCommand {
    param($FilePath, [string[]]$Arguments, $Label, $TimeoutSeconds, [switch]$Quiet)
    $output = if ($Label -eq 'Find running writers') { $env:BACKUP_TEST_WRITERS } else { 'fake-container' }
    return [pscustomobject]@{ Stdout = [string]$output }
}
function Run-Docker {
    param([string[]]$DockerArgs, [string]$Label, [int]$Timeout = 120)
    $global:BackupTestCalls.Add([pscustomobject]@{ Label = $Label; Arguments = $DockerArgs })
    if ($Label -eq 'Back up database' -and $env:BACKUP_TEST_FAIL -eq '1') {
        throw 'Simulated dump failure'
    }
}
""",
        encoding="utf-8",
    )
    harness = tmp_path / "Test-Backup.ps1"
    harness.write_text(
        r"""
$global:BackupTestCalls = New-Object 'System.Collections.Generic.List[object]'
$failed = $false
try { & (Join-Path $PSScriptRoot 'Backup.ps1') | Out-Null } catch { $failed = $true }
$result = [pscustomobject]@{ Failed = $failed; Calls = @($global:BackupTestCalls.ToArray()) }
Write-Output ('BACKUP_TEST_RESULT=' + (ConvertTo-Json -InputObject $result -Depth 6 -Compress))
""",
        encoding="utf-8",
    )
    env = os.environ.copy()
    env.update(BACKUP_TEST_WRITERS="\n".join(writers), BACKUP_TEST_FAIL="1" if fail_dump else "0")
    completed = subprocess.run(
        [POWERSHELL, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(harness)],
        capture_output=True,
        text=True,
        env=env,
        timeout=30,
        check=True,
    )
    result_line = next(
        line for line in completed.stdout.splitlines() if line.startswith("BACKUP_TEST_RESULT=")
    )
    result = json.loads(result_line.split("=", 1)[1])
    assert result["Failed"] is fail_dump
    for label, action in (
        ("Pause writers for backup", "stop"),
        ("Resume existing writers", "start"),
    ):
        matching = [call["Arguments"] for call in result["Calls"] if call["Label"] == label]
        assert matching == ([["compose", action, *writers]] if writers else [])
