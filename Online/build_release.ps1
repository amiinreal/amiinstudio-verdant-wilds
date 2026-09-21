param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string]$Version = '0.1.0',
    [string]$Python = 'python',
    [string]$Dotnet = 'dotnet'
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+([.-][A-Za-z0-9]+)*$') { throw 'Invalid game version' }
$project = Split-Path $PSScriptRoot -Parent
$release = Join-Path $project 'Releases'
$game = Join-Path $release "game-$Version"
$launcher = Join-Path $release 'launcher-0.1.0'
New-Item -ItemType Directory -Force -Path $game,$launcher | Out-Null
if (!(Test-Path (Join-Path $project 'Launcher/launcher-config.json'))) { throw 'Run release_tool.py keygen first.' }
& $Dotnet publish (Join-Path $project 'Launcher/AmiinLauncher.csproj') -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o $launcher
if ($LASTEXITCODE -ne 0) { throw 'Launcher publish failed' }
$metadata = Join-Path $project 'Adventure/release.json'
if (Test-Path $metadata) { throw 'Existing release.json found. Preserve or remove it before building.' }
try {
    @{version=$Version;protocol=1} | ConvertTo-Json | Set-Content -LiteralPath $metadata -Encoding utf8
    & $Godot --headless --path $project --export-pack 'Windows Launcher' (Join-Path $game 'VerdantWilds.pck') --log-file (Join-Path $project 'Adventure/qa/export.log')
    if ($LASTEXITCODE -ne 0) { throw 'Game pack export failed' }
} finally {
    if (Test-Path $metadata) { Remove-Item -LiteralPath $metadata }
}
# Local test fallback when release templates are not installed. This is explicitly
# labelled below; public distribution requires a proper Godot export template.
$engine = $Godot.Replace('_console.exe','.exe')
Copy-Item -LiteralPath $engine -Destination (Join-Path $game 'VerdantWilds.exe') -Force
@'
LOCAL TEST PACKAGE: uses the Godot editor runtime because export templates are
not installed. Replace this executable with the official matching Windows
release template and include Godot's copyright/third-party notices before a
public release. The .pck is the exported game. No backend keys are included.
'@ | Set-Content -LiteralPath (Join-Path $game 'LOCAL-TEST-RUNTIME.txt')
& $Python (Join-Path $PSScriptRoot 'zip_release.py') $game (Join-Path $release "game-$Version.zip")
if ($LASTEXITCODE -ne 0) { throw 'Game archive failed' }
& $Python (Join-Path $PSScriptRoot 'zip_release.py') $launcher (Join-Path $release 'launcher-0.1.0.zip')
if ($LASTEXITCODE -ne 0) { throw 'Launcher archive failed' }
Write-Output "Packages built in $release. They are local test packages until hosting and release runtime are configured."
