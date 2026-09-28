# VM Manager 0.3.6

Aplicativo nativo Windows x64, em Free Pascal/Lazarus, para servidores Linux KVM/QEMU/libvirt via SSH. Gerencia VMs por `virsh --connect qemu:///system` e abre console VNC/SPICE com `remote-viewer` e túnel OpenSSH. Não usa Proxmox.

O instalador pronto para Windows está na seção **Releases** deste repositório. Os fontes não contêm cadastro de hosts, senhas nem chaves SSH; esses dados ficam no perfil do usuário Windows.

## Início rápido

1. Instale o pacote da seção **Releases** e abra **VM Manager** pelo menu Iniciar. Se compilou os fontes, abra `bin\VMManager-0.3.6.exe`. Feche uma versão anterior do aplicativo antes de iniciar esta.
2. Clique em **Novo host** e informe nome, endereço DNS/IPv4, usuário SSH e porta. O caminho da chave pode ficar em branco. O console detecta automaticamente o `virt-viewer` instalado pelo pacote; informe um caminho no cadastro somente se ele foi instalado em uma pasta personalizada.
3. Selecione o host e clique em **Configurações de acesso SSH**.
4. Clique em **Verificar identidade do servidor**. No primeiro acesso, compare a impressão digital exibida com a informação obtida pelo console ou administrador do servidor e marque a confirmação. Se a identidade já estiver em `known_hosts`, o aplicativo a reconhece. Uma divergência bloqueia a operação.
5. Clique em **Gerar / recriar e autorizar**. O aplicativo cria uma chave exclusiva, instala sua parte pública em `authorized_keys` no Linux e testa o acesso ao libvirt. Se o acesso atual não autenticar, uma janela solicita a senha SSH do usuário escolhido. Não é preciso copiar comandos para o PowerShell.
6. Volte à tela principal e clique em **Atualizar**.

O usuário SSH precisa ter permissão para usar `qemu:///system` sem sudo ou prompt de polkit. Se o servidor não aceitar autenticação por senha e não houver outra chave válida, o acesso inicial precisa ser configurado pelo administrador do Linux.

Ao abrir, o aplicativo mostra uma imagem de apresentação por aproximadamente um segundo. O ícone próprio aparece no executável, nos atalhos e no instalador. Os arquivos de arte estão em `assets`.

## Gerar, recriar e excluir chaves

**Recriar:** gera outra chave, autoriza e testa o acesso com ela, salva o novo cadastro e só então revoga e exclui a chave anterior *criada pelo assistente*. Uma chave cadastrada manualmente é preservada, inclusive no servidor, pois pode ser usada por outro programa.

**Revogar e excluir chave:** depois de confirmação, remove do `authorized_keys` a identidade pública exata da chave gerenciada e exclui os arquivos privado e público locais. Outras chaves, comentários e opções de `authorized_keys` são preservados. A opção só fica disponível para uma chave criada pelo assistente. Depois da revogação, será preciso senha SSH ou outro acesso válido para criar uma nova chave. Excluir o *cadastro do host* remove somente o registro local e avisa para revogar a chave antes, se essa for a intenção.

As chaves gerenciadas ficam em `%LOCALAPPDATA%\VMManager\keys\<identificador>\id_ed25519`. Cada pasta é criada com acesso restrito ao usuário Windows antes da geração. As chaves são Ed25519 sem frase secreta para uso direto pelo aplicativo. Proteja a sessão do Windows e os backups dessa pasta. Os hosts ficam em `%APPDATA%\VMManager\hosts.ini`; esse arquivo contém endereço, usuário, porta e caminhos, mas não contém senha nem o conteúdo das chaves.

A janela da senha surge apenas quando o SSH solicita autenticação por senha. A senha não é colocada em argumentos de processo, arquivos de configuração ou registros do programa. O campo é mascarado e a janela fecha por inatividade após dois minutos. Cancelar interrompe aquela tentativa. **Não digite a senha do Linux neste chat.**

Se ocorrer falha ou timeout durante a instalação, a chave recém-criada é preservada: o servidor pode já tê-la recebido. O erro informa o caminho local para recuperação. Ela só se torna o acesso ativo depois de passar no teste com libvirt.

O assistente lê a identidade SSH do servidor, fixa a chave confirmada para a conexão de autorização e não envia senha se a identidade divergir. A chave pública é validada antes de compor o comando remoto. As alterações em `authorized_keys` usam uma trava no diretório `.ssh` para operações deste assistente.

## Funções de VM

- Cadastrar, editar e excluir vários servidores Linux.
- Listar VMs ativas e inativas com nome, estado e UUID.
- Iniciar (`virsh start`), pedir desligamento (`shutdown`), pedir reinício (`reboot`) e forçar parada (`destroy`), sempre com confirmação que mostra host e UUID.
- Atualizar manualmente e consultar novamente depois de uma ação aceita.
- Abrir console gráfico externo de VMs ligadas com VNC/SPICE por túnel SSH local.
- Dar duplo clique numa VM para abrir o console. O clique só age quando acontece sobre uma linha da lista.
- Abrir **Configurar VM** para consultar CPUs, RAM, discos, interfaces de rede e ordem de inicialização, configurar o início automático com o host e, com a VM desligada, alterar CPUs e RAM para a próxima inicialização.
- Clonar uma VM desligada para uma nova VM no mesmo servidor, copiando seus discos com `virt-clone`.

Para clonar, selecione a VM desligada, clique em **Clonar**, informe o novo nome e confirme. O servidor precisa ter `virt-clone` (pacote `virt-install`) e espaço suficiente para os discos copiados. O aplicativo confere o estado novamente no servidor antes de começar e atualiza a lista ao terminar. A cópia recebe UUID e endereços MAC novos; configurações dentro do sistema convidado, como IP estático, hostname e senhas, continuam iguais. Confira isso antes de iniciar as duas VMs na mesma rede. Uma cópia grande pode demorar; se houver interrupção ou falha, examine a VM e os arquivos de armazenamento no servidor antes de repetir.

A janela separa os controles de **Servidores** e **Máquinas virtuais** em duas faixas com cores e títulos próprios. Os botões têm ícones para facilitar a identificação. O botão Console continua disponível para quem preferir um clique simples após selecionar a VM.

## Configuração da VM

Selecione uma VM e clique em **Configurar VM**. A janela lê a definição persistente do libvirt via SSH e mostra os recursos registrados. Discos, rede e ordem de inicialização são apresentados para consulta. Marque ou desmarque **Iniciar automaticamente quando o servidor ligar** para ativar ou desativar a inicialização da VM quando o host Linux/libvirt iniciar. Essa opção pode ser alterada mesmo com a VM ligada. Para editar CPU e RAM, desligue a VM, informe os novos números e confirme **Salvar alterações**. As alterações de recursos usam `virsh` com `--config` e só passam a valer no próximo início da VM.

Antes de salvar, o aplicativo confere novamente o estado e a definição da VM. Se outra ferramenta a alterou, o salvamento é recusado até recarregar. O libvirt pode recusar valores incompatíveis com a topologia de CPU ou outros detalhes da VM. Como CPU e RAM são comandos separados, uma falha após a primeira etapa pode deixar parte da configuração alterada: a janela informa isso e exige recarregar antes de outra tentativa. Nenhum comando de configuração é enviado sem confirmação.

Desligar e reiniciar solicitam uma ação ao sistema convidado; a conclusão pode demorar. Forçar parada equivale a cortar a energia e pode perder dados não gravados. `destroy` não exclui definição ou discos. As ações de energia usam apenas UUIDs validados. A clonagem resolve o nome da origem a partir do UUID e protege os nomes usados no comando remoto.

As operações SSH usam o OpenSSH do Windows sem shell local intermediário. O gerenciador exige verificação da chave do servidor, não encaminha o agente e usa autenticação não interativa depois da configuração. Após timeout ou falha, confira o estado da VM antes de repetir uma ação, pois o servidor pode já tê-la recebido.

## Console

O instalador em `dist\VMManager-Setup-0.3.6-x64.exe` já inclui e instala o MSI oficial do [virt-viewer para Windows x64](https://virt-manager.org/download). O aplicativo detecta o `virt-viewer.exe` e inicia `remote-viewer.exe` da mesma pasta sem exigir que o usuário preencha o caminho no cadastro. Para instalações personalizadas, ainda é possível informar o caminho manualmente. O pacote oficial Windows testado rejeita `qemu+ssh` no libvirt; por isso o aplicativo consulta o display via SSH, abre túnel para `127.0.0.1` e inicia remote-viewer. As portas gráficas não precisam ficar expostas à rede. Fechar o visualizador encerra o túnel.

São aceitos VNC/SPICE TCP anunciados pelo libvirt em loopback IPv4. Unix socket, TLS direto e IPv6 não estão implementados. Uma senha própria do VNC/SPICE, se configurada na VM, pode ser solicitada pelo visualizador. O console VNC foi testado no servidor desta conversa e o usuário confirmou que a tela apareceu.

## Dependências e compilação

Para executar manualmente: Windows 10/11 x64 com Cliente OpenSSH do Windows (`%WINDIR%\System32\OpenSSH\ssh.exe`); para console, virt-viewer com `remote-viewer.exe`. O instalador solicita autorização para ativar o Cliente OpenSSH por meio do Windows Update se o recurso ainda não estiver instalado. Nesse caso, é necessária conexão com a internet e uma conta administradora. Mantenha `VMManager-0.3.6.exe`, `ConsoleBridge.exe`, `SSHAskPass.exe` e `splash.png` juntos na pasta `bin`. O computador de destino não precisa ter Lazarus.

Para compilar: Lazarus 3.4 / Free Pascal 3.2.2 para Windows x64. Abra `VMManager.lpi` e compile; compile também `SSHAskPass.lpi` e `ConsoleBridge.lpr`, ou execute no PowerShell:

```powershell
.\build.ps1 -LazarusDir C:\lazarus
```

O script compila os três executáveis e executa os testes locais. Use `-UITests` para testar também a janela de senha com valor fictício. Fontes em `src`; janelas construídas em código, sem formulários `.lfm`. `TEST-RESULTS.md` registra a validação local e o teste de criação, recriação e revogação contra o servidor real com um cadastro separado.

Para reconstruir o pacote de instalação, instale o Inno Setup 6 e siga `installer\README.md`. O setup final distribui o MSI oficial do virt-viewer e o código-fonte correspondente; não inclui nem modifica servidor Linux algum.

## Limites desta versão

Não cria nem exclui VMs, discos, redes ou snapshots. Discos, interfaces de rede e ordem de boot ainda não são editáveis pela interface. O gerenciamento por senha é usado **somente no assistente de autorização da chave** e depende de o servidor aceitar autenticação SSH por senha para o usuário escolhido. A digitação de uma senha real no assistente ainda precisa ser confirmada em uma instalação nova; os testes automatizados da janela usam apenas valor fictício. Nenhuma VM real recebeu comandos de energia ou alteração de CPU/RAM durante o desenvolvimento desta versão.

Referências: [virsh](https://www.libvirt.org/manpages/virsh.html), [OpenSSH](https://man.openbsd.org/ssh), [virt-viewer](https://virt-manager.org/download).
