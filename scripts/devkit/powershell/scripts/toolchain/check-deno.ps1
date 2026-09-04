#Requires -Version 7.0
<#
.NOTES
    Deno Lint / Deno Fmt / Deno Check / Deno Inspector all ship inside this
    same binary (see check-deno-lint.ps1 etc., task graph: DependsOn =
    'Deno'). This script is the single place that actually installs/updates
    Deno; the four sub-checks only verify a capability of whatever Deno
    ends up on PATH after this task completes.
#>

param(
    [string]$RequiredVersion = '2.5.5',
    [switch]$DryRun
)

. "$PSScriptRoot/../common/tool-check-helper.ps1"

$getVersion = {
    $cmd = Get-Command deno -ErrorAction SilentlyContinue
    if ($cmd) {
        (& deno --version) 2>&1 | Select-Object -First 1
    } else {
        $null
    }
}

$upstreamInstall = {

    # Official Windows installer - installs to $env:USERPROFILE\.deno\bin
    # and does not require administrator privileges.
    $installScript = Invoke-RestMethod -Uri 'https://deno.land/install.ps1'
    Invoke-Expression $installScript

    $denoBin = Join-Path $env:USERPROFILE '.deno\bin'

    if (Test-Path $denoBin) {

        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

        if ($userPath -notlike "*$denoBin*") {
            [Environment]::SetEnvironmentVariable(
                'Path',
                "$userPath;$denoBin",
                'User'
            )
        }

        $env:Path += ";$denoBin"
    }

    if (-not (Get-Command deno -ErrorAction SilentlyContinue)) {
        throw 'deno was not found on PATH after installation.'
    }
}

Invoke-ToolCheck `
    -ToolName 'Deno' `
    -RequiredVersion $RequiredVersion `
    -DryRun:$DryRun `
    -WingetId 'DenoLand.Deno' `
    -GetVersionRaw $getVersion `
    -UpstreamInstall $upstreamInstall
