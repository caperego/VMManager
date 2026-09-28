unit VMClone;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, VMCore;
type
  TCloneJob = class(TThread)
  private
    FHost: THost;
    FUUID, FNewName: string;
    function Remote(const Command: string; TimeoutMS: QWord): string;
  protected
    procedure Execute; override;
  public
    ErrorText, Notice: string;
    constructor Create(const Host: THost; const UUID, NewName: string);
  end;
function ValidCloneName(const S: string): Boolean;
function ShellQuote(const S: string): string;
function BuildCloneCommand(const OriginalName, NewName: string): string;
implementation
function ValidCloneName(const S: string): Boolean;
var I: Integer;
begin
  Result:=False;
  if (Length(S)<1) or (Length(S)>80) then Exit;
  if not (S[1] in ['a'..'z','A'..'Z','0'..'9']) then Exit;
  for I:=1 to Length(S) do
    if not (S[I] in ['a'..'z','A'..'Z','0'..'9','_','-','.']) then Exit;
  Result:=True;
end;
function ShellQuote(const S: string): string;
begin
  Result:=''''+StringReplace(S,'''','''\''''',[rfReplaceAll])+'''';
end;
function BuildCloneCommand(const OriginalName, NewName: string): string;
begin
  if (OriginalName='') or (Length(OriginalName)>255) or (Pos(#0,OriginalName)>0) then
    raise Exception.Create('Nome da VM de origem inválido.');
  if not ValidCloneName(NewName) then
    raise Exception.Create('Use de 1 a 80 caracteres no novo nome: letras, números, ponto, hífen e sublinhado; comece por letra ou número.');
  Result:='LC_ALL=C virt-clone --connect qemu:///system --original '+
    ShellQuote(OriginalName)+' --name '+ShellQuote(NewName)+' --auto-clone --quiet';
end;
constructor TCloneJob.Create(const Host: THost; const UUID, NewName: string);
begin
  inherited Create(True); FreeOnTerminate:=False;
  FHost:=Host; FUUID:=UUID; FNewName:=NewName;
end;
function TCloneJob.Remote(const Command: string; TimeoutMS: QWord): string;
var Args: TStringList; Err: string;
begin
  Args:=TStringList.Create;
  try
    SSHArguments(FHost,Command,Args);
    Result:=RunCaptured(SSHExecutable,Args,TimeoutMS,Self,Err);
  finally Args.Free; end;
end;
procedure TCloneJob.Execute;
var State, OriginalName: string;
begin
  try
    if not ValidUUID(FUUID) then raise Exception.Create('UUID inválido. Atualize a lista.');
    if not ValidCloneName(FNewName) then raise Exception.Create('Nome da nova VM inválido.');
    State:=Trim(Remote('LC_ALL=C virsh --connect qemu:///system domstate '+FUUID,30000));
    if State<>'shut off' then raise Exception.Create('Desligue completamente a VM de origem antes de clonar. Estado atual: '+State);
    OriginalName:=Trim(Remote('LC_ALL=C virsh --connect qemu:///system domname '+FUUID,30000));
    if Trim(Remote('command -v virt-clone',30000))='' then
      raise Exception.Create('virt-clone não está instalado no servidor Linux. Instale o pacote virt-install no servidor.');
    Remote(BuildCloneCommand(OriginalName,FNewName),7200000);
    Notice:='Clone '+FNewName+' criado no host '+FHost.Title+'. Atualize a lista para conferir.';
  except on E: Exception do ErrorText:=E.Message+
    ' Se a cópia foi interrompida, confira as VMs e o armazenamento no servidor antes de tentar novamente.';
  end;
end;
end.
