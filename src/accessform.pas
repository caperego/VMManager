unit AccessForm;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, VMCore, AccessCore;
procedure ConfigureAccess(const Config: string; Index: Integer);
implementation
type
  TAccessWindow = class(TForm)
  private
    Config: string;
    Index: Integer;
    Host: THost;
    Job: TAccessJob;
    Poll: TTimer;
    Details: TMemo;
    Inspect,Generate,Revoke,Done: TButton;
    Confirm: TCheckBox;
    Pin: string;
    Trusted: Boolean;
    procedure ClickInspect(Sender: TObject);
    procedure ClickGenerate(Sender: TObject);
    procedure ClickRevoke(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure OnWindowCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure Start(Op: TAccessOperation);
    procedure EnableButtons;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;
constructor TAccessWindow.Create(AOwner: TComponent);
var L: TLabel;
begin
  inherited CreateNew(AOwner,1); Caption:='Configurações - Acesso SSH';
  Width:=760; Height:=570; BorderStyle:=bsDialog; Position:=poMainFormCenter;
  Font.Name:='Segoe UI'; Font.Size:=10; OnCloseQuery:=@OnWindowCloseQuery;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(20,16,710,65); L.AutoSize:=False; L.WordWrap:=True;
  L.Caption:='Configure o acesso ao host selecionado. O assistente cria uma chave exclusiva, autoriza no Linux e testa o libvirt. Se o acesso atual não funcionar, uma janela solicitará a senha do usuário SSH.';
  Inspect:=TButton.Create(Self); Inspect.Parent:=Self; Inspect.SetBounds(20,90,240,34);
  Inspect.Caption:='1. Verificar identidade do servidor'; Inspect.OnClick:=@ClickInspect;
  Details:=TMemo.Create(Self); Details.Parent:=Self; Details.SetBounds(20,138,710,205);
  Details.ReadOnly:=True; Details.ScrollBars:=ssAutoBoth;
  Confirm:=TCheckBox.Create(Self); Confirm.Parent:=Self; Confirm.SetBounds(20,355,710,28);
  Confirm.Caption:='Conferi a impressão digital com o administrador e reconheço este servidor.';
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(20,393,710,44); L.AutoSize:=False; L.WordWrap:=True;
  L.Caption:='A chave é criada sem frase secreta, com acesso local restrito ao seu usuário Windows. Na recriação, a chave antiga só é revogada após testar e salvar a nova.';
  Generate:=TButton.Create(Self); Generate.Parent:=Self; Generate.SetBounds(20,455,250,36);
  Generate.Caption:='2. Gerar / recriar e autorizar'; Generate.OnClick:=@ClickGenerate;
  Revoke:=TButton.Create(Self); Revoke.Parent:=Self; Revoke.SetBounds(282,455,230,36);
  Revoke.Caption:='Revogar e excluir chave'; Revoke.OnClick:=@ClickRevoke;
  Done:=TButton.Create(Self); Done.Parent:=Self; Done.SetBounds(610,455,120,36);
  Done.Caption:='Fechar'; Done.ModalResult:=mrClose;
  Poll:=TTimer.Create(Self); Poll.Interval:=150; Poll.OnTimer:=@Tick;
end;
destructor TAccessWindow.Destroy;
begin
  if Job<>nil then begin Job.Terminate; Job.WaitFor; Job.Free; end;
  inherited Destroy;
end;
procedure TAccessWindow.EnableButtons;
begin
  Inspect.Enabled:=Job=nil;
  Generate.Enabled:=(Job=nil) and (Pin<>'');
  Revoke.Enabled:=Generate.Enabled and Host.ManagedKey and ManagedPath(Host.KeyFile);
  Done.Enabled:=Job=nil; Confirm.Enabled:=(Job=nil) and not Trusted;
end;
procedure TAccessWindow.Start(Op: TAccessOperation);
begin
  Job:=TAccessJob.Create(Host,Op,Config,Index,Pin); EnableButtons;
  Details.Lines.Add('Aguarde...'); Job.Start;
end;
procedure TAccessWindow.ClickInspect(Sender: TObject);
begin
  Pin:=''; Trusted:=False; Confirm.Checked:=False; Start(aoInspect);
end;
procedure TAccessWindow.ClickGenerate(Sender: TObject);
begin
  if not Trusted and not Confirm.Checked then begin
    ShowMessage('Confira a impressão digital por um canal confiável e marque a confirmação.'); Exit;
  end;
  if Host.ManagedKey and
    (MessageDlg('Recriar acesso','Uma nova chave será instalada e testada antes de revogar a chave atual deste cadastro. Continuar?',mtConfirmation,[mbYes,mbNo],0,mbNo)<>mrYes) then Exit;
  Start(aoCreate);
end;
procedure TAccessWindow.ClickRevoke(Sender: TObject);
begin
  if not Trusted and not Confirm.Checked then begin ShowMessage('Confirme primeiro a identidade do servidor.'); Exit; end;
  if MessageDlg('Revogar e excluir',
    'Remover a autorização desta chave no Linux e apagar seus arquivos locais?'+LineEnding+
    'O acesso por esta chave deixará de funcionar. Para recriar, será necessário acesso por senha ou outra chave.'+LineEnding+
    'Chaves de outros cadastros e arquivos externos serão preservados.',mtWarning,[mbYes,mbNo],0,mbNo)=mrYes then Start(aoRevoke);
end;
procedure TAccessWindow.OnWindowCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose:=Job=nil;
  if not CanClose then ShowMessage('Aguarde a conclusão. Se a janela de senha estiver aberta, use Cancelar nela.');
end;
procedure TAccessWindow.Tick(Sender: TObject);
var All: THosts;
begin
  if (Job=nil) or not Job.Finished then Exit;
  Job.WaitFor;
  if Job.ErrorText<>'' then begin
    Details.Lines.Add(Job.ErrorText);
    if Job.Changed then Pin:='';
  end else if Job.Fingerprint<>'' then begin
    Pin:=Job.HostLine; Trusted:=Job.Known;
    Details.Lines.Add('Servidor: '+Host.UserName+'@'+Host.Address+':'+IntToStr(Host.Port));
    Details.Lines.Add(Job.Fingerprint);
    if Trusted then Details.Lines.Add('Identidade já reconhecida no Windows.')
    else Details.Lines.Add('Primeiro acesso: confira esta impressão digital com o administrador antes de continuar.');
  end else Details.Lines.Add(Job.Notice);
  FreeAndNil(Job);
  try LoadHosts(Config,All); if (Index>=0) and (Index<=High(All)) then Host:=All[Index];
  except on E: Exception do Details.Lines.Add(E.Message); end;
  EnableButtons;
end;
procedure ConfigureAccess(const Config: string; Index: Integer);
var D: TAccessWindow; All: THosts;
begin
  LoadHosts(Config,All);
  if (Index<0) or (Index>High(All)) then raise Exception.Create('Selecione um host.');
  D:=TAccessWindow.Create(nil);
  try
    D.Config:=Config; D.Index:=Index; D.Host:=All[Index];
    D.Details.Lines.Add('Host: '+D.Host.Title+' ('+D.Host.UserName+'@'+D.Host.Address+')');
    if D.Host.KeyFile<>'' then D.Details.Lines.Add('Chave atual: '+D.Host.KeyFile);
    if not D.Host.ManagedKey and (D.Host.KeyFile<>'') then
      D.Details.Lines.Add('Chave externa: será preservada ao configurar uma chave nova.');
    D.EnableButtons; D.ShowModal;
  finally D.Free; end;
end;
end.
