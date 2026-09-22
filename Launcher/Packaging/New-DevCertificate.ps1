#Requires -Version 5.1
<#
.SYNOPSIS
    Creates a throwaway self-signed certificate for LOCAL DEVELOPMENT / SIDELOAD
    TESTING ONLY.

.DESCRIPTION
    ============================================================================
    THIS IS NOT A PUBLIC TRUST SOLUTION. READ BEFORE RUNNING.
    ============================================================================
    A self-signed certificate signs a binary, but Windows will not trust that
    signature on anyone else's machine -- Smart App Control and SmartScreen
    both key off a publicly trusted, reputable certificate chain (or Store
    certification), neither of which a self-signed cert has. This script
    exists only so you can:

      - sign an MSIX well enough to sideload-install it on YOUR OWN dev
        machine (after you've manually trusted this specific certificate in
        that machine's Trusted People / Trusted Root store), or
      - smoke-test the CI signing step locally before wiring up a real
        certificate.

    This script does NOT and MUST NOT:
      - install the certificate into any OTHER user's or machine's trust
        store (it only ever touches the CURRENT user's CurrentUser\My store
        on the machine you run it on);
      - be presented to end users as a reason to trust the app;
      - be committed to source control (dev-cert.pfx is gitignored) or
        shipped in a release.

    For PUBLIC release signing, see SIGNING.md -- the two supported paths are
    Microsoft Store/MSIX certification (free) or a real Authenticode
    certificate from a CA/Trusted Signing (paid), wired through
    .github/workflows/release.yml's optional signing step.

.PARAMETER Subject
    Certificate subject. Defaults to a clearly-labeled dev identity so it's
    never mistaken for the real publisher.
#>
param(
    [string]$Subject = "CN=Amiin Studio DEV-ONLY Test Certificate, O=Amiin Studio, C=NO"
)
$ErrorActionPreference = "Stop"

# Windows PowerShell (5.1) is always Windows; pwsh (6+) sets $IsWindows explicitly.
if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    throw "New-SelfSignedCertificate requires Windows PowerShell / PowerShell on Windows."
}

$packagingDir = $PSScriptRoot
$pfxPath = Join-Path $packagingDir "dev-cert.pfx"

if (Test-Path $pfxPath) {
    throw "dev-cert.pfx already exists at $pfxPath. Delete it first if you really want a new one."
}

Write-Host "Creating a DEVELOPMENT-ONLY self-signed code-signing certificate."
Write-Host "Subject: $Subject"
Write-Host "This certificate will NOT be trusted on any machine that hasn't explicitly imported it."
Write-Host ""

$cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $Subject `
    -KeyUsage DigitalSignature `
    -FriendlyName "Amiin Studio DEV-ONLY code signing (not for distribution)" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
    -NotAfter (Get-Date).AddYears(1)

$password = Read-Host "Set a password to protect dev-cert.pfx" -AsSecureString
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password | Out-Null

# Remove it from the CurrentUser\My store now that it's exported -- keeping only
# the file avoids leaving an extra copy of a "trust me" identity lying around
# in the certificate store after this script exits.
Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force

Write-Host ""
Write-Host "Wrote $pfxPath (gitignored -- do not commit it)."
Write-Host ""
Write-Host "To sideload-install packages signed with this certificate on THIS machine,"
Write-Host "you must separately import it into Trusted People yourself, e.g.:"
Write-Host "  Import-PfxCertificate -FilePath `"$pfxPath`" -CertStoreLocation Cert:\LocalMachine\TrustedPeople"
Write-Host "Never script that import against a machine you don't own or administer."
