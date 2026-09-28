program PasswordUITests;
{$mode objfpc}{$H+}
uses Interfaces, Forms, Controls, Classes, SysUtils, ExtCtrls, AskPassForm;
type
  TFixture = class
    Window: TPasswordWindow;
    procedure EnterDummy(Sender: TObject);
  end;
procedure TFixture.EnterDummy(Sender: TObject);
begin
  Window.Timeout.Enabled:=False;
  Window.Password.Text:='dummy-test-value'; Window.ModalResult:=mrOK;
end;
var D: TPasswordWindow; Fixture: TFixture;
begin
  RequireDerivedFormResource:=False; Application.Initialize;
  Fixture:=TFixture.Create;
  try
    D:=TPasswordWindow.Create(nil); Fixture.Window:=D;
    try
      if D.Password.PasswordChar<>'*' then raise Exception.Create('Password is not masked');
      D.Timeout.Interval:=50; D.Timeout.OnTimer:=@Fixture.EnterDummy;
      if D.ShowModal<>mrOK then raise Exception.Create('Accept failed');
      if D.Password.Text<>'dummy-test-value' then raise Exception.Create('Input mismatch');
      D.Password.Clear;
      if D.Password.Text<>'' then raise Exception.Create('Clear failed');
      WriteLn('PASS: masked entry, accept and clear');
    finally D.Free; end;
    D:=TPasswordWindow.Create(nil);
    try
      D.Timeout.Interval:=50;
      if D.ShowModal<>mrCancel then raise Exception.Create('Timeout cancellation failed');
      WriteLn('PASS: timeout cancels password prompt');
    finally D.Free; end;
    WriteLn('OK: password dialog tests passed; only dummy input used.');
  finally Fixture.Free; end;
end.
