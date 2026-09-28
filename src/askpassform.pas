unit AskPassForm;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls;
type
  TPasswordWindow = class(TForm)
    Password: TEdit;
    Timeout: TTimer;
    procedure Expired(Sender: TObject);
    constructor Create(AOwner: TComponent); override;
  end;
implementation
constructor TPasswordWindow.Create(AOwner: TComponent);
var L: TLabel; B: TButton;
begin
  inherited CreateNew(AOwner,1);
  Caption:='VM Manager - Autorizar acesso'; BorderStyle:=bsDialog;
  Position:=poScreenCenter; Width:=590; Height:=260; Font.Name:='Segoe UI'; Font.Size:=10;
  FormStyle:=fsStayOnTop;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(20,18,545,55); L.AutoSize:=False; L.WordWrap:=True;
  L.Caption:='Senha do Linux para '+GetEnvironmentVariable('VMMANAGER_AUTH_TARGET');
  Password:=TEdit.Create(Self); Password.Parent:=Self; Password.SetBounds(20,82,540,30);
  Password.PasswordChar:='*'; Password.MaxLength:=1024;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(20,123,540,42); L.AutoSize:=False; L.WordWrap:=True;
  L.Caption:='A senha será usada somente nesta conexão. Ela não será salva no cadastro ou em arquivos.';
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(310,178,120,32); B.Caption:='Autorizar'; B.Default:=True; B.ModalResult:=mrOK;
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(440,178,120,32); B.Caption:='Cancelar'; B.Cancel:=True; B.ModalResult:=mrCancel;
  Timeout:=TTimer.Create(Self); Timeout.Interval:=120000; Timeout.OnTimer:=@Expired;
  ActiveControl:=Password;
end;
procedure TPasswordWindow.Expired(Sender: TObject);
begin ModalResult:=mrCancel; end;
end.
