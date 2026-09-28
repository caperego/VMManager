program ConfigTests;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils, VMConfigCore;
const
  UUID='12345678-1234-1234-1234-123456789abc';
  SampleXML='<?xml version="1.0"?>'+
    '<domain type="kvm"><name>lab-vm</name><uuid>'+UUID+'</uuid>'+
    '<memory unit="MiB">4096</memory><currentMemory unit="MiB">2048</currentMemory>'+
    '<vcpu placement="static" current="2">4</vcpu>'+
    '<os><type arch="x86_64">hvm</type><boot dev="hd"/><boot dev="cdrom"/></os>'+
    '<devices><disk type="file" device="disk"><source file="/var/lib/libvirt/images/lab.qcow2"/>'+
    '<target dev="vda" bus="virtio"/></disk>'+
    '<interface type="network"><mac address="52:54:00:12:34:56"/>'+
    '<source network="default"/><model type="virtio"/></interface></devices></domain>';
var C: TVMConfiguration; Count: Integer; Failed: Boolean;
procedure Check(Value: Boolean; const Name: string);
begin
  if not Value then raise Exception.Create('FAIL: '+Name);
  Inc(Count); WriteLn('PASS: '+Name);
end;
begin
  C:=ParseVMConfiguration(SampleXML,'shut off',UUID);
  Check((C.CPUCount=2) and (C.CPUMax=4),'CPU atual e limite do XML');
  Check((C.MemoryKiB=2048*1024) and (C.MaxMemoryKiB=4096*1024),'Memória atual e limite do XML');
  Check((Pos('vda',C.Disks)>0) and (Pos('lab.qcow2',C.Disks)>0),'Disco exibido');
  Check((Pos('default',C.Networks)>0) and (Pos('52:54:00:12:34:56',C.Networks)>0),'Rede exibida');
  Check(C.Boot='hd cdrom','Ordem de inicialização exibida');
  Failed:=False;
  try ParseVMConfiguration(SampleXML,'shut off','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  except on Exception do Failed:=True; end;
  Check(Failed,'XML de outra VM rejeitado');
  Failed:=False;
  try BuildConfigCommand('cpu',UUID+'; id',4); except on Exception do Failed:=True; end;
  Check(Failed,'Injeção no UUID bloqueada');
  Check(BuildConfigCommand('cpu',UUID,4)=
    'LC_ALL=C virsh --connect qemu:///system setvcpus '+UUID+' 4 --config',
    'CPU altera apenas configuração persistente');
  Check(BuildConfigCommand('memory',UUID,4194304)=
    'LC_ALL=C virsh --connect qemu:///system setmem '+UUID+' 4194304KiB --config',
    'RAM altera apenas configuração persistente');
  Failed:=False;
  try ValidateResources(0,2048); except on Exception do Failed:=True; end;
  Check(Failed,'CPU zero rejeitada');
  Failed:=False;
  try ValidateResources(2,1048577); except on Exception do Failed:=True; end;
  Check(Failed,'RAM acima do limite rejeitada');
  WriteLn('OK: ',Count,' config tests passed.');
end.
