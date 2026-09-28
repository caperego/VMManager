param([string]$LazarusDir = 'C:\lazarus', [switch]$UITests)
$ErrorActionPreference = 'Stop'
$compiler = Get-ChildItem (Join-Path $LazarusDir 'fpc') -Recurse -Filter fpc.exe |
    Where-Object FullName -Match 'x86_64-win64' | Select-Object -First 1
if (-not $compiler) { throw 'Free Pascal Win64 não encontrado na instalação Lazarus.' }
$env:PATH = $compiler.DirectoryName + ';' + $env:PATH
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force bin,lib,lib\tests | Out-Null
    & (Join-Path $compiler.DirectoryName 'windres.exe') -i VMManager.rc -o VMManager.res -O res
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar o recurso de ícone do VM Manager.' }
    Copy-Item assets\splash.png bin\splash.png -Force
    Copy-Item assets\VMManager.ico bin\VMManager.ico -Force
    & (Join-Path $LazarusDir 'lazbuild.exe') --build-all VMManager.lpi
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar VMManager.' }
    & (Join-Path $LazarusDir 'lazbuild.exe') --build-all tests\icon_smoke.lpi
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o teste do ícone.' }
    & .\bin\icon_smoke.exe
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao carregar o ícone no Lazarus.' }
    & (Join-Path $LazarusDir 'lazbuild.exe') --build-all SSHAskPass.lpi
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar SSHAskPass.' }
    & $compiler.FullName -B -Mobjfpc -Sh -WC -Fusrc -FUlib\tests -FEbin ConsoleBridge.lpr
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar ConsoleBridge.' }
    & $compiler.FullName -B -Mobjfpc -Sh -Fusrc -FUlib\tests -FEbin tests\core_tests.lpr
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar os testes.' }
    & .\bin\core_tests.exe
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes.' }
    & $compiler.FullName -B -Mobjfpc -Sh -Fusrc -FUlib\tests -FEbin tests\access_tests.lpr
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar testes de acesso.' }
    & .\bin\access_tests.exe
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de acesso.' }
    & $compiler.FullName -B -Mobjfpc -Sh -Fusrc -FUlib\tests -FEbin tests\config_tests.lpr
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar testes de configuração de VM.' }
    & .\bin\config_tests.exe
    if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes de configuração de VM.' }
    if ($UITests) {
        & (Join-Path $LazarusDir 'lazbuild.exe') --build-all tests\password_ui_tests.lpi
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar testes da janela de senha.' }
        & .\bin\password_ui_tests.exe
        if ($LASTEXITCODE -ne 0) { throw 'Falha nos testes da janela de senha.' }
    }
} finally { Pop-Location }
