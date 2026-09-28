unit VMConfigCore;
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils;
type
  TVMConfiguration = record
    UUID, Name, State: string;
    CPUCount, CPUMax: Integer;
    MemoryKiB, MaxMemoryKiB: QWord;
    AutoStart: Boolean;
    Disks, Networks, Boot: string;
  end;
function ParseVMConfiguration(const XML, State, ExpectedUUID: string): TVMConfiguration;
function BuildConfigCommand(const Operation, UUID: string; Value: QWord = 0): string;
procedure ValidateResources(CPUCount: Integer; MemoryMiB: QWord);
procedure ValidateCPUCount(CPUCount: Integer);
procedure ValidateMemoryMiB(MemoryMiB: QWord);
function ParseAutoStartInfo(const Info: string): Boolean;
implementation
uses DOM, XMLRead, VMCore;

function Child(Node: TDOMNode; const Name: string): TDOMNode;
begin
  Result:=nil;
  if Node=nil then Exit;
  Node:=Node.FirstChild;
  while Node<>nil do begin
    if Node.NodeName=Name then Exit(Node);
    Node:=Node.NextSibling;
  end;
end;

function Attr(Node: TDOMNode; const Name: string): string;
begin
  Result:='';
  if Node is TDOMElement then Result:=UTF8Encode(TDOMElement(Node).GetAttribute(Name));
end;

function Body(Node: TDOMNode): string;
begin
  Result:='';
  if Node<>nil then Result:=Trim(UTF8Encode(Node.TextContent));
end;

function MemoryKiB(Node: TDOMNode): QWord;
var N,Factor: QWord; UnitName,Value: string;
begin
  if Node=nil then raise Exception.Create('Definição da VM não informa a memória.');
  Value:=Body(Node);
  if (Value='') or not TryStrToQWord(Value,N) or (N=0) then
    raise Exception.Create('Memória inválida na definição da VM.');
  UnitName:=LowerCase(Attr(Node,'unit'));
  if (UnitName='') or (UnitName='k') or (UnitName='kib') then Factor:=1
  else if (UnitName='m') or (UnitName='mib') then Factor:=1024
  else if (UnitName='g') or (UnitName='gib') then Factor:=1024*1024
  else if (UnitName='t') or (UnitName='tib') then Factor:=QWord(1024)*1024*1024
  else if (UnitName='b') or (UnitName='bytes') then begin Result:=(N+1023) div 1024; Exit; end
  else raise Exception.Create('Unidade de memória não suportada: '+UnitName);
  if N>High(QWord) div Factor then raise Exception.Create('Memória da VM excede o limite numérico.');
  Result:=N*Factor;
end;

function ParseVMConfiguration(const XML, State, ExpectedUUID: string): TVMConfiguration;
var D: TXMLDocument; Stream: TStringStream; Root,VCPU,Devices,Node,Sub,Source,Target: TDOMNode;
  S,Kind,LineText: string;
begin
  Result:=Default(TVMConfiguration);
  if not ValidUUID(ExpectedUUID) then raise Exception.Create('UUID inválido.');
  if (Length(XML)=0) or (Length(XML)>4*1024*1024) then raise Exception.Create('XML da VM vazio ou excessivo.');
  Stream:=TStringStream.Create(XML);
  D:=nil;
  try
    ReadXMLFile(D,Stream);
    Root:=D.DocumentElement;
    if (Root=nil) or (Root.NodeName<>'domain') then raise Exception.Create('Resposta não é uma definição de VM libvirt.');
    Result.UUID:=Body(Child(Root,'uuid'));
    if not SameText(Result.UUID,ExpectedUUID) then raise Exception.Create('UUID da definição diverge da VM selecionada.');
    Result.Name:=Body(Child(Root,'name'));
    Result.State:=Trim(State);
    VCPU:=Child(Root,'vcpu');
    if VCPU=nil then raise Exception.Create('Definição da VM não informa CPUs.');
    S:=Body(VCPU);
    if not TryStrToInt(S,Result.CPUMax) or (Result.CPUMax<1) then raise Exception.Create('Número máximo de CPUs inválido.');
    S:=Attr(VCPU,'current');
    if S='' then Result.CPUCount:=Result.CPUMax
    else if not TryStrToInt(S,Result.CPUCount) then raise Exception.Create('Número de CPUs inválido.');
    if (Result.CPUCount<1) or (Result.CPUCount>Result.CPUMax) then raise Exception.Create('Número de CPUs fora do limite.');
    Result.MaxMemoryKiB:=MemoryKiB(Child(Root,'memory'));
    Node:=Child(Root,'currentMemory');
    if Node=nil then Result.MemoryKiB:=Result.MaxMemoryKiB else Result.MemoryKiB:=MemoryKiB(Node);
    if Result.MemoryKiB>Result.MaxMemoryKiB then raise Exception.Create('Memória atual maior que o limite da VM.');
    Devices:=Child(Root,'devices');
    if Devices<>nil then begin
      Node:=Devices.FirstChild;
      while Node<>nil do begin
        if Node.NodeName='disk' then begin
          Source:=Child(Node,'source'); Target:=Child(Node,'target');
          Kind:=Attr(Node,'device');
          LineText:=Attr(Target,'dev');
          if LineText='' then LineText:='(sem destino)';
          S:=Attr(Source,'file'); if S='' then S:=Attr(Source,'dev');
          if S='' then S:=Attr(Source,'name');
          if S='' then S:='(sem origem)';
          Result.Disks:=Result.Disks+LineText+' ['+Kind+']  '+S+LineEnding;
        end else if Node.NodeName='interface' then begin
          Source:=Child(Node,'source'); Sub:=Child(Node,'mac'); Target:=Child(Node,'model');
          S:=Attr(Source,'network'); if S='' then S:=Attr(Source,'bridge');
          if S='' then S:=Attr(Source,'dev');
          if S='' then S:='(sem origem)';
          LineText:=Attr(Sub,'address');
          if LineText<>'' then LineText:=LineText+'  ';
          Result.Networks:=Result.Networks+LineText+S+' ['+Attr(Node,'type')+']';
          Kind:=Attr(Target,'type'); if Kind<>'' then Result.Networks:=Result.Networks+'  '+Kind;
          Result.Networks:=Result.Networks+LineEnding;
        end;
        Node:=Node.NextSibling;
      end;
    end;
    Node:=Child(Child(Root,'os'),'boot');
    while Node<>nil do begin
      if Node.NodeName='boot' then begin
        S:=Attr(Node,'dev'); if S<>'' then Result.Boot:=Result.Boot+S+' ';
      end;
      Node:=Node.NextSibling;
    end;
    Result.Boot:=Trim(Result.Boot);
    if Result.Disks='' then Result.Disks:='Nenhum disco listado.';
    if Result.Networks='' then Result.Networks:='Nenhuma interface listada.';
    if Result.Boot='' then Result.Boot:='Ordem padrão / definida nos dispositivos';
  finally D.Free; Stream.Free; end;
end;

procedure ValidateResources(CPUCount: Integer; MemoryMiB: QWord);
begin
  ValidateCPUCount(CPUCount); ValidateMemoryMiB(MemoryMiB);
end;

procedure ValidateCPUCount(CPUCount: Integer);
begin
  if (CPUCount<1) or (CPUCount>256) then raise Exception.Create('Informe entre 1 e 256 CPUs.');
end;

procedure ValidateMemoryMiB(MemoryMiB: QWord);
begin
  if (MemoryMiB<128) or (MemoryMiB>1048576) then raise Exception.Create('Informe entre 128 e 1048576 MiB de RAM.');
end;

function ParseAutoStartInfo(const Info: string): Boolean;
var Lines: TStringList; I,P: Integer; LineText,Value: string; Found: Boolean;
begin
  Lines:=TStringList.Create;
  try
    Lines.Text:=Info; Found:=False; Result:=False;
    for I:=0 to Lines.Count-1 do begin
      LineText:=Trim(Lines[I]); P:=Pos(':',LineText);
      if (P>0) and SameText(Trim(Copy(LineText,1,P-1)),'Autostart') then begin
        Value:=LowerCase(Trim(Copy(LineText,P+1,MaxInt)));
        if (Value='enable') or (Value='enabled') then begin Result:=True; Found:=True; Break; end;
        if (Value='disable') or (Value='disabled') then begin Result:=False; Found:=True; Break; end;
        raise Exception.Create('Estado de início automático inválido: '+Value);
      end;
    end;
    if not Found then raise Exception.Create('virsh dominfo não retornou o estado de início automático.');
  finally Lines.Free; end;
end;

function BuildConfigCommand(const Operation, UUID: string; Value: QWord): string;
begin
  if not ValidUUID(UUID) then raise Exception.Create('UUID inválido; comando bloqueado.');
  Result:='LC_ALL=C virsh --connect qemu:///system ';
  if Operation='state' then Result:=Result+'domstate '+UUID
  else if Operation='read' then Result:=Result+'dumpxml --inactive '+UUID
  else if Operation='info' then Result:=Result+'dominfo '+UUID
  else if Operation='autostart_on' then Result:=Result+'autostart '+UUID
  else if Operation='autostart_off' then Result:=Result+'autostart --disable '+UUID
  else begin
    if (Value=0) or (Value>1073741824) then raise Exception.Create('Valor de configuração inválido.');
    if Operation='cpu' then Result:=Result+'setvcpus '+UUID+' '+IntToStr(Value)+' --config'
    else if Operation='cpu_max' then Result:=Result+'setvcpus '+UUID+' '+IntToStr(Value)+' --maximum --config'
    else if Operation='memory' then Result:=Result+'setmem '+UUID+' '+IntToStr(Value)+'KiB --config'
    else if Operation='memory_max' then Result:=Result+'setmaxmem '+UUID+' '+IntToStr(Value)+'KiB --config'
    else raise Exception.Create('Operação de configuração inválida.');
  end;
end;
end.
