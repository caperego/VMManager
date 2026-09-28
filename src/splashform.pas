unit SplashForm;
{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, SysUtils, Forms, Controls, ExtCtrls, StdCtrls, Graphics;

type
  TSplashWindow = class(TForm)
  public
    constructor Create(TheOwner: TComponent); override;
  end;

implementation

constructor TSplashWindow.Create(TheOwner: TComponent);
var
  Background: TImage;
  TitleLabel, SubtitleLabel, DetailLabel: TLabel;
  ImageFile: string;
begin
  inherited CreateNew(TheOwner, 1);
  BorderStyle := bsNone;
  FormStyle := fsSplash;
  Position := poScreenCenter;
  SetBounds(0, 0, 800, 450);
  Color := RGBToColor(8, 19, 48);

  Background := TImage.Create(Self);
  Background.Parent := Self;
  Background.Align := alClient;
  Background.Stretch := True;
  ImageFile := ExtractFilePath(ParamStr(0)) + 'splash.png';
  if FileExists(ImageFile) then
    Background.Picture.LoadFromFile(ImageFile);

  TitleLabel := TLabel.Create(Self);
  TitleLabel.Parent := Self;
  TitleLabel.SetBounds(45, 157, 390, 69);
  TitleLabel.AutoSize := False;
  TitleLabel.Transparent := True;
  TitleLabel.Caption := 'VM Manager';
  TitleLabel.Font.Name := 'Segoe UI';
  TitleLabel.Font.Size := 32;
  TitleLabel.Font.Style := [fsBold];
  TitleLabel.Font.Color := clWhite;

  SubtitleLabel := TLabel.Create(Self);
  SubtitleLabel.Parent := Self;
  SubtitleLabel.SetBounds(48, 232, 350, 31);
  SubtitleLabel.AutoSize := False;
  SubtitleLabel.Transparent := True;
  SubtitleLabel.Caption := 'KVM / QEMU / libvirt';
  SubtitleLabel.Font.Name := 'Segoe UI';
  SubtitleLabel.Font.Size := 13;
  SubtitleLabel.Font.Color := RGBToColor(155, 222, 255);

  DetailLabel := TLabel.Create(Self);
  DetailLabel.Parent := Self;
  DetailLabel.SetBounds(48, 381, 370, 23);
  DetailLabel.AutoSize := False;
  DetailLabel.Transparent := True;
  DetailLabel.Caption := 'Preparando o gerenciador...';
  DetailLabel.Font.Name := 'Segoe UI';
  DetailLabel.Font.Size := 10;
  DetailLabel.Font.Color := RGBToColor(182, 196, 232);
end;

end.
