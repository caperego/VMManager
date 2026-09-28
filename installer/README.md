# Pacote de instalação do VM Manager

`VMManager.iss` gera um instalador x64 para Windows 10 (1809 ou posterior) e Windows 11. Ele instala o aplicativo e os dois auxiliares, instala o MSI oficial do `virt-viewer` 11.0 e inclui o texto GPL e o arquivo de código-fonte correspondente.

O MSI e o arquivo de código-fonte do `virt-viewer` são obtidos da [página oficial da versão 11.0](https://gitlab.com/virt-viewer/virt-viewer/-/releases/v11.0). O repositório inclui o código-fonte, as assinaturas e o texto da licença; o MSI de 84 MiB não é guardado no histórico Git. Para reconstruir o instalador a partir de um clone do repositório, baixe `virt-viewer-x64-11.0-1.0.msi` da página oficial e salve-o em `installer\vendor\` com esse nome exato. Antes da compilação, importe a chave anunciada em <https://virt-manager.org/download>, confira se a impressão digital é `DAF3 A6FD B26B 6291 2D0E 8E3F BE86 EBB4 1510 4FDF`, e verifique as assinaturas dos arquivos:

```powershell
gpg --keyserver hkps://keys.openpgp.org --recv-key BE86EBB415104FDF
gpg --fingerprint BE86EBB415104FDF
gpg --verify .\installer\vendor\virt-viewer-x64-11.0-1.0.msi.asc .\installer\vendor\virt-viewer-x64-11.0-1.0.msi
gpg --verify .\installer\vendor\virt-viewer-11.0.tar.xz.asc .\installer\vendor\virt-viewer-11.0.tar.xz
```

É necessário ter o Lazarus/Free Pascal usado para compilar o aplicativo e o Inno Setup 6. A partir da pasta do projeto:

```powershell
.\build.ps1 -LazarusDir C:\lazarus
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" .\installer\VMManager.iss
```

O instalador final é criado em `dist\VMManager-Setup-0.3.6-x64.exe`. Ele contém o MSI de 80 MiB, os executáveis, o ícone e a imagem de abertura do VM Manager. A conexão SSH usa o recurso opcional Cliente OpenSSH do Windows. Se o recurso estiver ausente, o instalador solicita autorização e o ativa por meio do Windows Update. Por isso, essa etapa requer internet e privilégios de administrador.

O `virt-viewer` é instalado como aplicativo separado pelo seu MSI oficial e pode ser removido em Aplicativos instalados. A configuração dos servidores e as chaves SSH ficam no perfil do usuário e são preservadas ao desinstalar o VM Manager.

Para usar o botão **Clonar**, o servidor Linux deve ter `virt-clone` instalado (geralmente fornecido pelo pacote `virt-install`). Essa dependência pertence ao servidor e não é instalada pelo pacote Windows.

O ícone é recriado com `assets\generate_icon.py` se necessário (requer Pillow). O projeto já inclui `assets\VMManager.ico` e `VMManager.res`; a recompilação normal usa `windres.exe` fornecido pelo Free Pascal. A imagem de abertura e o pedido usado para gerá-la estão em `assets`.
