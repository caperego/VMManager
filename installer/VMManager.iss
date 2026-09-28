#define AppVersion "0.3.6"

[Setup]
AppId={{7C366599-53F7-4C1B-9A3C-3EA47DB8359B}
AppName=VM Manager
AppVersion={#AppVersion}
AppPublisher=SistemaSAE
SetupIconFile=..\assets\VMManager.ico
UninstallDisplayIcon={app}\VMManager.exe
DefaultDirName={autopf}\VMManager
DefaultGroupName=VM Manager
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=VMManager-Setup-{#AppVersion}-x64
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
SetupLogging=yes
UninstallDisplayName=VM Manager
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked

[Files]
Source: "..\bin\VMManager-0.3.6.exe"; DestDir: "{app}"; DestName: "VMManager.exe"; Flags: ignoreversion
Source: "..\bin\ConsoleBridge.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\bin\SSHAskPass.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\splash.png"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\VMManager.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; DestName: "LEIA-ME.txt"; Flags: ignoreversion
Source: "THIRD-PARTY-NOTICES.txt"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "vendor\license\virt-viewer-COPYING.txt"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "vendor\virt-viewer-11.0.tar.xz"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "vendor\virt-viewer-x64-11.0-1.0.msi"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\VM Manager"; Filename: "{app}\VMManager.exe"
Name: "{autodesktop}\VM Manager"; Filename: "{app}\VMManager.exe"; Tasks: desktopicon
Name: "{group}\Desinstalar VM Manager"; Filename: "{uninstallexe}"

[Run]
Filename: "{sys}\msiexec.exe"; Parameters: "/i ""{tmp}\virt-viewer-x64-11.0-1.0.msi"" /passive /norestart"; StatusMsg: "Instalando o virt-viewer e seus componentes..."; Flags: waituntilterminated runhidden
Filename: "{app}\VMManager.exe"; Description: "Abrir VM Manager"; Flags: postinstall nowait skipifsilent

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';
  if FileExists(ExpandConstant('{sys}\OpenSSH\ssh.exe')) then
    Exit;

  if MsgBox('O Cliente OpenSSH do Windows, usado para conexões seguras ao servidor Linux, não está habilitado.' + #13#10 + #13#10 +
    'O instalador pode ativá-lo como recurso opcional do Windows. Isso pode baixar componentes do Windows Update e requer conexão com a internet. Continuar?',
    mbConfirmation, MB_YESNO) <> IDYES then begin
    Result := 'Ative o recurso opcional "Cliente OpenSSH" do Windows e execute o instalador novamente.';
    Exit;
  end;

  if not Exec(ExpandConstant('{sys}\dism.exe'),
    '/Online /Add-Capability /CapabilityName:OpenSSH.Client~~~~0.0.1.0 /NoRestart',
    '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode) then begin
    Result := 'Não foi possível iniciar o DISM para habilitar o Cliente OpenSSH. Ative o recurso opcional do Windows manualmente e tente novamente.';
    Exit;
  end;
  if ResultCode = 3010 then
    NeedsRestart := True;
  if ((ResultCode <> 0) and (ResultCode <> 3010)) or not FileExists(ExpandConstant('{sys}\OpenSSH\ssh.exe')) then
    Result := 'O Windows não conseguiu instalar o Cliente OpenSSH. Confira o Windows Update e tente novamente, ou ative "Cliente OpenSSH" em Configurações > Sistema > Recursos opcionais.';
end;
