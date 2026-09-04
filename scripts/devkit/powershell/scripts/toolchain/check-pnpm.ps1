#Requires -Version 7.0
<#
.NOTES
    Depends on Node.js (task graph: DependsOn = 'Node.js').
    pnpm is installed/pinned via corepack, matching pnpm's current official
    recommendation, rather than a standalone installer or winget package.

    IMPORTANT: Node.js 25 stopped bundling corepack (it now has to be
    installed separately via `npm install -g corepack`). Node 22/24 LTS
    still ship it. This script does not assume either way - if `corepack`
    isn't found after Node.js is confirmed present, it installs it via npm
    first, then proceeds. Keeps working regardless of which Node.js line
    project-paths/tool-versions ends up pinning.
#>

param(
    [string]$RequiredVersion = '9.0.0',
    [switch]$DryRun
)

. "$PSScriptRoot/../common/tool-check-helper.ps1"

$getVersion = {
    $cmd = Get-Command pnpm -ErrorAction SilentlyContinue
    if ($cmd) {
        (& pnpm --version) 2>&1 | Select-Object -First 1
    } else {
        $null
    }
}

$upstreamInstall = {

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        throw 'Node.js is missing.'
    }

    if (-not (Get-Command corepack -ErrorAction SilentlyContinue)) {
        Write-WarningLog -Message 'corepack not found (Node.js 25+ no longer bundles it); installing via npm...' -Source 'pnpm'
        & npm install -g corepack
        if ($LASTEXITCODE -ne 0) {
            throw "npm install -g corepack failed (exit code $LASTEXITCODE)."
        }
    }

    & corepack enable
    if ($LASTEXITCODE -ne 0) {
        throw "corepack enable failed (exit code $LASTEXITCODE)."
    }

    & corepack prepare pnpm@latest --activate
    if ($LASTEXITCODE -ne 0) {
        throw "corepack prepare pnpm@latest failed (exit code $LASTEXITCODE)."
    }

    Sync-EnvironmentPath
}

Invoke-ToolCheck `
    -ToolName 'pnpm' `
    -RequiredVersion $RequiredVersion `
    -DryRun:$DryRun `
    -WingetId $null `
    -GetVersionRaw $getVersion `
    -UpstreamInstall $upstreamInstall
