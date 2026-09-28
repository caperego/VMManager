program IconSmoke;
{$mode objfpc}{$H+}

uses Interfaces, Forms, Graphics, SysUtils;

{$R ../VMManager.res}

var
  FileIcon, ResourceIcon: TIcon;
begin
  RequireDerivedFormResource := False;
  Application.Initialize;
  FileIcon := TIcon.Create;
  ResourceIcon := TIcon.Create;
  try
    FileIcon.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'VMManager.ico');
    ResourceIcon.LoadFromResourceName(HInstance, 'MAINICON');
    if (FileIcon.Width < 16) or (ResourceIcon.Width < 16) then
      raise Exception.Create('O ícone não foi carregado.');
    WriteLn('PASS: ícone ICO e recurso do executável carregados pelo Lazarus.');
  finally
    ResourceIcon.Free;
    FileIcon.Free;
  end;
end.
