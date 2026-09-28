program AccessLiveTest;
{$mode objfpc}{$H+}
uses Classes, SysUtils, VMCore, AccessCore;
var Hosts,TestHosts: THosts; Job: TAccessJob; Temp,Pin,FirstKey,SecondKey: string;
procedure Operation(Op: TAccessOperation);
begin
  LoadHosts(Temp,TestHosts);
  Job:=TAccessJob.Create(TestHosts[0],Op,Temp,0,Pin);
  try
    Job.Start; Job.WaitFor;
    if Job.ErrorText<>'' then raise Exception.Create(Job.ErrorText);
    if Op=aoInspect then begin
      if not Job.Known then raise Exception.Create('Live test requires previously trusted server.');
      Pin:=Job.HostLine;
    end;
    WriteLn('PASS: ',Ord(Op),' ',Job.Notice);
  finally Job.Free; end;
end;
begin
  if (ParamCount<>1) or (ParamStr(1)<>'--authorized-live-test') then begin
    WriteLn('Explicit opt-in required. Uses first host and an isolated profile; original key is preserved.'); Halt(1);
  end;
  LoadHosts(IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA'))+'VMManager\hosts.ini',Hosts);
  if Length(Hosts)=0 then Halt(1);
  SetLength(TestHosts,1); TestHosts[0]:=Hosts[0]; TestHosts[0].ManagedKey:=False;
  Temp:=GetTempFileName(GetTempDir(False),'vml'); SaveHosts(Temp,TestHosts);
  try
    Operation(aoInspect); Operation(aoCreate);
    LoadHosts(Temp,TestHosts); FirstKey:=TestHosts[0].KeyFile;
    if not FileExists(FirstKey) then raise Exception.Create('New key not persisted');
    Operation(aoCreate);
    LoadHosts(Temp,TestHosts); SecondKey:=TestHosts[0].KeyFile;
    if (FirstKey=SecondKey) or FileExists(FirstKey) then raise Exception.Create('Rotation did not replace old managed key');
    Operation(aoRevoke);
    LoadHosts(Temp,TestHosts);
    if (TestHosts[0].KeyFile<>'') or FileExists(SecondKey) then raise Exception.Create('Revocation did not clear profile/key');
    WriteLn('PASS: live creation, rotation, revocation; original profile/key preserved.');
  except on E: Exception do begin
    WriteLn('FAIL: ',E.Message); WriteLn('Recovery profile preserved at: ',Temp); Halt(1);
  end; end;
  DeleteFile(Temp);
end.
