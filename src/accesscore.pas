unit AccessCore;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Windows, Classes, SysUtils, StrUtils, VMCore;
type
  TAccessOperation = (aoInspect, aoCreate, aoRevoke);
  TAccessJob = class(TThread)
  private
    FOperation: TAccessOperation;
    FConfig: string;
    FIndex: Integer;
    function RunTool(const Exe: string; const Values: array of string): string;
    function Remote(const H: THost; const Command: string; AllowPassword: Boolean): string;
    procedure SaveCurrent;
  protected
    procedure Execute; override;
  public
    Host: THost;
    HostLine, Fingerprint, ErrorText, Notice: string;
    Known, Changed: Boolean;
    constructor Create(const H: THost; Op: TAccessOperation;
      const Config: string; Index: Integer; const ConfirmedHostLine: string);
  end;
function PublicIdentity(const Line: string): string;
function AuthorizationCommand(const Identity: string; Remove: Boolean): string;
function ManagedPath(const Path: string): Boolean;
function CreateManagedKey: string;
procedure DeleteManagedKey(const Path: string);
implementation
function ConvertSidToStringSidW(Sid: PSID; var Text: PWideChar): BOOL; stdcall; external 'advapi32.dll';
function CurrentSID: string;
var Token: THandle; Size: DWORD; Info: Pointer; Text: PWideChar;
begin
  if not OpenProcessToken(GetCurrentProcess,TOKEN_QUERY,Token) then RaiseLastOSError;
  try
    Size:=0; GetTokenInformation(Token,TokenUser,nil,0,Size); GetMem(Info,Size);
    try
      if not GetTokenInformation(Token,TokenUser,Info,Size,Size) then RaiseLastOSError;
      Text:=nil;
      if not ConvertSidToStringSidW(PSID(PPointer(Info)^),Text) then RaiseLastOSError;
      try Result:=UTF8Encode(WideString(Text)); finally LocalFree(HLOCAL(Text)); end;
    finally FreeMem(Info); end;
  finally CloseHandle(Token); end;
end;
function KeysRoot: string;
begin Result:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA'))+'VMManager\keys\'; end;
function ManagedPath(const Path: string): Boolean;
var Relative,Dir: string;
begin
  Dir:=ExtractFileDir(ExpandFileName(Path));
  Relative:=ExtractFileName(Dir);
  Result:=(CompareText(ExtractFileName(Path),'id_ed25519')=0) and ValidUUID(Relative)
    and (CompareText(IncludeTrailingPathDelimiter(ExtractFileDir(Dir)),KeysRoot)=0);
end;
function PublicIdentity(const Line: string): string;
var Kind,Blob: string; I: Integer;
begin
  Kind:=ExtractWord(1,Line,[' ',#9]); Blob:=ExtractWord(2,Line,[' ',#9]);
  if not ((Kind='ssh-ed25519') or (Kind='ssh-rsa') or (Kind='ecdsa-sha2-nistp256') or
    (Kind='ecdsa-sha2-nistp384') or (Kind='ecdsa-sha2-nistp521')) then raise Exception.Create('Tipo de chave não suportado.');
  if (Length(Blob)<16) or (Length(Blob)>8192) then raise Exception.Create('Chave pública inválida.');
  for I:=1 to Length(Blob) do
    if not (Blob[I] in ['a'..'z','A'..'Z','0'..'9','+','/','=']) then raise Exception.Create('Chave pública inválida.');
  if (Pos(#10,Line)>0) or (Pos(#13,Line)>0) then raise Exception.Create('Chave pública deve ter uma única linha.');
  Result:=Kind+' '+Blob;
end;
function AuthorizationCommand(const Identity: string; Remove: Boolean): string;
var K,B: string;
begin
  PublicIdentity(Identity); K:=ExtractWord(1,Identity,[' ']); B:=ExtractWord(2,Identity,[' ']);
  { All interpolated values are validated algorithm/base64. The rest is constant POSIX shell. }
  Result:='set -eu; umask 077; d="$HOME/.ssh"; f="$d/authorized_keys"; '+
    'test ! -L "$d" && test ! -L "$f" || { echo "Symlink recusado" >&2; exit 1; }; '+
    'mkdir -p "$d"; chmod 700 "$d"; touch "$f"; chmod 600 "$f"; '+
    'lock="$d/.vmmanager-lock"; mkdir "$lock" 2>/dev/null || { echo "Outra configuracao em andamento" >&2; exit 1; }; '+
    'tmp=""; trap ''test -z "$tmp" || rm -f "$tmp"; rmdir "$lock"'' EXIT HUP INT TERM; ';
  if Remove then
    Result:=Result+'tmp=$(mktemp "$d/.vmmanager.XXXXXX"); '+
      'awk -v k='''+K+''' -v b='''+B+''' ''{ found=0; if ($1 !~ /^#/) for(i=1;i<NF;i++) if($i==k && $(i+1)==b) found=1; if(!found) print }'' "$f" > "$tmp"; '+
      'chmod 600 "$tmp"; mv "$tmp" "$f"; tmp=""; '
  else
    Result:=Result+'if ! awk -v k='''+K+''' -v b='''+B+''' ''BEGIN {found=0} {if ($1 !~ /^#/) for(i=1;i<NF;i++) if($i==k && $(i+1)==b) found=1} END {exit !found}'' "$f"; then '+
      'printf ''\n%s\n'' '''+K+' '+B+' vmmanager'' >> "$f"; fi; ';
  Result:=Result+'printf ''VMMANAGER_OK\n''';
end;
function Tool(const Exe: string; const Values: array of string): string;
var Args: TStringList; S,E: string;
begin
  Args:=TStringList.Create;
  try for S in Values do Args.Add(S); Result:=RunCaptured(Exe,Args,30000,nil,E);
  finally Args.Free; end;
end;
function CreateManagedKey: string;
var G: TGUID; Dir: string;
begin
  CreateGUID(G); Dir:=KeysRoot+LowerCase(Copy(GUIDToString(G),2,36));
  if DirectoryExists(Dir) then raise Exception.Create('Diretório de chave já existe.');
  if not ForceDirectories(Dir) then raise Exception.Create('Não foi possível criar pasta de chaves.');
  try
    { Protect the directory BEFORE generating any private material. Children inherit only this user. }
    Tool(GetEnvironmentVariable('WINDIR')+'\System32\icacls.exe',
      [Dir,'/inheritance:r','/grant:r','*'+CurrentSID+':(OI)(CI)F']);
    Result:=Dir+'\id_ed25519';
    Tool(ExtractFilePath(SSHExecutable)+'ssh-keygen.exe',['-t','ed25519','-f',Result,'-N','','-C','vmmanager']);
  except
    DeleteFile(Dir+'\id_ed25519'); DeleteFile(Dir+'\id_ed25519.pub');
    RemoveDir(Dir); raise;
  end;
end;
procedure DeleteManagedKey(const Path: string);
begin
  if not ManagedPath(Path) then raise Exception.Create('Chave externa preservada: exclusão permitida apenas para chaves criadas pelo assistente.');
  if FileExists(Path) and not DeleteFile(Path) then raise Exception.Create('Não foi possível excluir a chave privada local.');
  if FileExists(Path+'.pub') and not DeleteFile(Path+'.pub') then raise Exception.Create('Não foi possível excluir a chave pública local.');
  RemoveDir(ExtractFileDir(Path));
end;
constructor TAccessJob.Create(const H: THost; Op: TAccessOperation;
  const Config: string; Index: Integer; const ConfirmedHostLine: string);
begin
  inherited Create(True); FreeOnTerminate:=False; Host:=H; FOperation:=Op;
  FConfig:=Config; FIndex:=Index; HostLine:=ConfirmedHostLine;
end;
function TAccessJob.RunTool(const Exe: string; const Values: array of string): string;
begin Result:=Tool(Exe,Values); end;
function TAccessJob.Remote(const H: THost; const Command: string; AllowPassword: Boolean): string;
var Args,Env,Pin: TStringList; E,Temp,Kind: string; I: Integer;
  procedure ReplaceOption(const Name,Value: string);
  var J: Integer;
  begin
    for J:=0 to Args.Count-1 do if Pos(Name+'=',Args[J])=1 then begin Args[J]:=Name+'='+Value; Exit; end;
    Args.Insert(0,'-o'); Args.Insert(1,Name+'='+Value);
  end;
begin
  Args:=TStringList.Create; Env:=TStringList.Create; Pin:=TStringList.Create;
  Temp:=GetTempFileName(GetTempDir(False),'vmp');
  try
    if Trim(HostLine)='' then raise Exception.Create('Identidade do servidor não foi confirmada.');
    Pin.Add(HostLine); Pin.SaveToFile(Temp);
    SSHArguments(H,Command,Args);
    ReplaceOption('UserKnownHostsFile','"'+StringReplace(Temp,'\','/',[rfReplaceAll])+'"');
    ReplaceOption('GlobalKnownHostsFile','NUL');
    Kind:=ExtractWord(2,HostLine,[' ',#9]);
    if Kind='ssh-rsa' then Kind:='rsa-sha2-512,rsa-sha2-256';
    ReplaceOption('HostKeyAlgorithms',Kind);
    ReplaceOption('UpdateHostKeys','no');
    if AllowPassword then begin
      if not FileExists(ExtractFilePath(ParamStr(0))+'SSHAskPass.exe') then raise Exception.Create('SSHAskPass.exe não encontrado. Reinstale o pacote completo.');
      ReplaceOption('BatchMode','no'); ReplaceOption('PasswordAuthentication','yes');
      ReplaceOption('PreferredAuthentications','publickey,password'); ReplaceOption('NumberOfPasswordPrompts','1');
      for I:=1 to GetEnvironmentVariableCount do Env.Add(GetEnvironmentString(I));
      Env.Values['SSH_ASKPASS']:=ExtractFilePath(ParamStr(0))+'SSHAskPass.exe';
      Env.Values['SSH_ASKPASS_REQUIRE']:='force'; Env.Values['DISPLAY']:='vmmanager';
      Env.Values['VMMANAGER_AUTH_TARGET']:=H.UserName+'@'+H.Address+':'+IntToStr(H.Port);
      Result:=RunCapturedEnv(SSHExecutable,Args,Env,180000,Self,E);
    end else Result:=RunCaptured(SSHExecutable,Args,30000,Self,E);
  finally DeleteFile(Temp); Pin.Free; Env.Free; Args.Free; end;
end;
procedure TAccessJob.SaveCurrent;
var All: THosts;
begin
  LoadHosts(FConfig,All);
  if (FIndex<0) or (FIndex>High(All)) or (All[FIndex].Address<>Host.Address) or
    (All[FIndex].UserName<>Host.UserName) or (All[FIndex].Port<>Host.Port) then
    raise Exception.Create(string('Cadastro mudou durante a operação. Chave preservada em ')+Host.KeyFile);
  All[FIndex]:=Host; SaveHosts(FConfig,All);
end;
procedure TAccessJob.Execute;
var Args,Lines,OldLines,Words,Pub: TStringList; Scan,Old,Temp,OldPath,NewPath,OldIdentity,Identity,Target,S: string;
  I,J: Integer; Previous: THost; Installed: Boolean; F: TextFile;
begin
  NewPath:=''; Installed:=False;
  try
    Previous:=Host; Previous.KeyFile:=''; Previous.Viewer:=''; ValidateHost(Previous);
    if FOperation=aoInspect then begin
      Args:=TStringList.Create; Lines:=TStringList.Create; OldLines:=TStringList.Create; Words:=TStringList.Create;
      Temp:=GetTempFileName(GetTempDir(False),'vmf');
      try
        Scan:=RunTool(ExtractFilePath(SSHExecutable)+'ssh-keyscan.exe',['-T','5','-p',IntToStr(Host.Port),'-t','ed25519,ecdsa,rsa',Host.Address]);
        Lines.Text:=Scan; Target:=Host.Address;
        if Host.Port<>22 then Target:='['+Host.Address+']:'+IntToStr(Host.Port);
        try Old:=RunTool(ExtractFilePath(SSHExecutable)+'ssh-keygen.exe',['-F',Target]); except Old:=''; end;
        OldLines.Text:=Old; HostLine:=''; Known:=False;
        for I:=0 to Lines.Count-1 do begin
          S:=Trim(Lines[I]); if (S='') or (S[1]='#') then Continue;
          Identity:=PublicIdentity(ExtractWord(2,S,[' ',#9])+' '+ExtractWord(3,S,[' ',#9]));
          if HostLine='' then HostLine:=Target+' '+Identity;
          for J:=0 to OldLines.Count-1 do begin
            Old:=Trim(OldLines[J]); if (Old='') or (Old[1]='#') then Continue;
            if (ExtractWord(2,Old,[' ',#9])+' '+ExtractWord(3,Old,[' ',#9]))=Identity then begin
              Known:=True; HostLine:=Target+' '+Identity; Break;
            end;
          end;
          if Known then Break;
        end;
        if HostLine='' then raise Exception.Create('Servidor não retornou uma chave SSH compatível.');
        Changed:=(not Known) and (Trim(OldLines.Text)<>'');
        if Changed then raise Exception.Create('A identidade do servidor difere do known_hosts. Operação bloqueada. Confira a mudança com o administrador; nenhuma senha foi enviada.');
        Words.Add(HostLine); Words.SaveToFile(Temp);
        Fingerprint:=Trim(RunTool(ExtractFilePath(SSHExecutable)+'ssh-keygen.exe',['-l','-f',Temp,'-E','sha256']));
      finally DeleteFile(Temp); Words.Free; OldLines.Free; Lines.Free; Args.Free; end;
      Exit;
    end;
    Pub:=TStringList.Create;
    try
      Previous:=Host;
      OldPath:=Host.KeyFile;
      if (Previous.KeyFile<>'') and not FileExists(Previous.KeyFile) then Previous.KeyFile:='';
      if FOperation=aoRevoke then begin
        if not Host.ManagedKey or not ManagedPath(Host.KeyFile) then raise Exception.Create('Chave externa não pode ser excluída por este assistente.');
        Pub.LoadFromFile(Host.KeyFile+'.pub'); Identity:=PublicIdentity(Trim(Pub.Text));
        Remote(Previous,AuthorizationCommand(Identity,True),True);
        Host.KeyFile:=''; Host.ManagedKey:=False; SaveCurrent;
        DeleteManagedKey(OldPath);
        Notice:='Autorização removida do servidor e chave local excluída. Para configurar novamente, será necessário acesso por senha.';
        Exit;
      end;
      OldIdentity:='';
      if Previous.ManagedKey then begin
        if not ManagedPath(OldPath) then raise Exception.Create('Caminho de chave gerenciada inválido.');
        Pub.LoadFromFile(OldPath+'.pub'); OldIdentity:=PublicIdentity(Trim(Pub.Text));
      end;
      NewPath:=CreateManagedKey;
      Pub.LoadFromFile(NewPath+'.pub'); Identity:=PublicIdentity(Trim(Pub.Text));
      { Keep a possibly installed key on failures/timeouts: remote writes may already have happened. }
      Installed:=True;
      Remote(Previous,AuthorizationCommand(Identity,False),True);
      Host.KeyFile:=NewPath; Host.ManagedKey:=True;
      Remote(Host,'LC_ALL=C virsh --connect qemu:///system list --all --uuid',False);
      { Persist the tested key before revoking the old key. }
      SaveCurrent;
      Target:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('USERPROFILE'))+'.ssh';
      ForceDirectories(Target); Target:=Target+'\known_hosts';
      Pub.Clear; if FileExists(Target) then Pub.LoadFromFile(Target);
      if Pub.IndexOf(HostLine)<0 then begin
        AssignFile(F,Target); if FileExists(Target) then Append(F) else Rewrite(F);
        try WriteLn(F); WriteLn(F,HostLine); finally CloseFile(F); end;
      end;
      if OldIdentity<>'' then begin
        Remote(Host,AuthorizationCommand(OldIdentity,True),False);
        DeleteManagedKey(OldPath);
      end;
      Notice:='Nova chave autorizada, acesso ao libvirt testado e cadastro atualizado.';
      if (Previous.KeyFile<>'') and not Previous.ManagedKey then
        Notice:=Notice+' A chave externa anterior foi preservada.';
    finally Pub.Free; end;
  except on Ex: Exception do begin
    ErrorText:=Ex.Message;
    if NewPath<>'' then begin
      if not Installed then DeleteManagedKey(NewPath)
      else ErrorText:=ErrorText+LineEnding+string('Chave preservada para recuperação: ')+NewPath;
    end;
  end; end;
end;
end.
