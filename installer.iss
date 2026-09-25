; Script de Inno Setup para crear el instalador de Concursos CASART
; Genera un instalador .exe tradicional para Windows

#define MyAppName "Concursos CASART"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "CASART - IAM"
#define MyAppURL "https://iam.gob.mx"
#define MyAppExeName "concursos-casart-angel.exe"

[Setup]
; Identificador único de la app
AppId={{62BB2A9A-F925-4568-BF4D-430D8A44A5AC}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
; Ubicación donde se generará el instalador
OutputDir=build\installer
OutputBaseFilename=Instalador_Concursos_CASART
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Ejecutable principal
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; Librerías DLL necesarias (flutter_windows.dll, sqlite3.dll, pdfium.dll, printing_plugin.dll, etc.)
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
; Carpeta data completa (activos de Flutter, fuentes, binarios compilados)
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
