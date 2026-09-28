program ConsoleBridge;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils, Windows, VMCore, ConsoleTunnel;
var Hosts: THosts; Index: Integer;
begin
  try
    if ParamCount<3 then raise Exception.Create('Uso: ConsoleBridge cadastro.ini índice UUID');
    LoadHosts(ParamStr(1),Hosts); Index:=StrToInt(ParamStr(2));
    if (Index<0) or (Index>High(Hosts)) then raise Exception.Create('Host inválido.');
    RunConsole(Hosts[Index],ParamStr(3),ParamStr(4)='--probe');
  except on E: Exception do begin
    if ParamStr(4)='--probe' then WriteLn(E.Message)
    else MessageBoxW(0,PWideChar(UTF8Decode(E.Message)),'VM Manager - Console',MB_OK or MB_ICONERROR);
    Halt(1);
  end; end;
end.
