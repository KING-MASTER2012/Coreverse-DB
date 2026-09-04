#Requires -Version 7.0
<#
.SYNOPSIS
    Resolves yes/no install decisions for optional tools (Semgrep, SQLFluff,
    deno audit) up front, before any parallel installation work starts.

.DESCRIPTION
    Precedence, per tool id:
      1) -Reject <id> or -Reject 'none'  -> not installed, never asked.
      2) -Accept <id> or -Accept 'all'   -> installed, never asked.
      3) Neither given                   -> interactive Y/n prompt
                                             (defaults to 'No' in -Yes /
                                             non-interactive runs).
    If an id appears in both -Accept and -Reject (and neither 'all' nor
    'none' was used), -Reject wins and a warning is logged - see
    bootstrap.ps1 -Accept / -Reject documentation.

    This intentionally does NOT pre-check whether the tool is already
    installed before asking: Invoke-ToolCheck (tool-check-helper.ps1) is
    already idempotent (it does nothing if the version is already
    sufficient), so answering "y" for an already-installed tool is
    harmless. Keeping this phase simple (ask first, let the check script
    figure out whether there's actually anything to do) avoids running
    every optional tool's check logic twice.
#>

. "$PSScriptRoot/logger.ps1"

function Resolve-OptionalToolDecisions {
    param(
        [Parameter(Mandatory)][array]$Catalog,   # @(@{ Id = 'semgrep'; DisplayName = '...' }, ...)
        [string[]]$Accept = @(),
        [string[]]$Reject = @(),
        [switch]$Yes,
        [switch]$DryRun
    )

    $decisions = @{}
    $acceptAll = $Accept -contains 'all'
    $rejectAll = $Reject -contains 'none'

    foreach ($item in $Catalog) {
        $id = $item.Id
        $name = $item.DisplayName

        $inReject = $rejectAll -or ($Reject -contains $id)
        $inAccept = $acceptAll -or ($Accept -contains $id)

        if ($inReject -and $inAccept -and -not $rejectAll -and -not $acceptAll) {
            Write-WarningLog -Message "'$id' is listed in both -Accept and -Reject; -Reject takes precedence." -Source 'OptionalTools'
        }

        if ($inReject) {
            $decisions[$id] = $false
            Write-InfoLog -Message "${name}: skipped (--reject)." -Source 'OptionalTools'
            continue
        }

        if ($inAccept) {
            $decisions[$id] = $true
            Write-InfoLog -Message "${name}: approved (--accept)." -Source 'OptionalTools'
            continue
        }

        if ($Yes) {
            $decisions[$id] = $false
            Write-WarningLog -Message "${name}: -Yes given without -Accept/-Reject for this tool; defaulting to skipped." -Source 'OptionalTools'
            continue
        }

        if (-not [Environment]::UserInteractive) {
            $decisions[$id] = $false
            Write-WarningLog -Message "${name}: non-interactive session and no -Accept/-Reject given; defaulting to skipped." -Source 'OptionalTools'
            continue
        }

        $answer = Read-Host "Install ${name}? [y/N]"
        $decisions[$id] = ($answer -match '^(y|yes)$')
    }

    return $decisions
}
