; Builds Paraplay-Setup.exe from the folder the workflow assembles.
; Run:  iscc /DAppVersion=0.7.0 /DDistDir=C:\path\to\dist /DOutDir=C:\path\out paraplay.iss
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef DistDir
  #define DistDir "dist"
#endif
#ifndef OutDir
  #define OutDir "."
#endif

[Setup]
AppId={{6D1B8C52-7F4E-4C79-9A3B-2E5F1D0B7A64}
AppName=Paraplay
AppVersion={#AppVersion}
AppPublisher=whozdgt
AppPublisherURL=https://github.com/whozdgt/Paraplay
; Installs for the current person only, so no administrator prompt is needed.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\Paraplay
DefaultGroupName=Paraplay
DisableProgramGroupPage=yes
OutputDir={#OutDir}
OutputBaseFilename=Paraplay-Setup
SetupIconFile=musicplayer.ico
UninstallDisplayIcon={app}\musicplayer.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; The Intel/AMD build also runs on Windows on ARM (it is emulated there).
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Tasks]
Name: "desktopicon"; Description: "Put a Paraplay shortcut on the desktop"; Flags: unchecked

[Files]
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Paraplay"; Filename: "{app}\musicplayer.exe"
Name: "{autodesktop}\Paraplay"; Filename: "{app}\musicplayer.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\musicplayer.exe"; Description: "Start Paraplay"; Flags: nowait postinstall skipifsilent
