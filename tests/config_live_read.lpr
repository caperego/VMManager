program ConfigLiveRead;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils, VMCore, VMConfigJob;
var Hosts: THosts; ListJob: TRemoteJob; ConfigJob: TConfigurationJob;
  ConfigPath: string; I: Integer;
begin
  ConfigPath:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA'))+'VMManager\hosts.ini';
  LoadHosts(ConfigPath,Hosts);
  if Length(Hosts)=0 then raise Exception.Create('Nenhum host cadastrado.');
  ValidateHost(Hosts[0]);
  ListJob:=TRemoteJob.Create(Hosts[0],vaList,'');
  try
    ListJob.Start; ListJob.WaitFor;
    if ListJob.ErrorText<>'' then raise Exception.Create(ListJob.ErrorText);
    if Length(ListJob.VMs)=0 then begin WriteLn('Servidor acessível; nenhuma VM para verificar.'); Halt(0); end;
    for I:=0 to High(ListJob.VMs) do begin
      ConfigJob:=TConfigurationJob.CreateRead(Hosts[0],ListJob.VMs[I].UUID);
      try
        ConfigJob.Start; ConfigJob.WaitFor;
        if ConfigJob.ErrorText<>'' then
          raise Exception.Create(ListJob.VMs[I].Name+': '+ConfigJob.ErrorText);
        WriteLn('Leitura OK: ',ConfigJob.Configuration.Name,
          '; CPUs: ',ConfigJob.Configuration.CPUCount,
          '; RAM MiB: ',ConfigJob.Configuration.MemoryKiB div 1024);
      finally ConfigJob.Free; end;
    end;
    WriteLn('Total de VMs verificadas: ',Length(ListJob.VMs));
  finally ListJob.Free; end;
end.
