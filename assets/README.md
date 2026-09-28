# Identidade visual

`VMManager.ico` contém tamanhos de 16, 24, 32, 48, 64, 128 e 256 px, com quadros BMP/DIB compatíveis com o Lazarus. O ícone é desenhado por `generate_icon.py` (Pillow) e incorporado ao executável via `VMManager.rc` e `windres.exe` durante `build.ps1`. `icon-preview.png` serve para conferir a aparência. Para compilar o projeto não é necessário Python: os arquivos `.ico` e `.res` já estão incluídos.

`splash.png` é a imagem exibida durante a abertura do aplicativo. Ela foi gerada com o recurso integrado de geração de imagens, com este pedido:

> Use case: logo-brand. Asset type: Windows desktop application splash screen background for VM Manager, a native KVM/QEMU/libvirt virtual machine manager. Create a polished wide horizontal 16:9 illustration with a deep navy to indigo gradient, one luminous geometric outline of a computer monitor containing three small stacked virtual machine cubes, subtle cyan and violet network lines, restrained professional system-administration aesthetic. Keep the left half calm and dark with generous empty space so the application can overlay its own title and startup text. No lettering, no logos, no words, no watermark, no UI mockup or buttons. Clean high contrast, refined edges, suitable for display at 720x405 pixels.

O título e a indicação de inicialização são desenhados pelo aplicativo sobre a imagem. O instalador copia `splash.png` para a mesma pasta de `VMManager.exe`.
