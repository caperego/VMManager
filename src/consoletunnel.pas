unit ConsoleTunnel;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Process, Sockets, VMCore;
procedure ParseDisplay(const URI: string; out Protocol: string; out Port: Integer);
procedure RunConsole(const Host: THost; const UUID: string; ProbeOnly: Boolean);
implementation
procedure ParseDisplay(const URI: string; out Protocol: string; out Port: Integer);
var Rest,Number: string; I: Integer;
begin
  if Pos('vnc://',URI)=1 then begin Protocol:='vnc'; Rest:=Copy(URI,7,MaxInt); end
  else if Pos('spice://',URI)=1 then begin Protocol:='spice'; Rest:=Copy(URI,9,MaxInt); end
  else raise Exception.Create('Console sem endereço TCP VNC/SPICE compatível.');
  if Pos('127.0.0.1:',Rest)=1 then Number:=Copy(Rest,11,MaxInt)
  else if Pos('localhost:',Rest)=1 then Number:=Copy(Rest,11,MaxInt)
  else if Pos('0.0.0.0:',Rest)=1 then Number:=Copy(Rest,9,MaxInt)
  else raise Exception.Create('Console deve escutar no loopback IPv4 do servidor.');
  if Number='' then raise Exception.Create('Porta do console ausente.');
  for I:=1 to Length(Number) do
    if not (Number[I] in ['0'..'9']) then raise Exception.Create('Endereço do console inválido.');
  Port:=StrToIntDef(Number,-1);
  if (Port<0) or (Port>65535) then raise Exception.Create('Porta do console inválida.');
  if Protocol='vnc' then Inc(Port,5900);
  if (Port<1) or (Port>65535) then raise Exception.Create('Porta do console fora do intervalo.');
end;
function FreePort: Integer;
var S: TSocket; Address: TInetSockAddr; Len: TSockLen;
begin
  S:=fpSocket(AF_INET,SOCK_STREAM,0);
  if S=TSocket(-1) then raise Exception.Create('Não foi possível reservar porta local.');
  try
    FillChar(Address,SizeOf(Address),0); Address.sin_family:=AF_INET;
    Address.sin_addr:=StrToNetAddr('127.0.0.1'); Address.sin_port:=0;
    if fpBind(S,@Address,SizeOf(Address))<>0 then raise Exception.Create('Falha ao reservar porta local.');
    Len:=SizeOf(Address);
    if fpGetSockName(S,@Address,@Len)<>0 then raise Exception.Create('Falha ao consultar porta local.');
    Result:=NToHs(Address.sin_port);
  finally CloseSocket(S); end;
end;
function CheckLocalPort(Port: Integer; ReadVNC: Boolean): Boolean;
var S: TSocket; Address: TInetSockAddr; Timeout: LongInt;
  Header: array[0..11] of Char; N: Integer;
begin
  Result:=False; S:=fpSocket(AF_INET,SOCK_STREAM,0);
  if S=TSocket(-1) then Exit;
  try
    FillChar(Address,SizeOf(Address),0); Address.sin_family:=AF_INET;
    Address.sin_addr:=StrToNetAddr('127.0.0.1'); Address.sin_port:=HToNs(Port);
    if fpConnect(S,@Address,SizeOf(Address))<>0 then Exit;
    Result:=True;
    if ReadVNC then begin
      Timeout:=3000; fpSetSockOpt(S,SOL_SOCKET,SO_RCVTIMEO,@Timeout,SizeOf(Timeout));
      FillChar(Header,SizeOf(Header),0); N:=fpRecv(S,@Header,SizeOf(Header),0);
      Result:=(N>=4) and (Header[0]='R') and (Header[1]='F') and (Header[2]='B') and (Header[3]=' ');
    end;
  finally CloseSocket(S); end;
end;
procedure RunConsole(const Host: THost; const UUID: string; ProbeOnly: Boolean);
var Args: TStringList; Tunnel,Viewer: TProcess; URI,Protocol,E,RemoteViewer,ViewerPath: string;
  Port,LocalPort,I,Attempt: Integer; Started: QWord; Buffer: array[0..2047] of Char; Ready: Boolean;
  procedure DrainError;
  var N: Integer; Chunk: string;
  begin
    while Tunnel.Stderr.NumBytesAvailable>0 do begin
      N:=Tunnel.Stderr.Read(Buffer,SizeOf(Buffer)); if N<=0 then Break;
      SetString(Chunk,PChar(@Buffer[0]),N); E:=Copy(E+Chunk,1,16384);
    end;
  end;
begin
  ValidateHost(Host);
  if not ValidUUID(UUID) then raise Exception.Create('UUID inválido.');
  ViewerPath:=Host.Viewer;
  if ViewerPath='' then ViewerPath:=FindVirtViewerExecutable;
  if (ViewerPath='') or not FileExists(ViewerPath) then
    raise Exception.Create('virt-viewer não encontrado. Instale o VMManager com virt-viewer ou informe o caminho no cadastro do host.');
  RemoteViewer:=ExtractFilePath(ViewerPath)+'remote-viewer.exe';
  if not FileExists(RemoteViewer) then raise Exception.Create('remote-viewer.exe não encontrado ao lado de virt-viewer.exe.');
  Args:=TStringList.Create; Tunnel:=TProcess.Create(nil); Viewer:=TProcess.Create(nil);
  try
    SSHArguments(Host,'LC_ALL=C virsh --connect qemu:///system domdisplay '+UUID,Args);
    URI:=Trim(RunCaptured(SSHExecutable,Args,30000,nil,E));
    ParseDisplay(URI,Protocol,Port);
    { Retry local port allocation if another process takes the port before SSH. }
    for Attempt:=1 to 3 do begin
      E:=''; LocalPort:=FreePort;
      SSHArguments(Host,'',Args); Args.Delete(Args.Count-1);
      I:=Args.IndexOf('ClearAllForwardings=yes'); Args[I]:='ClearAllForwardings=no';
      Args.Insert(0,'-N'); Args.Insert(1,'-o'); Args.Insert(2,'ExitOnForwardFailure=yes');
      Args.Insert(3,'-L'); Args.Insert(4,'127.0.0.1:'+IntToStr(LocalPort)+':127.0.0.1:'+IntToStr(Port));
      Tunnel.Executable:=SSHExecutable; Tunnel.Parameters.Assign(Args);
      Tunnel.Options:=[poUsePipes,poNoConsole]; Tunnel.Execute; Tunnel.CloseInput;
      Started:=GetTickCount64; Ready:=False;
      repeat
        DrainError;
        if not Tunnel.Running then Break;
        Ready:=CheckLocalPort(LocalPort,False);
        if Ready then Break;
        Sleep(50);
      until GetTickCount64-Started>=15000;
      if Tunnel.Running and Ready then Break;
      if Tunnel.Running then raise Exception.Create('Tempo limite ao abrir túnel SSH.');
      if Pos('Address already in use',E)=0 then raise Exception.Create(string('Falha no túnel SSH: ')+E);
    end;
    if not Tunnel.Running then raise Exception.Create(string('Falha no túnel SSH: ')+E);
    if ProbeOnly then begin
      if (Protocol='vnc') and not CheckLocalPort(LocalPort,True) then raise Exception.Create('Túnel abriu, mas o servidor não respondeu com protocolo VNC.');
      WriteLn('Tunnel ready: ',Protocol,' on local port ',LocalPort,'; remote port ',Port);
      Exit;
    end;
    Viewer.Executable:=RemoteViewer;
    Viewer.Parameters.Add(Protocol+'://127.0.0.1:'+IntToStr(LocalPort));
    Viewer.Options:=[poNoConsole]; Viewer.Execute;
    while Viewer.Running do begin
      DrainError;
      if not Tunnel.Running then raise Exception.Create(string('Conexão SSH encerrada: ')+E);
      Sleep(100);
    end;
  finally
    if Viewer.Running then begin Viewer.Terminate(1); Viewer.WaitOnExit; end;
    if Tunnel.Running then begin Tunnel.Terminate(1); Tunnel.WaitOnExit; end;
    Viewer.Free; Tunnel.Free; Args.Free;
  end;
end;
end.
