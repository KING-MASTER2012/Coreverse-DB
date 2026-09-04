#Requires -Version 7.0
<#
.SYNOPSIS
    Coreverse-DB Bootstrap - shared check logic for Deno's built-in sub-tools
    (lint / fmt / check / inspector).

.DESCRIPTION
    Deno lint, fmt, check (type-checker) and the V8 Inspector are NOT
    separate binaries or packages - they ship inside the single `deno`
    executable. There is nothing to "install" independently of Deno itself
    (see check-deno.ps1), but each one is still verified separately here so
    the summary table reports each capability on its own row, and so a
    partially-broken Deno build (e.g. a stripped-down distro package missing
    a subcommand) is caught per-feature instead of masked behind a single
    generic "Deno: OK" line.

    This is intentionally NOT run through Invoke-ToolCheck (tool-check-
    helper.ps1): there is no install/upgrade path for an individual
    subcommand, only for Deno as a whole. If a subcommand is missing/broken,
    the fix is always "reinstall/upgrade Deno", which check-deno.ps1 already
    owns (task graph: DependsOn = 'Deno').

    Sourced by check-deno-lint.ps1 / check-deno-fmt.ps1 /
    check-deno-typecheck.ps1 / check-deno-inspector.ps1; not intended to be
    run directly.
#>

. "$PSScriptRoot/logger.ps1"

# Invoke-DenoSubcommandCheck <ToolName> <Args> [-VersionArgs <args>]
#   ToolName    : display name for logs / summary table (e.g. 'Deno Lint')
#   ProbeArgs   : arguments that prove the subcommand is available without
#                 requiring a real project on disk (e.g. '--help' or a
#                 harmless no-op invocation)
# Returns the common result shape used across the toolchain (Tool,
# PreviousVersion, RequiredVersion, FinalVersion, Source, Status) so it
# slots into the same summary table as Invoke-ToolCheck results.
function Invoke-DenoSubcommandCheck {
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][string[]]$ProbeArgs,
        [switch]$DryRun
    )

    $result = [PSCustomObject]@{
        Tool            = $ToolName
        PreviousVersion = $null
        RequiredVersion = 'ships with Deno'
        FinalVersion    = $null
        Source          = 'Deno'
        Status          = 'Unknown'
    }

    $denoCmd = Get-Command deno -ErrorAction SilentlyContinue
    if (-not $denoCmd) {
        Write-ErrorLog -Message 'Deno is not on PATH. The Deno task must succeed first.' -Source $ToolName
        $result.Status = 'Failed'
        return $result
    }

    if ($DryRun) {
        Write-InfoLog -Message "[DryRun] Would verify: deno $($ProbeArgs -join ' ')" -Source $ToolName
        $result.Status = 'DryRun'
        return $result
    }

    try {
        & deno @ProbeArgs *> $null
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = 1
    }

    $denoVersion = (& deno --version) 2>&1 | Select-Object -First 1
    $result.PreviousVersion = $denoVersion
    $result.FinalVersion = $denoVersion

    if ($exitCode -eq 0) {
        $result.Status = 'OK'
        Write-SuccessLog -Message 'Available.' -Source $ToolName
    } else {
        $result.Status = 'Failed'
        Write-ErrorLog -Message "Subcommand check failed (exit code $exitCode)." -Source $ToolName
    }

    return $result
}
