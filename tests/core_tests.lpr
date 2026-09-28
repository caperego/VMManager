program CoreTests;
{$mode objfpc}{$H+}{$codepage utf8}
uses Windows, ShellApi, Classes, SysUtils, VMCore, ConsoleTunnel, VMClone;
const UUID = '12345678-1234-1234-1234-123456789abc';
var H: THost; Hosts,Loaded: THosts; Args: TStringList; Count,I: Integer;
  S,E,Temp,TestRoot,Protocol: string; Port,ArgCount: Integer; Failed: Boolean; ArgVector: PLPWSTR;
  Dummy: TFileStream;
procedure Check(Condition: Boolean; const Name: string);
begin
  if not Condition then raise Exception.Create('FAIL: '+Name);
  Inc(Count); WriteLn('PASS: '+Name);
end;
procedure RejectHost(const Address,UserName: string);
var Bad: THost;
begin
  Bad:=H; Bad.Address:=Address; Bad.UserName:=UserName; Failed:=False;
  try ValidateHost(Bad); except on Exception do Failed:=True; end;
  Check(Failed,'Reject host/user: '+Address+'/'+UserName);
end;
begin
  if ParamStr(1)='--child-arguments' then begin
    ArgVector:=CommandLineToArgvW(GetCommandLineW,@ArgCount);
    if (ArgCount=5) and (WideString(ArgVector[2])='') and (WideString(ArgVector[3])='space "quoted" value\') and (WideString(ArgVector[4])='literal $() ; &') then
      WriteLn('ARGUMENTS_OK') else Halt(24);
    LocalFree(HLOCAL(ArgVector));
    Halt(0);
  end;
  if ParamStr(1)='--child-ok' then begin
    WriteLn('guest name with spaces;$(touch bad)'); WriteLn(StdErr,'diagnostic'); Halt(0);
  end;
  if ParamStr(1)='--child-fail' then begin WriteLn(StdErr,'Permission denied'); Halt(23); end;
  if ParamStr(1)='--child-sleep' then begin Sleep(5000); Halt(0); end;
  if ParamStr(1)='--child-large' then begin
    for I:=1 to 10000 do begin WriteLn(StringOfChar('o',80)); WriteLn(StdErr,StringOfChar('e',80)); end; Halt(0);
  end;
  Args:=TStringList.Create;
  try
    H:=Default(THost); H.Title:='Lab'; H.Address:='192.0.2.10'; H.UserName:='vmadmin'; H.Port:=2222;
    ValidateHost(H); Check(True,'Valid host');
    Check(ValidUUID(UUID),'Valid UUID');
    Check(not ValidUUID(UUID+'; reboot'),'UUID injection');
    Check(not ValidUUID(''), 'Empty UUID');
    Check(not ValidUUID('12345678_1234-1234-1234-123456789abc'),'UUID separators');
    RejectHost('-oProxyCommand=bad','vmadmin'); RejectHost('host;reboot','vmadmin');
    RejectHost('host name','vmadmin'); RejectHost('host','root;id'); RejectHost('host','-lroot');
    H.Port:=0; Failed:=False;
    try ValidateHost(H); except on Exception do Failed:=True; end;
    Check(Failed,'Invalid port'); H.Port:=2222;
    Check(BuildCommand(vaList,'')='LC_ALL=C virsh --connect qemu:///system list --all --uuid','System URI and UUID list');
    Check(BuildCommand(vaDestroy,UUID)='LC_ALL=C virsh --connect qemu:///system destroy '+UUID,'Destroy uses UUID');
    Failed:=False;
    try BuildCommand(vaStart,UUID+' && id'); except on Exception do Failed:=True; end;
    Check(Failed,'Command injection rejected');
    Check(ValidCloneName('Servidor-Clone_1'),'Valid clone name');
    Check(not ValidCloneName('-bad'),'Clone name cannot start with option marker');
    Check(not ValidCloneName('clone;touch_bad'),'Clone name shell injection rejected');
    Check(Pos('--original ''orig'' --name ''copy'' --auto-clone',BuildCloneCommand('orig','copy'))>0,
      'Clone command uses system libvirt and automatic disk paths');
    Check(Pos('''x''\'''';id''',BuildCloneCommand('x'';id','copy'))>0,
      'Source name is quoted for remote shell');
    SSHArguments(H,BuildCommand(vaList,''),Args);
    Check(Args.IndexOf('StrictHostKeyChecking=yes')>=0,'Strict host verification');
    Check(Args.IndexOf('BatchMode=yes')>=0,'Noninteractive authentication');
    Check((Args[0]='-F') and (Args[1]='NUL'),'Local SSH config ignored');
    Check(Args[Args.Count-1]=BuildCommand(vaList,''),'Remote command is single argument');
    Check(Args.IndexOf('2222')>=0,'Custom SSH port');
    SetLength(Hosts,1); Hosts[0]:=H;
    Temp:=GetTempDir(False)+'vmmanager-test-'+IntToStr(GetProcessID)+'.ini';
    try
      SaveHosts(Temp,Hosts); LoadHosts(Temp,Loaded);
      Check((Length(Loaded)=1) and (Loaded[0].Port=2222) and (Loaded[0].Address=H.Address),'Configuration round trip');
      SetLength(Hosts,0); SaveHosts(Temp,Hosts); LoadHosts(Temp,Loaded);
      Check(Length(Loaded)=0,'Host deletion persistence');
    finally DeleteFile(Temp); end;
    Args.Clear; Args.Add('--child-ok'); S:=RunCaptured(ParamStr(0),Args,2000,nil,E);
    Check(Pos('guest name with spaces;$(touch bad)',S)>0,'Literal process output');
    Check(Pos('diagnostic',E)>0,'Separate stderr');
    Args[0]:='--child-large'; S:=RunCaptured(ParamStr(0),Args,10000,nil,E);
    Check((Length(S)>800000) and (Length(E)>800000),'Drain both pipes without deadlock');
    Args[0]:='--child-fail'; Failed:=False;
    try RunCaptured(ParamStr(0),Args,2000,nil,E); except on Ex: Exception do Failed:=Pos('23',Ex.Message)>0; end;
    Check(Failed,'Nonzero exit reported');
    Args[0]:='--child-sleep'; Failed:=False;
    try RunCaptured(ParamStr(0),Args,100,nil,E); except on Ex: Exception do Failed:=Pos('Tempo limite',Ex.Message)>0; end;
    Check(Failed,'Timeout kills local process');
    ParseDisplay('vnc://127.0.0.1:3',Protocol,Port);
    Check((Protocol='vnc') and (Port=5903),'VNC display converted to TCP port');
    ParseDisplay('spice://localhost:5901',Protocol,Port);
    Check((Protocol='spice') and (Port=5901),'SPICE TCP port preserved');
    Failed:=False;
    try ParseDisplay('vnc://127.0.0.1:3;id',Protocol,Port); except on Exception do Failed:=True; end;
    Check(Failed,'Reject console URI injection');
    Failed:=False;
    try ParseDisplay('vnc://example.com:3',Protocol,Port); except on Exception do Failed:=True; end;
    Check(Failed,'Reject arbitrary forwarding target');
    Args.Clear; Args.Add('--child-arguments'); Args.Add(''); Args.Add('space "quoted" value\'); Args.Add('literal $() ; &');
    S:=RunCaptured(ParamStr(0),Args,2000,nil,E);
    Check(Pos('ARGUMENTS_OK',S)>0,'Windows arguments preserve empty, quotes, trailing backslash and metacharacters');
    TestRoot:=GetTempDir(False)+'vmmanager-viewer-test-'+IntToStr(GetProcessID);
    ForceDirectories(TestRoot+PathDelim+'VirtViewer v11.0-256'+PathDelim+'bin');
    Dummy:=TFileStream.Create(TestRoot+PathDelim+'VirtViewer v11.0-256'+PathDelim+'bin'+PathDelim+'virt-viewer.exe',fmCreate);
    Dummy.Free;
    Dummy:=TFileStream.Create(TestRoot+PathDelim+'VirtViewer v11.0-256'+PathDelim+'bin'+PathDelim+'remote-viewer.exe',fmCreate);
    Dummy.Free;
    Check(FindVirtViewerExecutable(TestRoot)=TestRoot+PathDelim+'VirtViewer v11.0-256'+PathDelim+'bin'+PathDelim+'virt-viewer.exe','Auto-detect virt-viewer MSI installation');
    DeleteFile(TestRoot+PathDelim+'VirtViewer v11.0-256'+PathDelim+'bin'+PathDelim+'virt-viewer.exe');
    DeleteFile(TestRoot+PathDelim+'VirtViewer v11.0-256'+PathDelim+'bin'+PathDelim+'remote-viewer.exe');
    RemoveDir(TestRoot+PathDelim+'VirtViewer v11.0-256'+PathDelim+'bin');
    RemoveDir(TestRoot+PathDelim+'VirtViewer v11.0-256');
    RemoveDir(TestRoot);
    WriteLn('OK: ',Count,' tests passed.');
  finally Args.Free; end;
end.
