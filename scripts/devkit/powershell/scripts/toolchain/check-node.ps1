#Requires -Version 7.0
<#
.NOTES
    Added for the src/ React package (pnpm scripts - tsc, vite, orval
    codegen, etc. - all need a real Node.js runtime on PATH). pnpm depends
    on this task (task graph: DependsOn = 'Node.js').
#>

param(
    [string]$RequiredVersion = '22.0.0',
    [switch]$DryRun
)

. "$PSScriptRoot/../common/tool-check-helper.ps1"

$getVersion = {
    $cmd = Get-Command node -ErrorAction SilentlyContinue
    if ($cmd) {
        (& node --version) 2>&1 | Select-Object -First 1
    } else {
        $null
    }
}

$upstreamInstall = {

    # winget is expected to cover the common case (OpenJS.NodeJS.LTS); this
    # upstream fallback only runs if winget is unavailable/insufficient.
    # Query the official release index for the newest LTS build and install
    # its Windows x64 MSI silently.
    $index = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json'
    $ltsRelease = $index | Where-Object { $_.lts } | Select-Object -First 1

    if (-not $ltsRelease) {
        throw 'No LTS release found in the Node.js release index.'
    }

    $version = $ltsRelease.version  # e.g. 'v22.14.0'
    $msiName = "node-$version-x64.msi"
    $downloadUrl = "https://nodejs.org/dist/$version/$msiName"
    $installerPath = Join-Path $env:TEMP $msiName

    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

    $msiArgs = @('/i', "`"$installerPath`"", '/quiet', '/norestart')
    $proc = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru

    if ($proc.ExitCode -ne 0) {
        throw "msiexec failed while installing Node.js $version (exit code $($proc.ExitCode))."
    }

    Sync-EnvironmentPath
}

Invoke-ToolCheck `
    -ToolName 'Node.js' `
    -RequiredVersion $RequiredVersion `
    -DryRun:$DryRun `
    -WingetId 'OpenJS.NodeJS.LTS' `
    -GetVersionRaw $getVersion `
    -UpstreamInstall $upstreamInstall
