#Requires -Version 7.0

<#
.SYNOPSIS
    Installs dependencies for the src/ React package via pnpm.

.DESCRIPTION
    Only runs 'pnpm install'. package.json / pnpm-lock.yaml / tsconfig.json /
    orval.config.ts already exist in the project and are never written or
    modified by this script - dependency resolution + tool installation is
    all this devkit does.

.NOTES
    This script assumes check-node.ps1 and check-pnpm.ps1 have already
    completed successfully.
#>

param(
    [string]$PackageDir = '',
    [switch]$DryRun
)

. "$PSScriptRoot/../common/logger.ps1"

$ToolName = 'pnpm Dependencies'

$result = [PSCustomObject]@{
    Tool   = $ToolName
    Status = 'Unknown'
    Detail = $null
}

if ([string]::IsNullOrWhiteSpace($PackageDir)) {
    Write-WarningLog `
        -Message "'pnpmPackageDir' is not set in config/project-paths.json. Skipping." `
        -Source $ToolName

    $result.Status = 'Skipped'
    return $result
}

$PackageDir = [System.IO.Path]::GetFullPath($PackageDir)
$packageJsonPath = Join-Path $PackageDir 'package.json'

if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
    Write-WarningLog `
        -Message "No package.json found under '$PackageDir'. Skipping." `
        -Source $ToolName

    $result.Status = 'Skipped'
    return $result
}

$pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue

if (-not $pnpmCmd) {
    Write-ErrorLog `
        -Message 'pnpm not found on PATH. The toolchain phase must be completed first.' `
        -Source $ToolName

    $result.Status = 'Failed'
    return $result
}

if ($DryRun) {
    Write-InfoLog `
        -Message "[DryRun] In '$PackageDir', 'pnpm install' was to be run." `
        -Source $ToolName

    $result.Status = 'DryRun'
    return $result
}

Push-Location $PackageDir

try {
    Write-InfoLog `
        -Message 'pnpm install running...' `
        -Source $ToolName

    # Capture all output first so that:
    # 1. empty lines can be ignored safely;
    # 2. pnpm's actual exit code is preserved;
    # 3. output handling cannot interfere with $LASTEXITCODE.
    $pnpmOutput = & pnpm install 2>&1
    $pnpmExitCode = $LASTEXITCODE

    foreach ($line in $pnpmOutput) {
        $message = [string]$line

        if (-not [string]::IsNullOrWhiteSpace($message)) {
            Write-PlainLog `
                -Message $message `
                -Source $ToolName
        }
    }

    if ($pnpmExitCode -eq 0) {
        $result.Status = 'OK'

        Write-SuccessLog `
            -Message 'pnpm dependencies installed.' `
            -Source $ToolName
    }
    else {
        $result.Status = 'Failed'

        Write-ErrorLog `
            -Message "pnpm install ended with error code: $pnpmExitCode" `
            -Source $ToolName
    }
}
catch {
    $result.Status = 'Failed'
    $result.Detail = $_.Exception.Message

    Write-ErrorLog `
        -Message "pnpm install failed: $($_.Exception.Message)" `
        -Source $ToolName
}
finally {
    Pop-Location
}

return $result
