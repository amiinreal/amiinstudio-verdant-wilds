#Requires -Version 5.1
<#
.SYNOPSIS
    Authenticode-signs a single release binary with SHA-256 + RFC 3161 SHA-256
    timestamping, then immediately verifies the result with signtool. Throws
    (failing the calling CI job) if signing or verification doesn't succeed.

.DESCRIPTION
    Used by .github/workflows/release.yml for both the launcher exe and the
    Inno Setup installer wrapper -- each is a distinct PE binary and needs its
    own signature. Never used for the MSIX artifact (see Launcher/SIGNING.md:
    Store-bound MSIX packages are uploaded unsigned; Microsoft signs them).

    Reads the certificate and password from environment variables so the CI
    workflow never has to write a secret into a file it can't immediately
    delete:
      AUTHENTICODE_PFX_BASE64     Required. Base64-encoded PFX.
      AUTHENTICODE_PFX_PASSWORD   Required. Its password.
      AUTHENTICODE_TIMESTAMP_URL  Optional. Defaults to a documented public
                                  RFC 3161 SHA-256 timestamp service. If your
                                  certificate provider (e.g. Trusted Signing)
                                  documents a different endpoint, set this
                                  secret instead of editing this script.

.PARAMETER Target
    Path to the single binary to sign and verify.
#>
param(
    [Parameter(Mandatory = $true)][string]$Target
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Target)) { throw "Sign-Verify: target not found: $Target" }
if ([string]::IsNullOrEmpty($env:AUTHENTICODE_PFX_BASE64)) { throw "AUTHENTICODE_PFX_BASE64 is not set." }
if ([string]::IsNullOrEmpty($env:AUTHENTICODE_PFX_PASSWORD)) { throw "AUTHENTICODE_PFX_PASSWORD is not set." }

function Find-SignTool {
    $roots = @("${env:ProgramFiles(x86)}\Windows Kits\10\bin", "${env:ProgramFiles}\Windows Kits\10\bin")
    foreach ($root in $roots) {
        if (Test-Path $root) {
            $found = Get-ChildItem -Path $root -Filter "signtool.exe" -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match "\\x64\\" } | Sort-Object FullName -Descending | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    $onPath = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    throw "signtool.exe not found. Install the Windows 10/11 SDK."
}

$signTool = Find-SignTool
$timestampUrl = if ($env:AUTHENTICODE_TIMESTAMP_URL) { $env:AUTHENTICODE_TIMESTAMP_URL } else { "http://timestamp.digicert.com" }
$pfxPath = Join-Path ([IO.Path]::GetTempPath()) ("release-signing-" + [Guid]::NewGuid() + ".pfx")

try {
    [IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($env:AUTHENTICODE_PFX_BASE64))

    Write-Host "Signing $Target"
    & $signTool sign /fd SHA256 /f $pfxPath /p $env:AUTHENTICODE_PFX_PASSWORD /tr $timestampUrl /td SHA256 $Target
    if ($LASTEXITCODE -ne 0) { throw "signtool sign failed for $Target" }

    Write-Host "Verifying $Target"
    & $signTool verify /pa /all $Target
    if ($LASTEXITCODE -ne 0) { throw "Signature verification FAILED for $Target -- failing the release." }

    Write-Host "OK: $Target is signed and verified."
} finally {
    if (Test-Path $pfxPath) { Remove-Item $pfxPath -Force }
}
