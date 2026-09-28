unit VMCore;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Windows, Classes, SysUtils, Process, Pipes, IniFiles;
type
  THost = record
    Title, Address, UserName, KeyFile, Viewer: string;
    Port: Integer;
    ManagedKey: Boolean;
  end;
  THosts = array of THost;
  TVM = record UUID, Name, State: string; end;
  TVMs = array of TVM;
  TVMAction = (vaList, vaStart, vaShutdown, vaReboot, vaDestroy);
  TRemoteJob = class(TThread)
  private
    FHost: THost;
    FAction: TVMAction;
    FUUID: string;
    function Remote(const Command: string): string;
  protected
    procedure Execute; override;
  public
    VMs: TVMs;
    ErrorText, Notice: string;
    constructor Create(const Host: THost; Action: TVMAction; const UUID: string);
  end;
function ValidUUID(const S: string): Boolean;
procedure ValidateHost(const H: THost);
function BuildCommand(Action: TVMAction; const UUID: string): string;
procedure SSHArguments(const H: THost; const Command: string; Args: TStrings);
function SSHExecutable: string;
function FindVirtViewerExecutable(const ProgramFilesDir: string = ''): string;
function WindowsArgument(const S: string): string;
function RunCaptured(const Exe: string; Args: TStrings; TimeoutMS: QWord;
  Job: TThread; out Err: string): string;
function RunCapturedEnv(const Exe: string; Args, Env: TStrings; TimeoutMS: QWord;
  Job: TThread; out Err: string): string;
procedure LoadHosts(const FileName: string; out Hosts: THosts);
procedure SaveHosts(const FileName: string; const Hosts: THosts);
implementation
function WindowsArgument(const S: string): string;
var I,Slashes: Integer;
begin
  Result:='"'; Slashes:=0;
  for I:=1 to Length(S) do begin
    if S[I]='\' then Inc(Slashes)
    else begin
      if S[I]='"' then Result:=Result+StringOfChar('\',Slashes*2+1)+'"'
      else Result:=Result+StringOfChar('\',Slashes)+S[I];
      Slashes:=0;
    end;
  end;
  Result:=Result+StringOfChar('\',Slashes*2)+'"';
end;
function ValidUUID(const S: string): Boolean;
var I: Integer;
begin
  Result := False;
  if Length(S) <> 36 then Exit;
  for I := 1 to 36 do
    if I in [9,14,19,24] then begin if S[I] <> '-' then Exit; end
    else if not (S[I] in ['0'..'9','a'..'f','A'..'F']) then Exit;
  Result := True;
end;
procedure ValidateHost(const H: THost);
var I: Integer;
begin
  if Trim(H.Title) = '' then raise Exception.Create('Informe o nome do host.');
  if (H.Address = '') or (Length(H.Address)>253) then raise Exception.Create('Endereço inválido.');
  if not (H.Address[1] in ['a'..'z','A'..'Z','0'..'9']) then raise Exception.Create('Endereço inválido.');
  for I := 1 to Length(H.Address) do
    if not (H.Address[I] in ['a'..'z','A'..'Z','0'..'9','.', '-']) then
      raise Exception.Create('Use DNS ou IPv4. IPv6 e aliases SSH não são suportados nesta versão.');
  if H.UserName = '' then raise Exception.Create('Informe o usuário SSH.');
  if not (H.UserName[1] in ['a'..'z','A'..'Z','_']) then raise Exception.Create('Usuário inválido.');
  for I := 1 to Length(H.UserName) do
    if not (H.UserName[I] in ['a'..'z','A'..'Z','0'..'9','_','-','.']) then raise Exception.Create('Usuário inválido.');
  if (H.Port < 1) or (H.Port > 65535) then raise Exception.Create('Porta deve estar entre 1 e 65535.');
  if (Pos(#10,H.Title)>0) or (Pos(#13,H.Title)>0) then raise Exception.Create('Nome inválido.');
  if (H.KeyFile <> '') and not FileExists(H.KeyFile) then raise Exception.Create('Chave privada não encontrada.');
  if (H.Viewer <> '') and not FileExists(H.Viewer) then raise Exception.Create('virt-viewer.exe não encontrado.');
end;
function BuildCommand(Action: TVMAction; const UUID: string): string;
const Actions: array[TVMAction] of string = ('list --all --uuid','start','shutdown','reboot','destroy');
begin
  Result := 'LC_ALL=C virsh --connect qemu:///system ' + Actions[Action];
  if Action <> vaList then begin
    if not ValidUUID(UUID) then raise Exception.Create('UUID inválido; comando bloqueado.');
    Result := Result + ' ' + UUID;
  end;
end;
function SSHExecutable: string;
begin
  Result := GetEnvironmentVariable('WINDIR') + '\System32\OpenSSH\ssh.exe';
end;
function FindVirtViewerExecutable(const ProgramFilesDir: string): string;
var
  Roots: array[0..1] of string;
  RootIndex: Integer;
  Search: TSearchRec;
  Candidate, Root: string;
begin
  Result := '';
  if ProgramFilesDir <> '' then begin
    Roots[0] := ProgramFilesDir;
    Roots[1] := '';
  end else begin
    Roots[0] := GetEnvironmentVariable('ProgramFiles');
    Roots[1] := GetEnvironmentVariable('ProgramFiles(x86)');
  end;
  for RootIndex := 0 to High(Roots) do begin
    Root := Roots[RootIndex];
    if Root = '' then Continue;
    if FindFirst(IncludeTrailingPathDelimiter(Root) + 'VirtViewer*', faDirectory, Search) <> 0 then Continue;
    try
      repeat
        if (Search.Attr and faDirectory) = 0 then Continue;
        if (Search.Name = '.') or (Search.Name = '..') then Continue;
        Candidate := IncludeTrailingPathDelimiter(Root) + Search.Name + PathDelim +
          'bin' + PathDelim + 'virt-viewer.exe';
        if FileExists(Candidate) and FileExists(ExtractFilePath(Candidate) + 'remote-viewer.exe') then begin
          Result := Candidate;
          Exit;
        end;
      until FindNext(Search) <> 0;
    finally
      FindClose(Search);
    end;
  end;
end;
procedure SSHArguments(const H: THost; const Command: string; Args: TStrings);
  procedure Opt(const S: string);
  begin Args.Add('-o'); Args.Add(S); end;
begin
  ValidateHost(H);
  Args.Clear;
  Args.Add('-F'); Args.Add('NUL');
  Args.Add('-T');
  Opt('BatchMode=yes'); Opt('StrictHostKeyChecking=yes');
  Opt('ConnectTimeout=10'); Opt('ConnectionAttempts=1');
  Opt('ServerAliveInterval=5'); Opt('ServerAliveCountMax=2');
  Opt('ForwardAgent=no'); Opt('ClearAllForwardings=yes');
  Opt('PermitLocalCommand=no'); Opt('PasswordAuthentication=no');
  Opt('KbdInteractiveAuthentication=no'); Opt('LogLevel=ERROR');
  if H.KeyFile <> '' then begin
    Opt('IdentitiesOnly=yes'); Args.Add('-i'); Args.Add(H.KeyFile);
  end;
  Args.Add('-p'); Args.Add(IntToStr(H.Port));
  Args.Add('-l'); Args.Add(H.UserName);
  Args.Add(H.Address); Args.Add(Command);
end;
function RunCaptured(const Exe: string; Args: TStrings; TimeoutMS: QWord;
  Job: TThread; out Err: string): string;
begin
  Result:=RunCapturedEnv(Exe,Args,nil,TimeoutMS,Job,Err);
end;
function RunCapturedEnv(const Exe: string; Args, Env: TStrings; TimeoutMS: QWord;
  Job: TThread; out Err: string): string;
var P: TProcess; Started: QWord; Buffer: array[0..4095] of Byte; N,I: Integer; HadData: Boolean;
  procedure Drain(Stream: TInputPipeStream; var Dest: string);
  var Chunk: string;
  begin
    while Stream.NumBytesAvailable > 0 do begin
      N := Stream.Read(Buffer, SizeOf(Buffer));
      if N <= 0 then Break;
      HadData := True;
      SetString(Chunk, PChar(@Buffer[0]), N); Dest := Dest + Chunk;
      if Length(Dest)>4*1024*1024 then raise Exception.Create('Resposta excedeu 4 MiB.');
    end;
  end;
begin
  Result := ''; Err := ''; P := TProcess.Create(nil);
  try
    P.Executable := Exe; P.Parameters.Assign(Args);
    { FPC 3.2.2 does not escape embedded quotes or empty Windows arguments. }
    for I:=0 to P.Parameters.Count-1 do P.Parameters[I]:=WindowsArgument(P.Parameters[I]);
    if Env<>nil then P.Environment.Assign(Env);
    P.Options := [poUsePipes,poNoConsole]; P.PipeBufferSize := 65536; P.Execute; P.CloseInput;
    Started := GetTickCount64;
    repeat
      HadData := False;
      Drain(P.Output, Result); Drain(P.Stderr, Err);
      if (Job <> nil) and Job.CheckTerminated then raise Exception.Create('Operação cancelada; atualize para conferir o estado remoto.');
      if GetTickCount64-Started > TimeoutMS then raise Exception.Create('Tempo limite excedido; o comando pode ter sido aplicado. Atualize antes de tentar novamente.');
      if not P.Running then Break;
      if not HadData then Sleep(5);
    until False;
    Drain(P.Output, Result); Drain(P.Stderr, Err);
    if P.ExitStatus <> 0 then raise Exception.CreateFmt('SSH/virsh retornou %d: %s',[P.ExitStatus,Trim(Err)]);
  finally
    if P.Running then begin P.Terminate(1); P.WaitOnExit; end;
    P.Free;
  end;
end;
constructor TRemoteJob.Create(const Host: THost; Action: TVMAction; const UUID: string);
begin
  inherited Create(True); FreeOnTerminate := False;
  FHost := Host; FAction := Action; FUUID := UUID;
end;
function TRemoteJob.Remote(const Command: string): string;
var Args: TStringList; E: string;
begin
  Args := TStringList.Create;
  try
    SSHArguments(FHost,Command,Args);
    Result := RunCaptured(SSHExecutable,Args,30000,Self,E);
  finally Args.Free; end;
end;
procedure TRemoteJob.Execute;
var IDs: TStringList; I,N: Integer; U: string;
begin
  try
    if FAction <> vaList then begin
      Notice := Trim(Remote(BuildCommand(FAction,FUUID)));
      Exit;
    end;
    IDs := TStringList.Create;
    try
      IDs.Text := Remote(BuildCommand(vaList,''));
      for I := 0 to IDs.Count-1 do begin
        if Terminated then raise Exception.Create('Atualização cancelada.');
        U := Trim(IDs[I]); if U = '' then Continue;
        if not ValidUUID(U) then raise Exception.Create('Servidor retornou UUID inválido.');
        N := Length(VMs); SetLength(VMs,N+1); VMs[N].UUID := U;
        VMs[N].Name := Trim(Remote('LC_ALL=C virsh --connect qemu:///system domname '+U));
        VMs[N].State := Trim(Remote('LC_ALL=C virsh --connect qemu:///system domstate '+U));
      end;
    finally IDs.Free; end;
  except on E: Exception do ErrorText := E.Message; end;
end;
procedure LoadHosts(const FileName: string; out Hosts: THosts);
var F: TIniFile; I,N: Integer; S: string;
begin
  Hosts := nil; if not FileExists(FileName) then Exit;
  F := TIniFile.Create(FileName);
  try
    N := F.ReadInteger('general','count',0);
    if (N<0) or (N>1000) then raise Exception.Create('Cadastro de hosts inválido.');
    SetLength(Hosts,N);
    for I := 0 to N-1 do begin
      S := 'host'+IntToStr(I);
      Hosts[I].Title := F.ReadString(S,'name','');
      Hosts[I].Address := F.ReadString(S,'address','');
      Hosts[I].UserName := F.ReadString(S,'user','');
      Hosts[I].Port := F.ReadInteger(S,'port',22);
      Hosts[I].KeyFile := F.ReadString(S,'key','');
      Hosts[I].Viewer := F.ReadString(S,'viewer','');
      Hosts[I].ManagedKey := F.ReadBool(S,'managed_key',False);
    end;
  finally F.Free; end;
end;
procedure SaveHosts(const FileName: string; const Hosts: THosts);
var F: TMemIniFile; I: Integer; S,Temp: string; G: TGUID;
begin
  ForceDirectories(ExtractFileDir(FileName));
  CreateGUID(G); Temp:=FileName+'.'+Copy(GUIDToString(G),2,36)+'.tmp';
  F := TMemIniFile.Create(Temp);
  try
    F.Clear; F.WriteInteger('general','count',Length(Hosts));
    for I := 0 to High(Hosts) do begin
      S := 'host'+IntToStr(I);
      F.WriteString(S,'name',Hosts[I].Title); F.WriteString(S,'address',Hosts[I].Address);
      F.WriteString(S,'user',Hosts[I].UserName); F.WriteInteger(S,'port',Hosts[I].Port);
      F.WriteString(S,'key',Hosts[I].KeyFile); F.WriteString(S,'viewer',Hosts[I].Viewer);
      F.WriteBool(S,'managed_key',Hosts[I].ManagedKey);
    end;
    F.UpdateFile;
    if not MoveFileExW(PWideChar(UTF8Decode(Temp)),PWideChar(UTF8Decode(FileName)),
      MOVEFILE_REPLACE_EXISTING or $00000008 { MOVEFILE_WRITE_THROUGH }) then RaiseLastOSError;
  finally F.Free; DeleteFile(Temp); end;
end;
end.
