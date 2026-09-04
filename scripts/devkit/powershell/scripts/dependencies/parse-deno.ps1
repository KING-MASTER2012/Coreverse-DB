#Requires -Version 7.0

<#
.SYNOPSIS
    Resolves Deno dependencies (deno.json/deno.lock) for the Supabase Edge
    Functions side of the project, then - if approved - runs `deno audit`
    as the last step of the same chain.

.DESCRIPTION
    Returns an ARRAY of 1 or 2 result objects ('Deno Dependencies', and
    'deno audit' when -RunAudit is set). Invoke-ParallelTasks/-TaskGraph's
    result flattening (see bootstrap.ps1's ConvertTo-FlatResults) accepts a
    task returning an array just as well as a single object, so both rows
    still land correctly in the summary table without any changes to the
    shared runner.

    `deno audit` is intentionally run here (against a freshly resolved
    deno.lock), not in the toolchain installation phase - it needs a
    current lockfile to audit against, and the toolchain phase runs before
    any lockfile has been resolved.

.NOTES
    This script assumes check-deno.ps1 has already completed successfully.
#>

param(
    [string]$FunctionsDir = '',
    [switch]$RunAudit,
    [switch]$DryRun
)

. "$PSScriptRoot/../common/logger.ps1"

$results = @()

$depResult = [PSCustomObject]@{
    Tool   = 'Deno Dependencies'
    Status = 'Unknown'
    Detail = $null
}

if ([string]::IsNullOrWhiteSpace($FunctionsDir)) {
    Write-WarningLog `
        -Message "'denoFunctionsDir' is not set in config/project-paths.json. Skipping." `
        -Source $depResult.Tool

    $depResult.Status = 'Skipped'
    $results += $depResult
    return $results
}

$FunctionsDir = [System.IO.Path]::GetFullPath($FunctionsDir)

$denoJsonPath = Join-Path $FunctionsDir 'deno.json'
$denoJsoncPath = Join-Path $FunctionsDir 'deno.jsonc'

if (
    -not (Test-Path -LiteralPath $denoJsonPath -PathType Leaf) -and
    -not (Test-Path -LiteralPath $denoJsoncPath -PathType Leaf)
) {
    Write-WarningLog `
        -Message "No deno.json/deno.jsonc found under '$FunctionsDir'. Skipping." `
        -Source $depResult.Tool

    $depResult.Status = 'Skipped'
    $results += $depResult
    return $results
}

$denoCmd = Get-Command deno -ErrorAction SilentlyContinue

if (-not $denoCmd) {
    Write-ErrorLog `
        -Message 'deno not found on PATH. The toolchain phase must be completed first.' `
        -Source $depResult.Tool

    $depResult.Status = 'Failed'
    $results += $depResult
    return $results
}

if ($DryRun) {
    Write-InfoLog `
        -Message "[DryRun] In '$FunctionsDir', 'deno install' was to be run." `
        -Source $depResult.Tool

    $depResult.Status = 'DryRun'
    $results += $depResult

    if ($RunAudit) {
        $results += [PSCustomObject]@{
            Tool   = 'deno audit'
            Status = 'DryRun'
            Detail = $null
        }
    }

    return $results
}

# ---------------------------------------------------------------------------
# Deno dependency resolution
# ---------------------------------------------------------------------------

Push-Location $FunctionsDir

try {
    Write-InfoLog `
        -Message 'deno install running...' `
        -Source $depResult.Tool

    # Capture command output first rather than piping directly into the logger.
    # This prevents empty output records from being passed to Write-PlainLog.
    $denoInstallOutput = & deno install 2>&1
    $denoInstallExitCode = $LASTEXITCODE

    foreach ($line in $denoInstallOutput) {
        $message = [string]$line

        if (-not [string]::IsNullOrWhiteSpace($message)) {
            Write-PlainLog `
                -Message $message `
                -Source $depResult.Tool
        }
    }

    if ($denoInstallExitCode -eq 0) {
        $depResult.Status = 'OK'

        Write-SuccessLog `
            -Message 'Deno dependencies resolved.' `
            -Source $depResult.Tool
    }
    else {
        $depResult.Status = 'Failed'

        Write-ErrorLog `
            -Message "deno install ended with error code: $denoInstallExitCode" `
            -Source $depResult.Tool
    }
}
catch {
    $depResult.Status = 'Failed'
    $depResult.Detail = $_.Exception.Message

    Write-ErrorLog `
        -Message "deno install failed: $($_.Exception.Message)" `
        -Source $depResult.Tool
}
finally {
    Pop-Location
}

$results += $depResult

# ---------------------------------------------------------------------------
# Optional Deno audit
# ---------------------------------------------------------------------------

if (-not $RunAudit) {
    return $results
}

$auditResult = [PSCustomObject]@{
    Tool   = 'deno audit'
    Status = 'Unknown'
    Detail = $null
}

if ($depResult.Status -ne 'OK') {
    Write-WarningLog `
        -Message 'Skipped: dependency resolution did not complete successfully.' `
        -Source $auditResult.Tool

    $auditResult.Status = 'Skipped'
    $results += $auditResult
    return $results
}

Push-Location $FunctionsDir

try {
    Write-InfoLog `
        -Message 'deno audit running...' `
        -Source $auditResult.Tool

    # Capture output first so empty lines never reach Write-PlainLog.
    $denoAuditOutput = & deno audit 2>&1
    $denoAuditExitCode = $LASTEXITCODE

    foreach ($line in $denoAuditOutput) {
        $message = [string]$line

        if (-not [string]::IsNullOrWhiteSpace($message)) {
            Write-PlainLog `
                -Message $message `
                -Source $auditResult.Tool
        }
    }

    if ($denoAuditExitCode -eq 0) {
        $auditResult.Status = 'OK'

        Write-SuccessLog `
            -Message 'No known vulnerabilities reported.' `
            -Source $auditResult.Tool
    }
    else {
        # deno audit may exit non-zero when it encounters an audit failure
        # or findings. This is intentionally surfaced as a Warning so that
        # audit problems do not fail the entire bootstrap process.
        $auditResult.Status = 'Warning'
        $auditResult.Detail = "deno audit exited with code $denoAuditExitCode"

        Write-WarningLog `
            -Message "deno audit reported findings or could not complete (exit code $denoAuditExitCode). Review the output above." `
            -Source $auditResult.Tool
    }
}
catch {
    # An unexpected PowerShell/runtime error is also surfaced as a warning,
    # preserving the bootstrap's non-blocking audit policy.
    $auditResult.Status = 'Warning'
    $auditResult.Detail = $_.Exception.Message

    Write-WarningLog `
        -Message "deno audit could not be completed: $($_.Exception.Message)" `
        -Source $auditResult.Tool
}
finally {
    Pop-Location
}

$results += $auditResult

return $results
