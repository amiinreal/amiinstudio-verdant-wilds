; Amiin Studio Launcher installer. Packages the self-contained launcher build
; (see build_release.ps1 / dotnet publish output) into a normal Windows
; installer for first-time downloads. In-app auto-updates still use the plain
; zip via Updates.cs -- this installer is only the first-run experience.
#define MyAppName "Amiin Studio Launcher"
#define MyAppVersion "0.3.2"
#define MyAppPublisher "Amiin Studio"
#define MyAppExeName "AmiinLauncher.exe"
#define SourceDir "..\Releases\launcher-0.3.2"

[Setup]
AppId={{6C6F5E1E-6B0D-4A9E-9B1A-3E3B9F0C4B21}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Amiin Studio\Launcher
DefaultGroupName=Amiin Studio
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=..\Releases
OutputBaseFilename=AmiinLauncherSetup-{#MyAppVersion}
SetupIconFile=launcher.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\AmiinLauncher.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\launcher-config.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\Assets\amiin-logo.png"; DestDir: "{app}\Assets"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Amiin Studio now"; Flags: nowait postinstall skipifsilent
