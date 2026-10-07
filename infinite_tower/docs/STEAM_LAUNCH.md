# Stairborn: caminho até a Steam

Estado em 2026-10-07. Itens marcados com ✅ estão no código e testados (Linux/headless);
⚠️ não pude testar aqui (precisa de Windows ou de uma conta); 🔒 só o dono do jogo pode fazer.

## 1. Regras da Steam que moldam o jogo

| Regra | Consequência para o Stairborn |
| --- | --- |
| Reembolso: até **2 h de jogo** em até **14 dias**, sem perguntas ([fonte](https://gamingprofileviewer.com/steam/guides/steam-refund-policy)) | As 2 primeiras horas têm que mostrar o jogo inteiro: ✅ andares curtos no começo (6 s), 1ª Ascensão por volta de 1,5–2 h. |
| Taxa Steam Direct: **US$ 100** por jogo, devolvida como crédito ao chegar a US$ 1 000 de receita ([fonte](https://www.summerengine.com/blog/how-to-publish-game-on-steam)) | 🔒 Conta Steamworks + entrevista fiscal/bancária. |
| Página "Coming Soon" pública por **pelo menos 2 semanas** antes do lançamento ([fonte](https://partner.steamgames.com/doc/store/coming_soon)) | 🔒 Publicar a página cedo e juntar wishlists. |
| Jogos com blockchain que emitam/troquem cripto ou NFT são proibidos ([fonte](https://www.pcgamer.com/steam-bans-nfts-cryptocurrencies-blockchain/)) | ✅ Nada de token no jogo da Steam; só itens via Steam Inventory/Community Market. |

## 2. Imagens da loja (todas precisam do nome do jogo no desenho) ([fonte](https://www.steampageanalyzer.com/blog/how-to-publish-game-on-steam))

| Asset | Tamanho |
| --- | --- |
| Header capsule | 460 × 215 |
| Small capsule | 231 × 87 |
| Main capsule | 616 × 353 |
| Hero graphic | 3840 × 1240 |
| Library capsule | 600 × 900 |
| Fundo da página (opcional) | 1438 × 810 |

Também: ≥ 5 screenshots 1920 × 1080 (confirmar no Steamworks), trailer (opcional, mas converte),
ícone do app e descrição curta/longa. 🔒 Falta tudo isso: o gerador de imagens
(Maginific) está no plano gratuito, sem créditos; SpriteCook e CellCog foram sugeridos para ativação.

## 3. Código: pronto e pendente

| Item | Estado |
| --- | --- |
| Identidade: login da Steam substitui a tela de login (`Game.sign_in_steam`, `PlatformServices.steam_user`); fora da Steam, contas locais | ✅ testado com usuário falso; ⚠️ falta testar com o GodotSteam real |
| Save: por conta, criptografado, com `.bak`. Mesma conta Steam = mesma chave em qualquer PC | ✅ |
| Steam Cloud (Auto-Cloud): apontar o caminho `%APPDATA%/Godot/app_userdata/STAIRBORN/accounts/` no painel Steamworks | 🔒 configuração no site |
| Conquistas: `PlatformServices.unlock_achievement` já dispara os marcos (`REACH_50`, `REACH_100`...) | ⚠️ criar as conquistas no Steamworks com os mesmos nomes de API |
| Steam Inventory + Community Market (itens Legendary+ e relíquias) | ⚠️ gerar itemdefs com `tools/export_steam_itemdefs.gd` e enviar; precisa do AppID |
| `steam_app_id` em `data/platform.json` | 🔒 só existe depois de pagar a taxa |
| GodotSteam (extensão) no projeto e `steam_appid.txt` ao lado do exe para testar | ⚠️ 🔒 |
| Ícone e metadados do `.exe` (rcedit) | ⚠️ não dá para aplicar na máquina de build Linux; fazer no Windows ou com wine |
| Versão visível (`config/version`, mostrada no login) | ✅ |
| Idiomas: en, pt, es (menu, painéis, login, missões) | ✅ parcial: faltam nomes de itens/monstros/skills e história em es |
| Controle / Steam Deck | ❌ o jogo é um companheiro de janela com mouse; Deck Verified exigiria modo de tela cheia com controle (não planejado) |
| Teste em Windows de verdade (janelas soltas, bandeja, múltiplos monitores, DPI) | ⚠️ crítico antes de lançar |

## 4. Decisões que dependem de você

1. **Early Access ou lançamento completo?** Recomendo Early Access: o jogo é um loop vivo e se beneficia de feedback.
2. **Preço.** Idle/companheiros de desktop costumam ficar entre US$ 3 e 8; a Steam permite mudar depois.
3. **Mercado de itens.** Recomendação (ver o paper): só Community Market, itens vinculados ao equipar não podem ser negociados.
4. **Nome "Stairborn".** Pesquisar marca registrada e conflito de nome na Steam antes de pagar a taxa.
5. **Assets do PixelLab.** Conferir nos termos do plano que usou se a arte gerada pode ser comercializada.
6. **Política de privacidade** e termos curtos (a loja pede uma URL se coletar dados; hoje o jogo não coleta nada).

## 5. Ordem sugerida

1. Testar a build no Windows e corrigir (1–2 sessões).
2. Criar a conta Steamworks, pagar a taxa, obter o AppID.
3. Arte da loja + 5 screenshots + trailer curto, e publicar a página "Coming Soon" (2+ semanas).
4. Integrar GodotSteam, conquistas, Auto-Cloud, itemdefs; build de Steam via SteamPipe.
5. Revisão de build/loja da Valve, lançamento (Early Access).
