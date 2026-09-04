#Requires -Version 7.0
<#
.NOTES
    Depends on Deno (task graph: DependsOn = 'Deno'). Not a separate
    install - see deno-subtool-check.ps1.
#>

param(
    [switch]$DryRun
)

. "$PSScriptRoot/../common/deno-subtool-check.ps1"

Invoke-DenoSubcommandCheck `
    -ToolName 'Deno Fmt' `
    -ProbeArgs @('fmt', '--help') `
    -DryRun:$DryRun
