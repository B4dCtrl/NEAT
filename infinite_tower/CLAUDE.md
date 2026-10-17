# Stairborn — notas para o Claude

- Entregas de build: gerar **só a versão Windows**, como **instalador**
  (`export/Stairborn-Setup.exe`) para o usuário testar. Não gerar Linux
  a menos que ele peça.
  1. `godot --headless --path . --import`
  2. `godot --headless --path . --export-release "Windows Desktop" export/windows/Stairborn.exe`
     (gera `Stairborn.exe` + `Stairborn.pck`; o ícone do .exe precisa do
     rcedit + wine configurados nas Editor Settings, em Export > Windows)
  3. `makensis -DVERSION=<versão> tools/installer/stairborn.nsi`
  4. Se houver certificado de assinatura real: `tools/installer/sign.sh game`
     antes do passo 3 e `tools/installer/sign.sh installer` depois
     (`SIGN_PFX`/`SIGN_PASS`). Sem assinatura, o Smart App Control do
     Windows 11 bloqueia o instalador e não há botão para liberar: certificado
     autoassinado NÃO resolve. Avisar o usuário disso ao entregar.
  Ícone e imagens do instalador: `tools/make_icon.gd` + `tools/installer/make_ico.py`.
  Avisos de licença: `tools/make_notices.gd`.
- Antes de entregar: testar o instalador e o jogo no Wine (instalar, abrir,
  passar pelo login e pelo mangá) e conferir as telas.
- Usar o Godot 4.3 (o `godot` do sistema é 4.2 e não serve).
- Testes: `godot --headless --path . -s res://tests/run_tests.gd`.
- Textos: `tests/ui_text_dump.gd` + `tools/i18n/find_english.py` acham texto
  que ficou em inglês no pt/es.
