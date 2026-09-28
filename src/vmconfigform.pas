unit VMConfigForm;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  VMCore, VMConfigCore, VMConfigJob;
function ShowVMConfiguration(AOwner: TComponent; const Host: THost;
  const UUID, VMName: string): Boolean;
implementation
uses Dialogs;
type
  TConfigurationWindow = class(TForm)
  private
    FHost: THost;
    FUUID, FRawXML: string;
    FJob: TConfigurationJob;
    FSaveMode, FChanged: Boolean;
    FConfig: TVMConfiguration;
    Header, StateLabel, StatusLabel: TLabel;
    CPUField, MemoryField: TEdit;
    AutoStartCheck: TCheckBox;
    Details: TMemo;
    SaveButton, ReloadButton: TButton;
    Poll: TTimer;
    procedure StartRead;
    procedure CheckJob(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure AutoStartToggle(Sender: TObject);
    procedure ReloadClick(Sender: TObject);
    procedure Closing(Sender: TObject; var CanClose: Boolean);
    procedure SetBusy(Busy: Boolean);
    procedure ShowConfiguration;
  public
    constructor CreateForVM(AOwner: TComponent; const Host: THost;
      const UUID, VMName: string);
    destructor Destroy; override;
    property Changed: Boolean read FChanged;
  end;

constructor TConfigurationWindow.CreateForVM(AOwner: TComponent; const Host: THost;
  const UUID, VMName: string);
var L: TLabel; B: TButton;
begin
  inherited CreateNew(AOwner,1);
  FHost:=Host; FUUID:=UUID;
  Caption:='Configurar máquina virtual';
  SetBounds(0,0,750,650); Position:=poMainFormCenter; BorderStyle:=bsSizeable;
  OnCloseQuery:=@Closing;
  Constraints.MinWidth:=690; Constraints.MinHeight:=580;
  Font.Name:='Segoe UI'; Font.Size:=10;
  Header:=TLabel.Create(Self); Header.Parent:=Self; Header.SetBounds(20,16,700,25);
  Header.Font.Size:=12; Header.Font.Style:=[fsBold]; Header.Caption:=VMName;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(20,46,700,21);
  L.Caption:='UUID: '+UUID;
  StateLabel:=TLabel.Create(Self); StateLabel.Parent:=Self; StateLabel.SetBounds(20,76,690,24);
  StateLabel.Caption:='Consultando estado e definição no servidor...';
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(20,113,210,21);
  L.Caption:='CPUs virtuais';
  CPUField:=TEdit.Create(Self); CPUField.Parent:=Self; CPUField.SetBounds(20,137,150,29);
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(215,113,290,21);
  L.Caption:='RAM para a próxima inicialização (MiB)';
  MemoryField:=TEdit.Create(Self); MemoryField.Parent:=Self; MemoryField.SetBounds(215,137,185,29);
  AutoStartCheck:=TCheckBox.Create(Self); AutoStartCheck.Parent:=Self;
  AutoStartCheck.SetBounds(20,178,690,24);
  AutoStartCheck.Caption:='Iniciar automaticamente quando o servidor ligar';
  AutoStartCheck.OnChange:=@AutoStartToggle;
  AutoStartCheck.ShowHint:=True;
  AutoStartCheck.Hint:='Esta opção inicia a VM junto com o host Linux/libvirt.';
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(20,204,690,38);
  L.Caption:='CPU e RAM só podem ser alteradas com a VM desligada e passam a valer na próxima inicialização.';
  L.WordWrap:=True;
  Details:=TMemo.Create(Self); Details.Parent:=Self; Details.SetBounds(20,244,695,261);
  Details.Anchors:=[akLeft,akTop,akRight,akBottom];
  Details.ReadOnly:=True; Details.ScrollBars:=ssBoth; Details.WordWrap:=False;
  Details.Font.Name:='Consolas'; Details.Font.Size:=10;
  StatusLabel:=TLabel.Create(Self); StatusLabel.Parent:=Self; StatusLabel.SetBounds(20,515,685,42);
  StatusLabel.Anchors:=[akLeft,akRight,akBottom]; StatusLabel.WordWrap:=True;
  StatusLabel.Caption:='Conectando por SSH...';
  SaveButton:=TButton.Create(Self); SaveButton.Parent:=Self;
  SaveButton.Caption:='Salvar alterações'; SaveButton.SetBounds(303,565,170,36);
  SaveButton.Anchors:=[akRight,akBottom]; SaveButton.OnClick:=@SaveClick;
  ReloadButton:=TButton.Create(Self); ReloadButton.Parent:=Self;
  ReloadButton.Caption:='Recarregar'; ReloadButton.SetBounds(483,565,110,36);
  ReloadButton.Anchors:=[akRight,akBottom]; ReloadButton.OnClick:=@ReloadClick;
  B:=TButton.Create(Self); B.Parent:=Self; B.Caption:='Fechar';
  B.SetBounds(603,565,110,36); B.Anchors:=[akRight,akBottom]; B.ModalResult:=mrClose;
  Poll:=TTimer.Create(Self); Poll.Interval:=150; Poll.OnTimer:=@CheckJob;
  SetBusy(True); StartRead;
end;

destructor TConfigurationWindow.Destroy;
begin
  Poll.Enabled:=False;
  if FJob<>nil then begin FJob.Terminate; FJob.WaitFor; FJob.Free; end;
  inherited Destroy;
end;

procedure TConfigurationWindow.SetBusy(Busy: Boolean);
begin
  CPUField.Enabled:=not Busy and (FRawXML<>'') and (FConfig.State='shut off');
  MemoryField.Enabled:=CPUField.Enabled;
  AutoStartCheck.Enabled:=not Busy and (FRawXML<>'');
  SaveButton.Enabled:=not Busy and (FRawXML<>'') and
    ((FConfig.State='shut off') or (AutoStartCheck.Checked<>FConfig.AutoStart));
  ReloadButton.Enabled:=not Busy;
end;

procedure TConfigurationWindow.StartRead;
begin
  if FJob<>nil then Exit;
  FRawXML:=''; Details.Lines.Text:='';
  StatusLabel.Caption:='Lendo configuração da VM pelo SSH...';
  SetBusy(True); FSaveMode:=False;
  FJob:=TConfigurationJob.CreateRead(FHost,FUUID); FJob.Start;
end;

procedure TConfigurationWindow.ShowConfiguration;
begin
  StateLabel.Caption:='Estado: '+FConfig.State+'    |    Limite de CPUs: '+IntToStr(FConfig.CPUMax)+
    '    |    RAM máxima: '+IntToStr((FConfig.MaxMemoryKiB+1023) div 1024)+' MiB';
  CPUField.Text:=IntToStr(FConfig.CPUCount);
  MemoryField.Text:=IntToStr((FConfig.MemoryKiB+1023) div 1024);
  AutoStartCheck.Checked:=FConfig.AutoStart;
  Details.Lines.Text:='DISCOS'+LineEnding+FConfig.Disks+LineEnding+
    'REDE'+LineEnding+FConfig.Networks+LineEnding+
    'INICIALIZAÇÃO'+LineEnding+FConfig.Boot;
  if FConfig.State='shut off' then
    StatusLabel.Caption:='Definição carregada. CPU/RAM e início automático disponíveis.'
  else StatusLabel.Caption:='VM ligada: CPU/RAM ficam bloqueadas; o início automático pode ser alterado.';
end;

procedure TConfigurationWindow.CheckJob(Sender: TObject);
var E: string; WasSave: Boolean;
begin
  if (FJob=nil) or not FJob.Finished then Exit;
  FJob.WaitFor; E:=FJob.ErrorText; WasSave:=FSaveMode;
  if E='' then begin
    FConfig:=FJob.Configuration; FRawXML:=FJob.RawXML;
    if WasSave then FChanged:=True;
    ShowConfiguration;
    if WasSave then StatusLabel.Caption:='Alterações salvas e verificadas no servidor.';
  end else begin
    FRawXML:=''; CPUField.Text:=''; MemoryField.Text:=''; Details.Lines.Text:='';
    StatusLabel.Caption:='Falha ao consultar ou salvar. Recarregue antes de outra alteração.';
  end;
  FreeAndNil(FJob); SetBusy(False);
  if E<>'' then ShowMessage(E);
end;

procedure TConfigurationWindow.SaveClick(Sender: TObject);
var CPU: Integer; RAM: QWord; Summary,CurrentRAMText: string;
  CPUChanged,MemoryChanged,AutoStartChanged: Boolean;
begin
  try
    if FRawXML='' then raise Exception.Create('Recarregue a definição da VM.');
    CPU:=FConfig.CPUCount;
    RAM:=(FConfig.MemoryKiB+1023) div 1024;
    CPUChanged:=False; MemoryChanged:=False;
    if FConfig.State='shut off' then begin
      if Trim(CPUField.Text)<>IntToStr(FConfig.CPUCount) then begin
        if not TryStrToInt(Trim(CPUField.Text),CPU) then
          raise Exception.Create('Informe CPUs como número inteiro.');
        CPUChanged:=CPU<>FConfig.CPUCount;
        if CPUChanged then ValidateCPUCount(CPU);
      end;
      CurrentRAMText:=IntToStr((FConfig.MemoryKiB+1023) div 1024);
      if Trim(MemoryField.Text)<>CurrentRAMText then begin
        if not TryStrToQWord(Trim(MemoryField.Text),RAM) then
          raise Exception.Create('Informe RAM como número inteiro de MiB.');
        MemoryChanged:=True;
        ValidateMemoryMiB(RAM);
      end;
    end;
    CPUChanged:=CPUChanged and (CPU<>FConfig.CPUCount);
    MemoryChanged:=MemoryChanged and (RAM*1024<>FConfig.MemoryKiB);
    AutoStartChanged:=AutoStartCheck.Checked<>FConfig.AutoStart;
    if not CPUChanged and not MemoryChanged and not AutoStartChanged then begin
      StatusLabel.Caption:='Nenhuma alteração a salvar.'; Exit;
    end;
    Summary:='Salvar alterações de '+FConfig.Name+'?'+LineEnding+
      'Host: '+FHost.Title+' ('+FHost.Address+')'+LineEnding+'UUID: '+FUUID+LineEnding+LineEnding;
    if CPUChanged then
      Summary:=Summary+'CPUs: '+IntToStr(FConfig.CPUCount)+' → '+IntToStr(CPU)+LineEnding;
    if MemoryChanged then
      Summary:=Summary+'RAM: '+IntToStr((FConfig.MemoryKiB+1023) div 1024)+' → '+IntToStr(RAM)+' MiB'+LineEnding;
    if AutoStartChanged then begin
      if FConfig.AutoStart then Summary:=Summary+'Início automático: Sim → Não'+LineEnding
      else Summary:=Summary+'Início automático: Não → Sim'+LineEnding;
    end;
    if CPUChanged or MemoryChanged then
      Summary:=Summary+LineEnding+'Os valores de CPU/RAM passam a valer na próxima inicialização da VM.'+LineEnding;
    Summary:=Summary+
      'O início automático ocorre quando o host Linux/libvirt iniciar.'+LineEnding+
      'O libvirt pode recusar valores incompatíveis. Em caso de falha parcial, recarregue para conferir.';
    if MessageDlg('Confirmar configuração',Summary,mtConfirmation,[mbYes,mbNo],0,mbNo)<>mrYes then Exit;
    FSaveMode:=True; FJob:=TConfigurationJob.CreateSave(FHost,FUUID,FRawXML,CPU,RAM,
      CPUChanged,MemoryChanged,
      FConfig.AutoStart,AutoStartCheck.Checked);
    SetBusy(True); StatusLabel.Caption:='Salvando definição no servidor...'; FJob.Start;
  except on E: Exception do ShowMessage(E.Message); end;
end;

procedure TConfigurationWindow.AutoStartToggle(Sender: TObject);
begin
  if FJob=nil then SetBusy(False);
end;

procedure TConfigurationWindow.ReloadClick(Sender: TObject);
begin StartRead; end;

procedure TConfigurationWindow.Closing(Sender: TObject; var CanClose: Boolean);
begin
  CanClose:=FJob=nil;
  if not CanClose then StatusLabel.Caption:='Aguarde a consulta ou gravação terminar antes de fechar esta janela.';
end;

function ShowVMConfiguration(AOwner: TComponent; const Host: THost;
  const UUID, VMName: string): Boolean;
var D: TConfigurationWindow;
begin
  if not ValidUUID(UUID) then raise Exception.Create('UUID inválido.');
  ValidateHost(Host);
  D:=TConfigurationWindow.CreateForVM(AOwner,Host,UUID,VMName);
  try D.ShowModal; Result:=D.Changed; finally D.Free; end;
end;
end.
