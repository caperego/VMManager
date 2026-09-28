program VMManager;
{$mode objfpc}{$H+}
uses Interfaces, Forms, SysUtils, MainForm, SplashForm;

{$R VMManager.res}

var
  Splash: TSplashWindow;
  Started: QWord;
begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Started := GetTickCount64;
  Application.CreateForm(TSplashWindow, Splash);
  try
    Splash.Update;
    Application.ProcessMessages;
    Application.CreateForm(TMainWindow, MainWindow);
    while GetTickCount64 - Started < 1000 do begin
      Application.ProcessMessages;
      Sleep(20);
    end;
  finally
    Splash.Free;
  end;
  Application.Run;
end.
