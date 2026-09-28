unit VMConfigJob;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, VMCore, VMConfigCore;
type
  TConfigurationJob = class(TThread)
  private
    FHost: THost;
    FUUID, FOriginalXML: string;
    FOriginalAutoStart, FDesiredAutoStart: Boolean;
    FSetCPU, FSetMemory: Boolean;
    FSave: Boolean;
    FCPU: Integer;
    FMemoryMiB: QWord;
    function Remote(const Command: string): string;
  protected
    procedure Execute; override;
  public
    Configuration: TVMConfiguration;
    RawXML, ErrorText: string;
    constructor CreateRead(const Host: THost; const UUID: string);
    constructor CreateSave(const Host: THost; const UUID, OriginalXML: string;
      CPU: Integer; MemoryMiB: QWord; SetCPU, SetMemory,
      OriginalAutoStart, DesiredAutoStart: Boolean);
  end;
implementation

constructor TConfigurationJob.CreateRead(const Host: THost; const UUID: string);
begin
  inherited Create(True);
  FreeOnTerminate:=False;
  FHost:=Host; FUUID:=UUID; FSave:=False;
end;

constructor TConfigurationJob.CreateSave(const Host: THost; const UUID, OriginalXML: string;
  CPU: Integer; MemoryMiB: QWord; SetCPU, SetMemory,
  OriginalAutoStart, DesiredAutoStart: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate:=False;
  FHost:=Host; FUUID:=UUID; FOriginalXML:=OriginalXML;
  FSave:=True; FCPU:=CPU; FMemoryMiB:=MemoryMiB;
  FSetCPU:=SetCPU; FSetMemory:=SetMemory;
  FOriginalAutoStart:=OriginalAutoStart; FDesiredAutoStart:=DesiredAutoStart;
end;

function TConfigurationJob.Remote(const Command: string): string;
var Args: TStringList; Err: string;
begin
  Args:=TStringList.Create;
  try
    SSHArguments(FHost,Command,Args);
    Result:=RunCaptured(SSHExecutable,Args,30000,Self,Err);
  finally Args.Free; end;
end;

procedure TConfigurationJob.Execute;
var State,CurrentXML,Info: string; Before: TVMConfiguration; Touched: Boolean;
  KiB: QWord; CurrentAutoStart, ResourcesChanged: Boolean;
begin
  Touched:=False;
  try
    if not ValidUUID(FUUID) then raise Exception.Create('UUID inválido.');
    State:=Trim(Remote(BuildConfigCommand('state',FUUID)));
    CurrentXML:=Remote(BuildConfigCommand('read',FUUID));
    Before:=ParseVMConfiguration(CurrentXML,State,FUUID);
    Info:=Remote(BuildConfigCommand('info',FUUID));
    Before.AutoStart:=ParseAutoStartInfo(Info);
    if FSave then begin
      if FOriginalXML='' then raise Exception.Create('Recarregue a configuração antes de salvar.');
      if CurrentXML<>FOriginalXML then
        raise Exception.Create('A definição da VM mudou no servidor. Recarregue antes de salvar.');
      if Before.AutoStart<>FOriginalAutoStart then
        raise Exception.Create('A opção de início automático mudou no servidor. Recarregue antes de salvar.');
      ResourcesChanged:=FSetCPU or FSetMemory;
      if FSetCPU then ValidateCPUCount(FCPU);
      if FSetMemory then ValidateMemoryMiB(FMemoryMiB);
      if ResourcesChanged and (State<>'shut off') then
        raise Exception.Create('Desligue a VM antes de alterar CPU ou RAM.');
      KiB:=FMemoryMiB*1024;
      if ResourcesChanged then begin
        if FSetCPU and (FCPU>Before.CPUMax) then begin
          Touched:=True; Remote(BuildConfigCommand('cpu_max',FUUID,FCPU));
        end;
        if FSetCPU and (FCPU<>Before.CPUCount) then begin
          Touched:=True; Remote(BuildConfigCommand('cpu',FUUID,FCPU));
        end;
        if FSetMemory and (KiB>Before.MaxMemoryKiB) then begin
          Touched:=True; Remote(BuildConfigCommand('memory_max',FUUID,KiB));
        end;
        if FSetMemory and (KiB<>Before.MemoryKiB) then begin
          Touched:=True; Remote(BuildConfigCommand('memory',FUUID,KiB));
        end;
      end;
      if FDesiredAutoStart<>Before.AutoStart then begin
        if FDesiredAutoStart then Info:=BuildConfigCommand('autostart_on',FUUID)
        else Info:=BuildConfigCommand('autostart_off',FUUID);
        Touched:=True; Remote(Info);
      end;
      State:=Trim(Remote(BuildConfigCommand('state',FUUID)));
      CurrentXML:=Remote(BuildConfigCommand('read',FUUID));
      Before:=ParseVMConfiguration(CurrentXML,State,FUUID);
      Info:=Remote(BuildConfigCommand('info',FUUID));
      CurrentAutoStart:=ParseAutoStartInfo(Info);
      Before.AutoStart:=CurrentAutoStart;
      if ((FSetCPU and (Before.CPUCount<>FCPU)) or
          (FSetMemory and (Before.MemoryKiB<>KiB))) or
         (CurrentAutoStart<>FDesiredAutoStart) then
        raise Exception.Create('O servidor não confirmou todos os valores solicitados. Recarregue a configuração.');
    end;
    Configuration:=Before; RawXML:=CurrentXML;
  except on E: Exception do begin
    ErrorText:=E.Message;
    if Touched then ErrorText:=ErrorText+' Uma alteração pode ter sido aplicada parcialmente; recarregue a configuração antes de tentar novamente.';
  end; end;
end;
end.
