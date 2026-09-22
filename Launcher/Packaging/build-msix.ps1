#Requires -Version 5.1
<#
.SYNOPSIS
    Packages the published launcher as an MSIX for Microsoft Store submission
    or local sideload testing.

.DESCRIPTION
    This does NOT sign the package for public trust. Two distinct paths:

      - Store submission (recommended, free): upload the UNSIGNED .msix this
        script produces to Partner Center. Microsoft validates and signs it
        as part of certification -- that is what makes it trusted on other
        people's machines. Do not sign it yourself first.

      - Local sideload testing on YOUR OWN dev machine only: pass
        -DevSign to also sign with a throwaway self-signed certificate
        (see New-DevCertificate.ps1). A machine can only install a
        sideloaded MSIX if it already trusts that certificate, which is why
        this is development-only and never a public distribution method.

.PARAMETER Configuration
    Build configuration to publish (default: Release).

.PARAMETER Version
    Package version in a.b.c.d form. Defaults to the value already in
    Package.appxmanifest.

.PARAMETER DevSign
    If set, signs the resulting .msix with Packaging/dev-cert.pfx for local
    sideload testing. Requires New-DevCertificate.ps1 to have been run first.
    NEVER use this output for public distribution.

.EXAMPLE
    pwsh Launcher/Packaging/build-msix.ps1
    Produces an unsigned MSIX ready to upload to Partner Center.

.EXAMPLE
    pwsh Launcher/Packaging/build-msix.ps1 -DevSign
    Produces an MSIX signed with the local dev certificate, installable only
    on machines that have explicitly trusted that certificate.
#>
param(
    [string]$Configuration = "Release",
    [string]$Version,
    [switch]$DevSign
)
$ErrorActionPreference = "Stop"

$packagingDir = $PSScriptRoot
$launcherDir = Split-Path $packagingDir -Parent
$repoRoot = Split-Path $launcherDir -Parent
$publishDir = Join-Path $repoRoot "Releases/msix-publish"
$stagingDir = Join-Path $repoRoot "Releases/msix-staging"
$outDir = Join-Path $repoRoot "Releases"

function Find-WindowsSdkTool([string]$Name) {
    $candidate = Get-Command $Name -ErrorAction SilentlyContinue
    if ($candidate) { return $candidate.Source }
    $roots = @("${env:ProgramFiles(x86)}\Windows Kits\10\bin", "${env:ProgramFiles}\Windows Kits\10\bin")
    foreach ($root in $roots) {
        if (Test-Path $root) {
            $found = Get-ChildItem -Path $root -Filter $Name -Recurse -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    throw "$Name not found. Install the Windows 10/11 SDK (includes makeappx.exe / signtool.exe)."
}

Write-Host "==> Cleaning previous MSIX build output"
Remove-Item -Recurse -Force $publishDir, $stagingDir -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $publishDir, $stagingDir, $outDir | Out-Null

Write-Host "==> Publishing launcher (self-contained, win-x64)"
$csproj = Join-Path $launcherDir "AmiinLauncher.csproj"
dotnet publish $csproj -c $Configuration -r win-x64 --self-contained true `
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $publishDir
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }

Write-Host "==> Staging MSIX package contents"
Copy-Item -Path (Join-Path $publishDir "*") -Destination $stagingDir -Recurse -Force
Copy-Item -Path (Join-Path $packagingDir "Assets") -Destination $stagingDir -Recurse -Force

$manifestSource = Join-Path $packagingDir "Package.appxmanifest"
$manifestStaged = Join-Path $stagingDir "AppxManifest.xml"
if ($Version) {
    Write-Host "==> Stamping manifest version $Version"
    # Negative lookbehind so this only matches the Identity element's own
    # Version="..." attribute, not MinVersion="..."/MaxVersionTested="...".
    (Get-Content $manifestSource -Raw) -replace '(?<![A-Za-z])Version="[0-9.]+"', "Version=`"$Version`"" |
        Set-Content -LiteralPath $manifestStaged -Encoding utf8
} else {
    Copy-Item -Path $manifestSource -Destination $manifestStaged -Force
}

$manifestText = Get-Content $manifestStaged -Raw
if ($manifestText -match 'REPLACE-ME') {
    Write-Warning "Package.appxmanifest still has REPLACE-ME placeholders (Identity/Publisher)."
    Write-Warning "The .msix will build, but Partner Center will reject it until you paste in"
    Write-Warning "your real package identity from the app's page in Partner Center."
}

$makeAppx = Find-WindowsSdkTool "makeappx.exe"
$versionLabel = if ($Version) { $Version } else { "dev" }
$msixPath = Join-Path $outDir "AmiinLauncher-$versionLabel.msix"
Write-Host "==> Packing MSIX: $msixPath"
& $makeAppx pack /d $stagingDir /p $msixPath /overwrite
if ($LASTEXITCODE -ne 0) { throw "makeappx pack failed" }

if ($DevSign) {
    Write-Host "==> DEV-ONLY signing for local sideload testing (NOT for public distribution)"
    $devCert = Join-Path $packagingDir "dev-cert.pfx"
    if (-not (Test-Path $devCert)) {
        throw "dev-cert.pfx not found. Run Packaging/New-DevCertificate.ps1 first."
    }
    $signTool = Find-WindowsSdkTool "signtool.exe"
    $securePassword = Read-Host "Dev certificate password" -AsSecureString
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
    & $signTool sign /fd SHA256 /a /f $devCert /p $plainPassword $msixPath
    if ($LASTEXITCODE -ne 0) { throw "Dev-signing failed" }
    Write-Host "Signed with the DEVELOPMENT certificate. This package will only install"
    Write-Host "on machines that have explicitly trusted that certificate. It is not a"
    Write-Host "publicly trusted package -- see Launcher/SIGNING.md."
} else {
    Write-Host "==> Package left UNSIGNED. Upload it to Partner Center as-is;"
    Write-Host "    Microsoft signs it during certification."
}

Write-Host "==> Done: $msixPath"
