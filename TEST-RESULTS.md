# VM Manager 0.3.0 — resultados da validação

Executado no Windows x64 com Lazarus 3.4, Free Pascal 3.2.2 e OpenSSH do Windows.

| Verificação | Resultado |
|---|---|
| Compilar VMManager, ConsoleBridge e SSHAskPass | Passou |
| Testes locais de processos, validação e console | 31 passaram |
| Testes locais de chaves e `authorized_keys` em diretório isolado | 18 passaram |
| Testes locais de leitura da definição e de comandos de configuração | 11 passaram |
| Leitura real da definição persistente via SSH/libvirt | Passou nas 8 VMs cadastradas; CPU e RAM foram interpretadas sem erro |
| Testes da janela de senha com valor fictício e timeout | Passaram |
| Autenticação e listagem real via SSH/libvirt | Passou: 8 VMs, 4 ligadas e 4 desligadas |
| Console VNC real | Túnel e banner VNC passaram; usuário confirmou a imagem |
| Inspeção de identidade SSH real | Passou: reconheceu chave já confiável e mostrou SHA256 |
| Criação, recriação e revogação real de chave com cadastro separado | Passou; chave original do usuário preservada |
| Acesso original após os testes do ciclo da chave | Passou |
| Nova janela com faixas e ícones | Compilou e abriu no Windows; disposição das duas faixas conferida em captura local |

O duplo clique foi conectado à linha sob o ponteiro e inicia o mesmo fluxo seguro do botão Console. Esta interação específica ainda não foi clicada manualmente; o acesso ao console pelo botão foi validado anteriormente no servidor do usuário.

A janela **Configurar VM** compila; a leitura de XML foi exercitada com uma definição sintética e com as 8 VMs reais do servidor. O salvamento de CPU/RAM foi validado apenas quanto à construção segura dos comandos e à compilação. Não alterei a definição de uma VM real para testar a gravação, pois isso mudaria recursos do servidor do usuário.

O teste de ciclo de chave criou uma identidade temporária no servidor, confirmou acesso ao libvirt, recriou a identidade e revogou a temporária. Não enviou comandos de iniciar, desligar, reiniciar ou forçar parada a nenhuma VM.

O fluxo com **senha real** ainda não foi exercitado, porque o servidor já aceita a chave atual e não foi necessário pedir a senha do usuário. A janela foi testada com entrada fictícia; o programa recusa solicitações inesperadas que não sejam um prompt de senha. Para validar a autenticação inicial por senha, use um host de teste que a permita e confira manualmente a impressão digital antes de avançar.

O projeto contém fontes, binários e script de compilação para reproduzir os testes. `build-0.3.0.log` guarda a saída da compilação e dos testes locais desta versão.

## Pacote de instalação Windows 0.3.3

| Verificação | Resultado |
|---|---|
| Compilação dos aplicativos depois da detecção automática de virt-viewer | Passou |
| Testes locais de processos, validação e console | 32 passaram, incluindo detecção do diretório instalado pelo MSI |
| Assinatura GPG do MSI oficial do virt-viewer 11.0 | Boa assinatura; impressão digital conferida com a página oficial |
| Assinatura GPG do código-fonte correspondente do virt-viewer 11.0 | Boa assinatura; impressão digital conferida com a página oficial |
| Compilação do instalador Inno Setup x64 | Passou; `dist\VMManager-Setup-0.3.3-x64.exe`, 88.610.313 bytes |

O instalador não foi executado nesta máquina, para evitar instalar ou alterar componentes do computador durante a geração do pacote. A execução em uma instalação limpa de Windows continua sendo a validação final recomendada antes de distribuir o arquivo a terceiros. Se o Cliente OpenSSH estiver ausente, o setup solicita confirmação antes de pedir ao DISM que o habilite via Windows Update.

## Identidade visual e novo pacote 0.3.4

| Verificação | Resultado |
|---|---|
| Ícone Windows | Gerado em 7 tamanhos, de 16 a 256 px; o ícone extraído do aplicativo e do instalador é idêntico |
| Imagem de abertura | `assets\splash.png` incluído na pasta de execução e no instalador; formato PNG validado |
| Compilação do aplicativo e auxiliares | Passou com `SplashForm` e recurso `VMManager.res` |
| Testes locais | 32 testes gerais, 18 de acesso e 11 de configuração passaram |
| Compilação do instalador | Passou; `dist\VMManager-Setup-0.3.4-x64.exe`, 89.967.620 bytes |

O pacote 0.3.4 não foi instalado em um Windows limpo nesta sessão; a abertura visual e o fluxo do instalador ainda precisam ser conferidos em um computador de destino antes de distribuição ampla.

## Correção do ícone e novo pacote 0.3.5

O ícone da versão 0.3.4 continha imagens PNG dentro do arquivo ICO. Na inicialização, o carregador de imagens do Lazarus mostrou o erro `Bitmap with unknown compression (268435456)`. O pacote 0.3.4 foi retirado da pasta `dist` para evitar seu uso acidental. A versão 0.3.5 usa imagens BMP/DIB sem compressão dentro do ICO.

| Verificação | Resultado |
|---|---|
| Formato do ICO | As 7 imagens têm cabeçalho BITMAPINFOHEADER e compressão 0 |
| Carregamento pelo Lazarus | Passou para o arquivo ICO e para o recurso MAINICON embutido no executável |
| Compilação e testes locais | Passou: 32 testes gerais, 18 de acesso e 11 de configuração |
| Compilação do instalador | Passou: `dist\VMManager-Setup-0.3.5-x64.exe`, 90.270.022 bytes |
| SHA-256 do instalador | `816A656F281A620E1703F613E9D0B00E32922D14A9DC1F3862B1E482C0F4CED9` |

Os ícones extraídos do executável e do instalador foram comparados e são idênticos. O registro detalhado da compilação está em `build-0.3.5.log`. A instalação e a abertura visual em um Windows limpo ainda não foram testadas interativamente.

## Clonagem 0.3.6

A tela principal ganhou o botão **Clonar**. A operação exige uma VM desligada, pede um novo nome, confirma host e implicações da cópia e executa `virt-clone` no servidor Linux pela mesma conexão SSH autenticada. O estado é conferido novamente no servidor antes da cópia. O aplicativo recarrega a lista quando o comando termina.

A compilação do aplicativo passou. Os testes locais passaram: 37 gerais (incluindo validação e proteção dos nomes de clonagem), 18 de acesso e 11 de configuração. O carregamento do ícone também passou. Saída completa em `build-0.3.6.log`.

O instalador `dist\VMManager-Setup-0.3.6-x64.exe` compilou com sucesso (90.272.341 bytes). SHA-256: `9B28DBA7F8D5D343BCAF4A03F6274A140BCA5931186432160E3D2B121BBF7C00`.

**Limite da validação:** nenhuma VM real foi clonada no servidor do usuário, pois isso consumiria armazenamento e criaria uma nova máquina. A execução remota do `virt-clone` e a disponibilidade do pacote no servidor ainda precisam ser verificadas numa clonagem escolhida pelo usuário.
