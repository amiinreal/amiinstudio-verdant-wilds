# Signing & trusted distribution

This documents how the Amiin Studio Launcher is signed and distributed, why
that approach was chosen, and exactly what a Windows trust prompt does and
doesn't mean. Read this before changing anything under `Packaging/` or
`.github/workflows/release.yml`.

## The problem

Smart App Control and Microsoft Defender SmartScreen warn about (or block)
`AmiinLauncher.exe` because it's unsigned and has no publisher reputation.
Both checks are working as intended -- the fix is to give Windows a
legitimate reason to trust the app, not to work around the checks. This repo
will never disable Smart App Control/SmartScreen, install a trusted root
certificate on a user's machine, tell users to bypass a warning, or claim a
self-signed certificate makes the app publicly trusted.

## What was investigated, and why

| Option | Verdict | Why |
|---|---|---|
| **Microsoft Store / MSIX** | **Chosen** | Individual developer registration on Partner Center is free as of the Windows Developer Blog's September 2025 announcement, and Store-distributed MSIX packages are signed and hosted by Microsoft for free as part of certification. This is currently the best *free*, publicly trusted route for a small studio. |
| **SignPath Foundation** | Not eligible | SignPath Foundation's free signing is for genuinely open-source projects: OSI-approved license, publicly available source, no proprietary components (see signpath.org/terms.html). This repository is a closed commercial game/launcher with a private signed-release backend -- it doesn't qualify, and making it "open source" just to get free signing isn't a real option here. Revisit this only if the studio actually open-sources the launcher itself. |
| **Microsoft Trusted Signing (Azure Artifact Signing)** | Not free, kept as upgrade path | Currently priced from $9.99/month (Basic, 5,000 signatures/mo) -- see Azure's Trusted/Artifact Signing pricing page. Real Authenticode signing, works for the direct-download EXE/installer too, but it's a recurring cost, not a free option. The release pipeline below has a signing step already wired for this (or any Authenticode-compatible provider) so it's a config change, not a redesign, when the studio is ready to pay for it. |
| Self-signed certificate | Dev/test only | Never trusted by another machine unless that machine explicitly imports the certificate. Documented and scripted separately below -- never used for public releases. |

**Bottom line:** ship both distribution channels, as requested.

- **Microsoft Store (MSIX)** -- `Launcher/Packaging/`. Free, Microsoft-signed,
  the strongest trust story available at no cost. Requires an external,
  one-time Partner Center submission (see "Manual steps" below).
- **Direct download (EXE/installer)** -- unchanged `dotnet publish` +
  Inno Setup (`installer.iss`), still built and released. It will be
  unsigned until the studio pays for a real Authenticode certificate; the
  release pipeline is already wired to sign it automatically the moment
  that certificate exists (see "Enabling Authenticode signing later").

## Distinctions that matter (don't blur these)

- **HTTPS/TLS** protects the *download connection* -- it says nothing about
  who published the file. It does not sign the EXE.
- **Authenticode signature**: cryptographic proof of *which certificate*
  signed a binary, and that it hasn't been altered since. It does not by
  itself mean the certificate is trusted.
- **Trusted publisher / certificate trust**: whether the signing
  certificate chains to a root Windows already trusts (a real CA, or
  Microsoft's Store signing root). A self-signed cert has a valid
  Authenticode signature but no certificate trust on other machines.
- **SmartScreen reputation**: separate from signing. Even a validly signed,
  trusted-certificate binary can get a "few known reports" style warning
  until enough Windows installs have run it and reported clean. Signing
  makes reputation accumulate *per-certificate* instead of per-file-hash
  (which is why unsigned apps effectively can never build reputation --
  every new build is a brand new, zero-reputation hash).
- **Smart App Control**: a stricter allow-listing layer. It leans heavily
  on Microsoft's own signal (Store apps, well-known signed publishers).
  Store distribution is the most direct way to satisfy it without buying a
  certificate.

**No signing method here is being sold as "SmartScreen will never warn
again."** A brand-new Store listing or a brand-new Authenticode certificate
both still have to earn reputation over time; Store distribution just starts
from a much stronger trust baseline than an unsigned or self-signed EXE.

## Repository layout

```
Launcher/
  Packaging/
    Package.appxmanifest      MSIX manifest (has REPLACE-ME placeholders -- see below)
    Assets/                   Store tile/icon images, generated from Logo/X8y06N.png
    generate-assets.py        Regenerates Assets/ if the logo changes
    build-msix.ps1            dotnet publish -> stage -> makeappx pack -> (optional dev-sign)
    New-DevCertificate.ps1    DEV-ONLY self-signed cert generator (see warnings in the script)
    Sign-Verify.ps1           Shared PUBLIC RELEASE signing helper: sign one binary with
                              Authenticode (SHA-256 + RFC 3161 timestamp), then verify it.
                              Used by release.yml for the launcher exe and the installer
                              wrapper -- never for the MSIX (see "MSIX" above).
  installer.iss                Inno Setup installer for the direct-download EXE (unchanged flow)
.github/workflows/
  build-launcher.yml           Existing PR/push build+test (unchanged)
  release.yml                  New: tag-triggered release pipeline (build, test, publish,
                                package EXE+installer+MSIX, optional Authenticode sign,
                                verify, SHA-256 hashes, GitHub Release)
```

## The release pipeline

Triggered by pushing a tag like `launcher-v0.2.1`:

```
restore -> build -> test (Launcher/tests) -> dotnet publish (self-contained, win-x64)
  -> sign + verify the launcher exe (ONLY if AUTHENTICODE_* secrets are configured;
     otherwise skipped with a clear warning, never silently "succeeds")
  -> zip the (signed-or-not) exe for direct download
  -> build the Inno Setup installer from that same exe
  -> sign + verify the installer wrapper (same condition as above)
  -> build the MSIX (always left unsigned -- see "MSIX" above)
  -> sha256 hashes for every artifact (SHA256SUMS.txt)
  -> GitHub Release with all artifacts attached
```

Signing happens *before* packaging (not after) so the Inno Setup installer
embeds the already-signed exe, and the installer wrapper itself gets its own,
separate signature afterward -- it's a distinct PE binary from the payload it
carries. If signing was expected (secrets configured) and `signtool verify`
fails on either binary, the job fails immediately rather than shipping a
release that merely claims to be signed.

No certificate, password, or token is ever written into the repository.
Everything sensitive comes from GitHub Actions repository secrets.

### Enabling Authenticode signing later

The moment the studio has a real Authenticode certificate (Trusted
Signing/Azure Artifact Signing, or a traditional OV/EV cert from any CA),
signing turns on by adding secrets -- no workflow redesign needed:

- `AUTHENTICODE_PFX_BASE64` -- the certificate+key, base64-encoded
  (`certutil -encode cert.pfx cert.b64` on Windows, or
  `base64 -w0 cert.pfx` on Linux/macOS).
- `AUTHENTICODE_PFX_PASSWORD` -- its password.
- `AUTHENTICODE_TIMESTAMP_URL` *(optional)* -- defaults to
  `http://timestamp.digicert.com`, a documented, widely-supported RFC 3161
  timestamp service. If your CA/provider documents a different endpoint
  (Trusted Signing uses its own), set this secret to that URL instead of
  editing the workflow.

With those secrets present, `release.yml` signs `AmiinLauncher.exe`, the
Inno Setup installer output, and the MSIX, using SHA-256 digest + RFC 3161
SHA-256 timestamp, then runs `signtool verify /pa` on each and fails the
job if verification doesn't pass. Without those secrets, the job still
completes and produces unsigned artifacts (today's baseline) -- it does not
silently pretend to have signed anything.

### Microsoft Trusted Signing specifically

If the studio picks Azure Artifact Signing (formerly Trusted Signing)
instead of a PFX-based certificate, the signing step differs (it uses
`azuresigntool` or the `trusted-signing-cli` action with an Azure identity
rather than a PFX secret). That's a small, isolated change to the single
"sign" step in `release.yml` -- everything else in this document (package,
verify, hash, release) stays the same.

## Manual/external steps (cannot be automated from this repo)

These require a human with account access -- nothing here can create them:

1. **Register a free Microsoft Store individual developer account** at
   [partner.microsoft.com/dashboard](https://partner.microsoft.com/dashboard)
   (individual registration has been free since the September 2025 rollout).
2. **Reserve the app name** ("Amiin Studio Launcher" or your preferred
   name) in Partner Center. This is also where the game itself (The Verdant
   Wilds) can eventually get its own Store listing if you want one.
3. **Copy the real package identity** Partner Center assigns you (Package
   Name, Publisher CN, Publisher Display Name) into
   `Launcher/Packaging/Package.appxmanifest`, replacing every `REPLACE-ME`
   placeholder. `build-msix.ps1` will warn loudly if you forget.
4. **Build and upload** `Launcher/Packaging/build-msix.ps1`'s output (or the
   `release.yml` MSIX artifact) to a new submission in Partner Center.
   Upload it **unsigned** -- Microsoft signs it during certification.
5. *(Optional, later)* If/when the studio wants the direct-download EXE
   itself Authenticode-signed too, purchase a certificate (a traditional CA
   cert, or Azure Artifact Signing at $9.99/mo) and add the
   `AUTHENTICODE_*` secrets described above to the GitHub repository
   (Settings > Secrets and variables > Actions).
6. *(Optional)* If the launcher is ever genuinely open-sourced, re-check
   SignPath Foundation eligibility at signpath.org -- it would let the
   direct-download EXE get a real, free Authenticode signature too.

Nothing above should be automated by CI or by an assistant: Partner Center
identity, payment, and account creation are the studio's decisions to make.
