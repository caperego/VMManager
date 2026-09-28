program AccessTests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Classes, SysUtils, StrUtils, VMCore, AccessCore;
var Count,I: Integer; Args,Env,Data: TStringList; Root,Key,Command,Output,Err,Identity: string;
  Failed: Boolean; H: THost; Job: TAccessJob;
procedure Check(OK: Boolean; const Name: string);
begin
  if not OK then raise Exception.Create('FAIL: '+Name);
  Inc(Count); WriteLn('PASS: '+Name);
end;
procedure RunAuthorization(Remove: Boolean);
begin
  Command:=AuthorizationCommand(Identity,Remove);
  Command:=StringReplace(Command,'$HOME/.ssh','$VMM_TEST_ROOT/.ssh',[]);
  Args.Clear; Args.Add('--noprofile'); Args.Add('--norc'); Args.Add('-c'); Args.Add(Command);
  Output:=RunCapturedEnv('C:\Program Files\Git\bin\bash.exe',Args,Env,10000,nil,Err);
  Check(Pos('VMMANAGER_OK',Output)>0,'Authorization script completed');
end;
begin
  Count:=0; Args:=TStringList.Create; Env:=TStringList.Create; Data:=TStringList.Create;
  Root:=ExpandFileName(ExtractFilePath(ParamStr(0))+'..\..\..\work\access-tests-'+IntToStr(GetProcessID));
  Key:='';
  try
    Identity:='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestBase64Fixture1234567890';
    Check(PublicIdentity(Identity+' comment')=Identity,'Public-key comment excluded');
    Failed:=False;
    try PublicIdentity('ssh-ed25519 AAAAC3NzaC1lZDI1NTE5;id'); except on Exception do Failed:=True; end;
    Check(Failed,'Reject public-key injection');
    Failed:=False;
    try PublicIdentity(Identity+#10+'another'); except on Exception do Failed:=True; end;
    Check(Failed,'Reject multiline public key');
    Check(not ManagedPath(GetEnvironmentVariable('USERPROFILE')+'\.ssh\external-key'),'External key cannot be deleted');
    Check(not ManagedPath(GetEnvironmentVariable('LOCALAPPDATA')+'\VMManager\keys\..\id_ed25519'),'Path traversal rejected');
    Failed:=False;
    try DeleteManagedKey(GetEnvironmentVariable('USERPROFILE')+'\.ssh\external-key'); except on Exception do Failed:=True; end;
    Check(Failed,'Deletion guard blocks external key');
    ForceDirectories(Root+'\.ssh');
    for I:=1 to GetEnvironmentVariableCount do Env.Add(GetEnvironmentString(I));
    Env.Values['VMM_TEST_ROOT']:=StringReplace(Root,'\','/',[rfReplaceAll]);
    Data.Add('# existing comment'); Data.Add('ssh-ed25519 AAAAOtherKeyPreserved');
    Data.SaveToFile(Root+'\.ssh\authorized_keys');
    RunAuthorization(False); RunAuthorization(False);
    Data.LoadFromFile(Root+'\.ssh\authorized_keys');
    Check(Data.Count>=3,'Authorized keys readable');
    I:=0; for Output in Data do if Pos(Identity,Output)>0 then Inc(I);
    Check(I=1,'Install is idempotent');
    Data.Add('no-port-forwarding '+Identity+' old-restricted-copy');
    Data.SaveToFile(Root+'\.ssh\authorized_keys');
    RunAuthorization(True);
    Data.LoadFromFile(Root+'\.ssh\authorized_keys');
    Check(Pos(Identity,Data.Text)=0,'Revoke exact identity including restricted copies');
    Check(Pos('AAAAOtherKeyPreserved',Data.Text)>0,'Other authorized keys preserved');
    Check(Pos('# existing comment',Data.Text)>0,'Comments preserved');
    Key:=CreateManagedKey;
    Check(ManagedPath(Key) and FileExists(Key) and FileExists(Key+'.pub'),'Generated Ed25519 managed key');
    Data.LoadFromFile(Key+'.pub'); Check(Pos('ssh-ed25519 ',PublicIdentity(Trim(Data.Text)))=1,'Generated public key valid');
    Args.Clear; Args.Add('-y'); Args.Add('-P'); Args.Add(''); Args.Add('-f'); Args.Add(Key);
    Output:=RunCaptured(ExtractFilePath(SSHExecutable)+'ssh-keygen.exe',Args,10000,nil,Err);
    Check(PublicIdentity(Trim(Output))=PublicIdentity(Trim(Data.Text)),'Private key readable without passphrase');
    DeleteManagedKey(Key);
    Check(not FileExists(Key) and not FileExists(Key+'.pub'),'Managed pair deleted'); Key:='';
    if ParamStr(1)='--live-inspect' then begin
      H:=Default(THost); H.Title:='Read-only test';
      H.Address:=GetEnvironmentVariable('VM_MANAGER_TEST_HOST');
      H.UserName:=GetEnvironmentVariable('VM_MANAGER_TEST_USER');
      H.Port:=StrToIntDef(GetEnvironmentVariable('VM_MANAGER_TEST_PORT'),22);
      if (H.Address='') or (H.UserName='') then
        raise Exception.Create('Defina VM_MANAGER_TEST_HOST e VM_MANAGER_TEST_USER para o teste remoto.');
      Job:=TAccessJob.Create(H,aoInspect,'',0,'');
      try
        Job.Start; Job.WaitFor;
        Check(Job.ErrorText='','Live host inspection: '+Job.ErrorText);
        Check(Job.Known and not Job.Changed,'Existing server identity recognized');
        Check(Pos('SHA256:',Job.Fingerprint)>0,'SHA256 host fingerprint returned');
      finally Job.Free; end;
    end;
    WriteLn('OK: ',Count,' access tests passed.');
  finally
    if Key<>'' then DeleteManagedKey(Key);
    DeleteFile(Root+'\.ssh\authorized_keys'); RemoveDir(Root+'\.ssh'); RemoveDir(Root);
    Data.Free; Env.Free; Args.Free;
  end;
end.
