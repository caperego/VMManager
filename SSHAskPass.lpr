program SSHAskPass;
{$mode objfpc}{$H+}{$codepage utf8}
uses Interfaces, Windows, Classes, Forms, Controls, StdCtrls, ExtCtrls, SysUtils, AskPassForm;
var D: TPasswordWindow; Secret: string; Written: DWORD; Accepted: Boolean;
begin
  { Refuse generic host-key/confirmation prompts. Only a password authentication prompt is permitted. }
  if (GetEnvironmentVariable('VMMANAGER_AUTH_TARGET')='') or
    (Pos('password:',LowerCase(ParamStr(1)))=0) then Halt(1);
  RequireDerivedFormResource:=False; Application.Initialize;
  D:=TPasswordWindow.Create(nil); Accepted:=False;
  try
    if D.ShowModal=mrOK then begin
      Secret:=D.Password.Text; D.Password.Clear;
      if (Secret<>'') and (Pos(#10,Secret)=0) and (Pos(#13,Secret)=0) then begin
        Secret:=Secret+#10; UniqueString(Secret);
        Accepted:=WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),Secret[1],Length(Secret),Written,nil)
          and (Written=DWORD(Length(Secret)));
        FillChar(Secret[1],Length(Secret),0); Secret:='';
      end;
    end;
  finally D.Password.Clear; D.Free; end;
  if not Accepted then Halt(1);
end.
