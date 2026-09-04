#Requires -Version 7.0
<#
.NOTES
    Depends on Deno (task graph: DependsOn = 'Deno'). Not a separate
    install - the V8 Inspector is a flag on `deno run`/`deno test`
    (--inspect / --inspect-brk / --inspect-wait), not a standalone binary.

    Unlike lint/fmt/check, there is no dedicated `deno inspect --help`
    subcommand to probe, and actually opening an inspector socket just to
    verify it works would leave a listener behind / needs a real script to
    attach to. Instead this checks that the installed Deno build advertises
    the --inspect flag on `deno run --help`, which is the cheapest reliable
    signal that the Inspector is compiled in.
#>

param(
    [switch]$DryRun
)

. "$PSScriptRoot/../common/logger.ps1"

$ToolName = 'Deno Inspector'

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
    Write-InfoLog -Message '[DryRun] Would verify: deno run --help advertises --inspect.' -Source $ToolName
    $result.Status = 'DryRun'
    return $result
}

$denoVersion = (& deno --version) 2>&1 | Select-Object -First 1
$result.PreviousVersion = $denoVersion
$result.FinalVersion = $denoVersion

$helpText = (& deno run --help) 2>&1 | Out-String

if ($helpText -match '--inspect') {
    $result.Status = 'OK'
    Write-SuccessLog -Message 'Available (--inspect flag present).' -Source $ToolName
} else {
    $result.Status = 'Failed'
    Write-ErrorLog -Message 'This Deno build does not advertise --inspect.' -Source $ToolName
}

return $result
