#Requires -Version 7.0
<#
.SYNOPSIS
    Optional tool - only added to the task graph when approved via -Accept /
    an interactive Y/n answer (see bootstrap.ps1's optional-tool phase).

.NOTES
    Covers BOTH "SQL lint/style" and "SQL static analysis" from the
    original tool list: SQLFluff is a single package that provides its
    lint engine and rule set together, so a single question/install covers
    both - two separate pip installs of the same package would be
    redundant.

    No reliable winget package; installed via pip, same pattern as
    check-semgrep.ps1.
#>

param(
    [string]$RequiredVersion = '3.0.0',
    [switch]$DryRun
)

. "$PSScriptRoot/../common/logger.ps1"
. "$PSScriptRoot/../common/version-compare.ps1"
. "$PSScriptRoot/../common/python-check.ps1"

$ToolName = 'SQLFluff'

$result = [PSCustomObject]@{
    Tool            = $ToolName
    PreviousVersion = $null
    RequiredVersion = $RequiredVersion
    FinalVersion    = $null
    Source          = $null
    Status          = 'Unknown'
}

$getVersion = {
    $cmd = Get-Command sqlfluff -ErrorAction SilentlyContinue
    if ($cmd) { (& sqlfluff --version) 2>&1 | Select-Object -First 1 } else { $null }
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
    Write-InfoLog -Message '[DryRun] Installation was to be performed (pip install sqlfluff).' -Source $ToolName
    $result.Status = 'DryRun'
    return $result
}

$python = Find-PythonExecutable
if (-not $python) {
    Write-WarningLog -Message 'No Python 3 interpreter found; sqlfluff is a pip package and cannot be installed. Skipping.' -Source $ToolName
    $result.Status = 'Skipped'
    return $result
}

$installed = Install-PythonPipPackage -Python $python -PackageName 'sqlfluff' -Source $ToolName

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
    Write-ErrorLog -Message 'sqlfluff was not found on PATH after pip install.' -Source $ToolName
}

return $result
