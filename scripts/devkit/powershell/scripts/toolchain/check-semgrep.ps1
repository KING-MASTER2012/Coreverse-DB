#Requires -Version 7.0
<#
.SYNOPSIS
    Optional tool - only added to the task graph when approved via -Accept /
    an interactive Y/n answer (see bootstrap.ps1's optional-tool phase).

.NOTES
    Semgrep has no reliable winget package; it's a Python (pip) package on
    Windows. No package manager fallback beyond pip - if Python 3 isn't
    found, this is logged as a Warning and Skipped rather than Failed,
    matching the project's "warn and continue" policy for secondary tools
    (see python-check.ps1 / check-lldb.ps1).
#>

param(
    [string]$RequiredVersion = '1.0.0',
    [switch]$DryRun
)

. "$PSScriptRoot/../common/logger.ps1"
. "$PSScriptRoot/../common/version-compare.ps1"
. "$PSScriptRoot/../common/python-check.ps1"

$ToolName = 'Semgrep'

$result = [PSCustomObject]@{
    Tool            = $ToolName
    PreviousVersion = $null
    RequiredVersion = $RequiredVersion
    FinalVersion    = $null
    Source          = $null
    Status          = 'Unknown'
}

$getVersion = {
    $cmd = Get-Command semgrep -ErrorAction SilentlyContinue
    if ($cmd) { (& semgrep --version) 2>&1 | Select-Object -First 1 } else { $null }
}

$raw = & $getVersion
$result.PreviousVersion = $raw

if ($raw -and (Test-VersionAtLeast -CurrentRaw $raw -RequiredRaw $RequiredVersion)) {
    $result.FinalVersion = $raw
    $result.Source = 'AlreadySatisfied'
    $result.Status = 'OK'
    Write-SuccessLog -Message "The version is sufficient (>= $RequiredVersion)." -Source $ToolName
    return $result
}

if ($DryRun) {
    Write-InfoLog -Message '[DryRun] Installation was to be performed (pip install semgrep).' -Source $ToolName
    $result.Status = 'DryRun'
    return $result
}

$python = Find-PythonExecutable
if (-not $python) {
    Write-WarningLog -Message 'No Python 3 interpreter found; semgrep is a pip package and cannot be installed. Skipping.' -Source $ToolName
    $result.Status = 'Skipped'
    return $result
}

$installed = Install-PythonPipPackage -Python $python -PackageName 'semgrep' -Source $ToolName

if (-not $installed) {
    $result.Status = 'Failed'
    return $result
}

$raw = & $getVersion
if ($raw -and (Test-VersionAtLeast -CurrentRaw $raw -RequiredRaw $RequiredVersion)) {
    $result.FinalVersion = $raw
    $result.Source = 'pip'
    $result.Status = if ($result.PreviousVersion) { 'Upgraded' } else { 'Installed' }
    Write-SuccessLog -Message "Installed: $raw" -Source $ToolName
} elseif ($raw) {
    $result.FinalVersion = $raw
    $result.Source = 'pip'
    $result.Status = 'Warning'
    Write-WarningLog -Message "Installed but version is lower than wanted: $raw (wanted >= $RequiredVersion). Continuing." -Source $ToolName
} else {
    $result.Status = 'Failed'
    Write-ErrorLog -Message 'semgrep was not found on PATH after pip install.' -Source $ToolName
}

return $result
