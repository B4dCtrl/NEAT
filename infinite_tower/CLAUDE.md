# Stairborn — notas para o Claude

- Entregas de build: gerar **só a versão Windows** (`export/windows/Stairborn.exe`,
  preset "Windows Desktop", zipada) para o usuário testar. Não gerar Linux
  a menos que ele peça.
- Usar o Godot 4.3 (o `godot` do sistema é 4.2 e não serve).
- Testes: `godot --headless --path . -s res://tests/run_tests.gd`.
