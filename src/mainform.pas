unit MainForm;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Math, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls,
  Dialogs, Process, Buttons, Graphics, Types, VMCore, AccessForm, UIIcons,
  VMConfigForm, VMClone;
type
  TMainWindow = class(TForm)
  private
    Hosts: THosts;
    HostBox: TComboBox;
    Grid: TListView;
    Log: TMemo;
    ToolbarArea, HostBar, VMBar: TPanel;
    HeaderHint: TLabel;
    LayoutLock: Boolean;
    Status: TLabel;
    Poll: TTimer;
    Job: TRemoteJob;
    CloneJob: TCloneJob;
    PendingAction: TVMAction;
    ConfigFile: string;
    procedure ButtonClick(Sender: TObject);
    procedure HostChanged(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure Closing(Sender: TObject; var CanClose: Boolean);
    procedure RefreshHosts(Index: Integer);
    procedure BeginJob(AAction: TVMAction; const UUID: string);
    procedure SetBusy(Busy: Boolean);
    procedure EditHost(Index: Integer);
    procedure Console;
    procedure VMDoubleClick(Sender: TObject);
    procedure ResizeToolbars(Sender: TObject);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;
var MainWindow: TMainWindow;
implementation
constructor TMainWindow.Create(TheOwner: TComponent);
var B: TBitBtn; Col: TListColumn; L: TLabel; Mark: TShape; GlyphBitmap: TBitmap;
  function AddButton(ParentPanel: TPanel; X,W,Kind: Integer; const Title,Tip: string): TBitBtn;
  begin
    Result:=TBitBtn.Create(Self); Result.Parent:=ParentPanel;
    Result.SetBounds(X,51,W,36); Result.Caption:=Title; Result.Tag:=Kind;
    Result.OnClick:=@ButtonClick; Result.ShowHint:=True; Result.Hint:=Tip;
    Result.Layout:=blGlyphLeft; Result.Spacing:=6; Result.Margin:=7;
    GlyphBitmap:=ButtonIcon(Kind);
    try Result.Glyph.Assign(GlyphBitmap); finally GlyphBitmap.Free; end;
  end;
  procedure AddHeader(ParentPanel: TPanel; const Title: string; Accent: TColor);
  begin
    Mark:=TShape.Create(Self); Mark.Parent:=ParentPanel; Mark.Shape:=stRectangle;
    Mark.Pen.Style:=psClear; Mark.Brush.Color:=Accent; Mark.SetBounds(0,0,5,ParentPanel.Height);
    Mark.Anchors:=[akLeft,akTop,akBottom];
    L:=TLabel.Create(Self); L.Parent:=ParentPanel; L.SetBounds(16,10,300,25);
    L.Caption:=Title; L.Font.Style:=[fsBold]; L.Font.Color:=Accent; L.Font.Size:=11;
  end;
begin
  inherited CreateNew(TheOwner,1);
  Caption := 'VM Manager 0.3.6 - KVM / QEMU / libvirt';
  Width := 1120; Height := 720; Position := poScreenCenter;
  Constraints.MinWidth := 720; Constraints.MinHeight := 600;
  Font.Name := 'Segoe UI'; Font.Size := 10;
  OnCloseQuery := @Closing;
  OnResize:=@ResizeToolbars;
  ToolbarArea:=TPanel.Create(Self); ToolbarArea.Parent:=Self; ToolbarArea.Align:=alTop;
  ToolbarArea.Height:=203; ToolbarArea.BevelOuter:=bvNone;
  VMBar:=TPanel.Create(Self); VMBar.Parent:=ToolbarArea; VMBar.Align:=alNone;
  VMBar.Caption:='';
  VMBar.SetBounds(0,102,1120,101); VMBar.Anchors:=[akLeft,akTop,akRight];
  VMBar.BevelOuter:=bvNone; VMBar.ParentColor:=False;
  VMBar.Color:=RGBToColor(245,247,250);
  HostBar:=TPanel.Create(Self); HostBar.Parent:=ToolbarArea; HostBar.Align:=alNone;
  HostBar.Caption:='';
  HostBar.SetBounds(0,0,1120,102); HostBar.Anchors:=[akLeft,akTop,akRight];
  HostBar.BevelOuter:=bvNone; HostBar.ParentColor:=False;
  HostBar.Color:=RGBToColor(235,244,251);
  AddHeader(HostBar,'SERVIDORES',RGBToColor(32,102,170));
  HostBox:=TComboBox.Create(Self); HostBox.Parent:=HostBar;
  HostBox.SetBounds(16,30,425,28); HostBox.Style:=csDropDownList; HostBox.OnChange:=@HostChanged;
  B:=AddButton(HostBar,451,102,0,'Novo','Cadastrar servidor Linux');
  B:=AddButton(HostBar,561,105,1,'Editar','Editar o host selecionado');
  B:=AddButton(HostBar,674,106,2,'Excluir','Remover o cadastro do host');
  B:=AddButton(HostBar,788,278,9,'Configurações de acesso SSH','Gerar, autorizar ou revogar a chave SSH');
  AddHeader(VMBar,'MÁQUINAS VIRTUAIS',RGBToColor(77,87,112));
  HeaderHint:=TLabel.Create(Self); HeaderHint.Parent:=VMBar; HeaderHint.SetBounds(300,13,500,23);
  HeaderHint.Caption:='Duplo clique numa VM para abrir o console';
  HeaderHint.Font.Color:=RGBToColor(93,102,118);
  B:=AddButton(VMBar,16,131,3,'Atualizar','Consultar todas as VMs do host');
  B:=AddButton(VMBar,156,116,4,'Iniciar','Iniciar a VM selecionada');
  B:=AddButton(VMBar,281,129,5,'Desligar','Pedir desligamento normal');
  B:=AddButton(VMBar,419,129,6,'Reiniciar','Pedir reinício normal');
  B:=AddButton(VMBar,557,176,7,'Forçar parada','Cortar a energia da VM');
  B:=AddButton(VMBar,742,130,8,'Console','Abrir a tela da VM');
  B:=AddButton(VMBar,881,180,10,'Configurar VM','Ver discos e rede; editar CPUs e RAM com a VM desligada');
  B:=AddButton(VMBar,1070,130,11,'Clonar','Copiar VM desligada e seus discos para uma nova VM');
  Status := TLabel.Create(Self); Status.Parent := Self; Status.Align := alBottom;
  Status.BorderSpacing.Around := 8; Status.Caption := 'Cadastre um servidor Linux para começar.';
  Log := TMemo.Create(Self); Log.Parent := Self; Log.Align := alBottom; Log.Height := 130;
  Log.ReadOnly := True; Log.ScrollBars := ssVertical;
  Grid := TListView.Create(Self); Grid.Parent := Self; Grid.Align := alClient;
  Grid.ViewStyle := vsReport; Grid.ReadOnly := True; Grid.RowSelect := True;
  Grid.OnDblClick:=@VMDoubleClick; Grid.ShowHint:=True;
  Grid.Hint:='Duplo clique numa máquina virtual para abrir o console';
  Col := Grid.Columns.Add; Col.Caption := 'Máquina virtual'; Col.Width := 340;
  Col := Grid.Columns.Add; Col.Caption := 'Estado'; Col.Width := 210;
  Col := Grid.Columns.Add; Col.Caption := 'UUID'; Col.Width := 410;
  Poll := TTimer.Create(Self); Poll.Interval := 150; Poll.OnTimer := @Tick;
  ConfigFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA'))+'VMManager\hosts.ini';
  ResizeToolbars(nil);
  try LoadHosts(ConfigFile,Hosts); except on E: Exception do ShowMessage(E.Message); end;
  RefreshHosts(0);
end;
procedure TMainWindow.ResizeToolbars(Sender: TObject);
var Rows,HostHeight,VMHeight,W,Available: Integer;
  procedure FlowButtons(Panel: TPanel; StartY: Integer; out RowCount: Integer);
  var J,PosX,PosY: Integer; Control: TControl;
  begin
    PosX:=16; PosY:=StartY; RowCount:=1;
    for J:=0 to Panel.ControlCount-1 do begin
      Control:=Panel.Controls[J];
      if not (Control is TBitBtn) then Continue;
      if (PosX>16) and (PosX+Control.Width>Panel.ClientWidth-16) then begin
        PosX:=16; Inc(PosY,42); Inc(RowCount);
      end;
      Control.SetBounds(PosX,PosY,Control.Width,36);
      Inc(PosX,Control.Width+8);
    end;
  end;
begin
  if LayoutLock or (ToolbarArea=nil) or (HostBar=nil) or (VMBar=nil) then Exit;
  W:=ToolbarArea.ClientWidth;
  if W<1 then Exit;
  LayoutLock:=True;
  try
    HostBar.SetBounds(0,0,W,HostBar.Height);
    HostBox.SetBounds(16,30,Max(200,Min(425,W-32)),28);
    FlowButtons(HostBar,62,Rows);
    HostHeight:=Max(102,62+(Rows-1)*42+40);
    HostBar.Height:=HostHeight;

    VMBar.SetBounds(0,HostHeight,W,VMBar.Height);
    Available:=VMBar.ClientWidth;
    HeaderHint.Visible:=Available>=850;
    FlowButtons(VMBar,40,Rows);
    VMHeight:=Max(101,40+(Rows-1)*42+46);
    VMBar.Height:=VMHeight;
    ToolbarArea.Height:=HostHeight+VMHeight;
  finally LayoutLock:=False; end;
end;
destructor TMainWindow.Destroy;
begin
  if Job <> nil then begin Job.Terminate; Job.WaitFor; Job.Free; end;
  if CloneJob <> nil then begin CloneJob.Terminate; CloneJob.WaitFor; CloneJob.Free; end;
  inherited Destroy;
end;
procedure TMainWindow.Closing(Sender: TObject; var CanClose: Boolean);
begin
  if CloneJob <> nil then begin
    CloneJob.Terminate; Status.Caption := 'Cancelando acompanhamento da clonagem. Aguarde e confira o servidor.';
    CanClose := False;
  end else if Job <> nil then begin
    Job.Terminate; Status.Caption := 'Cancelando conexão. Aguarde e feche novamente.';
    CanClose := False;
  end;
end;
procedure TMainWindow.RefreshHosts(Index: Integer);
var I: Integer;
begin
  HostBox.Clear;
  for I := 0 to High(Hosts) do HostBox.Items.Add(Hosts[I].Title+' - '+Hosts[I].UserName+'@'+Hosts[I].Address);
  if Index > High(Hosts) then Index := High(Hosts);
  HostBox.ItemIndex := Index; HostChanged(nil);
end;
procedure TMainWindow.HostChanged(Sender: TObject);
begin
  Grid.Items.Clear;
  Status.Caption := 'Clique em Atualizar para consultar qemu:///system. Autenticação por chave/agente SSH.';
end;
procedure TMainWindow.SetBusy(Busy: Boolean);
begin
  HostBar.Enabled := not Busy; VMBar.Enabled:=not Busy; Grid.Enabled := not Busy;
end;
procedure TMainWindow.BeginJob(AAction: TVMAction; const UUID: string);
begin
  if (Job<>nil) or (CloneJob<>nil) or (HostBox.ItemIndex<0) then Exit;
  ValidateHost(Hosts[HostBox.ItemIndex]);
  PendingAction := AAction;
  Job := TRemoteJob.Create(Hosts[HostBox.ItemIndex],AAction,UUID);
  SetBusy(True); Status.Caption := 'Conectando por SSH...'; Job.Start;
end;
procedure TMainWindow.Tick(Sender: TObject);
var I: Integer; Item: TListItem; E,N: string; A: TVMAction;
begin
  if CloneJob<>nil then begin
    if not CloneJob.Finished then Exit;
    CloneJob.WaitFor; E:=CloneJob.ErrorText; N:=CloneJob.Notice;
    FreeAndNil(CloneJob); SetBusy(False);
    if E<>'' then begin
      Status.Caption:='Clonagem não confirmada. Confira o registro e o servidor.';
      Log.Lines.Add(FormatDateTime('hh:nn:ss',Now)+'  '+E);
    end else begin
      Log.Lines.Add(FormatDateTime('hh:nn:ss',Now)+'  '+N);
      BeginJob(vaList,'');
    end;
    Exit;
  end;
  if (Job=nil) then Exit;
  if not Job.Finished then Exit;
  Job.WaitFor; E := Job.ErrorText; N := Job.Notice; A := PendingAction;
  if (E='') and (A=vaList) then begin
    Grid.Items.BeginUpdate;
    try
      Grid.Items.Clear;
      for I := 0 to High(Job.VMs) do begin
        Item := Grid.Items.Add; Item.Caption := Job.VMs[I].Name;
        Item.SubItems.Add(Job.VMs[I].State); Item.SubItems.Add(Job.VMs[I].UUID);
      end;
    finally Grid.Items.EndUpdate; end;
  end;
  FreeAndNil(Job); SetBusy(False);
  if E<>'' then begin
    Grid.Items.Clear;
    Status.Caption := 'Falha. Confira o registro abaixo e atualize antes de repetir ações.';
    Log.Lines.Add(FormatDateTime('hh:nn:ss',Now)+'  '+E);
  end else if A=vaList then begin
    Status.Caption := Format('%d VMs - atualizado às %s. Duplo clique numa VM para abrir o console.',
      [Grid.Items.Count,FormatDateTime('hh:nn:ss',Now)]);
  end else begin
    Log.Lines.Add(FormatDateTime('hh:nn:ss',Now)+string('  Solicitação aceita: ')+N);
    Log.Lines.Add('Desligamento/reinício podem levar tempo. Atualize novamente para acompanhar.');
    BeginJob(vaList,'');
  end;
end;
procedure TMainWindow.EditHost(Index: Integer);
var D: TForm; Fields: array[0..5] of TEdit; I: Integer; L: TLabel; B: TButton; H: THost;
const Labels: array[0..5] of string = ('Nome do host','DNS ou IPv4','Usuário SSH','Porta SSH','Chave privada (caminho completo; vazio = agente)','virt-viewer.exe (opcional; detecção automática)');
begin
  H := Default(THost); H.Port := 22;
  if Index>=0 then H := Hosts[Index];
  D := TForm.CreateNew(Self); try
    D.Caption := 'Cadastro de servidor Linux KVM'; D.SetBounds(0,0,650,490);
    D.Position := poMainFormCenter; D.BorderStyle := bsDialog;
    for I := 0 to 5 do begin
      L := TLabel.Create(D); L.Parent := D; L.Caption := Labels[I]; L.SetBounds(20,12+I*62,600,22);
      Fields[I] := TEdit.Create(D); Fields[I].Parent := D; Fields[I].SetBounds(20,35+I*62,600,28);
    end;
    Fields[0].Text:=H.Title; Fields[1].Text:=H.Address; Fields[2].Text:=H.UserName;
    Fields[3].Text:=IntToStr(H.Port); Fields[4].Text:=H.KeyFile; Fields[5].Text:=H.Viewer;
    B := TButton.Create(D); B.Parent:=D; B.Caption:='Salvar'; B.SetBounds(390,415,110,32); B.ModalResult:=mrOK; B.Default:=True;
    B := TButton.Create(D); B.Parent:=D; B.Caption:='Cancelar'; B.SetBounds(510,415,110,32); B.ModalResult:=mrCancel; B.Cancel:=True;
    while D.ShowModal=mrOK do begin
      try
        H.Title:=Trim(Fields[0].Text); H.Address:=Trim(Fields[1].Text); H.UserName:=Trim(Fields[2].Text);
        H.Port:=StrToIntDef(Fields[3].Text,0);
        if H.KeyFile<>Trim(Fields[4].Text) then H.ManagedKey:=False;
        H.KeyFile:=Trim(Fields[4].Text); H.Viewer:=Trim(Fields[5].Text);
        ValidateHost(H);
        if Index<0 then begin Index:=Length(Hosts); SetLength(Hosts,Index+1); end;
        Hosts[Index]:=H; SaveHosts(ConfigFile,Hosts); RefreshHosts(Index); Break;
      except on E: Exception do ShowMessage(E.Message); end;
    end;
  finally D.Free; end;
end;
procedure TMainWindow.Console;
var P: TProcess; H: THost; U,Bridge: string;
begin
  H := Hosts[HostBox.ItemIndex]; ValidateHost(H);
  if H.Viewer='' then begin
    H.Viewer:=FindVirtViewerExecutable;
    if H.Viewer='' then raise Exception.Create('virt-viewer não encontrado. Instale o VMManager com virt-viewer ou informe o caminho no cadastro do host.');
    Hosts[HostBox.ItemIndex]:=H;
    SaveHosts(ConfigFile,Hosts);
  end;
  U := Grid.Selected.SubItems[1];
  if not ValidUUID(U) then raise Exception.Create('UUID inválido.');
  Bridge:=ExtractFilePath(ParamStr(0))+'ConsoleBridge.exe';
  if not FileExists(Bridge) then raise Exception.Create('ConsoleBridge.exe não encontrado na pasta do aplicativo. Execute build.ps1.');
  P := TProcess.Create(nil);
  try
    P.Executable := Bridge; P.Parameters.Add(ConfigFile); P.Parameters.Add(IntToStr(HostBox.ItemIndex));
    P.Parameters.Add(U); P.Options := [poNoConsole]; P.Execute;
  finally P.Free; end;
  Log.Lines.Add('Console solicitado por túnel OpenSSH. Feche o visualizador para encerrar o túnel.');
end;
procedure TMainWindow.VMDoubleClick(Sender: TObject);
var At: TPoint; Item: TListItem;
begin
  if (Job<>nil) or (CloneJob<>nil) or (HostBox.ItemIndex<0) then Exit;
  At:=Grid.ScreenToClient(Mouse.CursorPos);
  Item:=Grid.GetItemAt(At.X,At.Y);
  if Item=nil then Exit;
  Grid.Selected:=Item;
  try Console; except on E: Exception do ShowMessage(E.Message); end;
end;
procedure TMainWindow.ButtonClick(Sender: TObject);
var ButtonTag,I,J: Integer; A: TVMAction; U,Question,NewName: string;
begin
  try
    ButtonTag := TBitBtn(Sender).Tag; I := HostBox.ItemIndex;
    if ButtonTag=0 then begin EditHost(-1); Exit; end;
    if I<0 then raise Exception.Create('Cadastre e selecione um host.');
    case ButtonTag of
      9: begin ConfigureAccess(ConfigFile,I); LoadHosts(ConfigFile,Hosts); RefreshHosts(I); end;
      1: EditHost(I);
      2: if MessageDlg(string('Excluir cadastro de ')+Hosts[I].Title+'?'+LineEnding+
        string('Isso remove apenas o cadastro. Para revogar uma chave, use Configurações de acesso SSH antes.'),mtConfirmation,[mbYes,mbNo],0,mbNo)=mrYes then begin
        for J:=I to High(Hosts)-1 do Hosts[J]:=Hosts[J+1];
        SetLength(Hosts,Length(Hosts)-1); SaveHosts(ConfigFile,Hosts); RefreshHosts(0);
      end;
      3: BeginJob(vaList,'');
      4..8,10,11: begin
        if Grid.Selected=nil then raise Exception.Create('Selecione uma VM na lista atualizada.');
        if ButtonTag=11 then begin
          if (Job<>nil) or (CloneJob<>nil) then Exit;
          U:=Grid.Selected.SubItems[1];
          if not ValidUUID(U) then raise Exception.Create('UUID inválido. Atualize a lista.');
          if Trim(Grid.Selected.SubItems[0])<>'shut off' then
            raise Exception.Create('Desligue a VM de origem antes de clonar. Atualize a lista para confirmar.');
          NewName:=Grid.Selected.Caption+'-clone';
          if not InputQuery('Clonar VM','Nome da nova máquina virtual:',NewName) then Exit;
          NewName:=Trim(NewName);
          if not ValidCloneName(NewName) then raise Exception.Create('Nome inválido. Use até 80 letras, números, ponto, hífen ou sublinhado; comece por letra ou número.');
          Question:='Criar uma cópia de '+Grid.Selected.Caption+' como '+NewName+' no host '+Hosts[I].Title+'?'+LineEnding+
            'Os discos serão copiados no armazenamento do servidor. Isso pode demorar e exigir espaço livre.'+LineEnding+
            'A nova VM terá UUID e MAC próprios, mas dados internos como IP fixo, hostname e senhas serão copiados.';
          if MessageDlg('Confirmar clonagem',Question,mtWarning,[mbYes,mbNo],0)=mrYes then begin
            ValidateHost(Hosts[I]);
            CloneJob:=TCloneJob.Create(Hosts[I],U,NewName);
            SetBusy(True); Status.Caption:='Clonando '+Grid.Selected.Caption+' para '+NewName+'... Aguarde; a cópia pode demorar.';
            CloneJob.Start;
          end;
          Exit;
        end;
        if ButtonTag=8 then begin Console; Exit; end;
        if ButtonTag=10 then begin
          U:=Grid.Selected.SubItems[1];
          if ShowVMConfiguration(Self,Hosts[I],U,Grid.Selected.Caption) then BeginJob(vaList,'');
          Exit;
        end;
        U := Grid.Selected.SubItems[1]; A := TVMAction(ButtonTag-3);
        Question := TBitBtn(Sender).Caption+' a VM '+Grid.Selected.Caption+'?'+LineEnding+
          'Host: '+Hosts[I].Title+' ('+Hosts[I].Address+')'+LineEnding+'UUID: '+U;
        if A=vaDestroy then Question:=Question+LineEnding+LineEnding+string('ATENÇÃO: equivale a cortar a energia. Dados não gravados serão perdidos.');
        if MessageDlg('Confirmar operação',Question,mtWarning,[mbYes,mbNo],0)=mrYes then BeginJob(A,U);
      end;
    end;
  except on E: Exception do ShowMessage(E.Message); end;
end;
end.
