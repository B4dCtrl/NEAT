extends RefCounted
## Story and tutorial texts in English and Portuguese. The language follows the
## operating system (pt* -> Portuguese, everything else -> English).

const COMIC := {
	"en": {
		"tower": "Beyond the last village of the world, a tower pierces the sky. No one has ever seen its top.",
		"heroes": "For generations, heroes came from every kingdom to conquer it...",
		"lost": "...none of them ever returned.",
		"withering": "Now the land is withering. The elders say the fate of the world waits at the Summit.",
		"birth": "Then, at the foot of the Tower, a child was born. The people called it... the Stairborn.",
		"first_step": "Born of the stairs, it will climb where every hero fell.",
		"begin": "Click to begin the climb",
		"skip": "Skip ▶▶",
		"next": "click to continue",
	},
	"pt": {
		"tower": "Além da última vila do mundo, uma torre rasga o céu. Ninguém jamais viu o seu topo.",
		"heroes": "Por gerações, heróis de todos os reinos vieram conquistá-la...",
		"lost": "...nenhum deles jamais retornou.",
		"withering": "Agora a terra está definhando. Os anciões dizem que o destino do mundo espera no Topo.",
		"birth": "Então, ao pé da Torre, nasceu uma criança. O povo a chamou de... Stairborn.",
		"first_step": "Nascido dos degraus, ele subirá onde todos os heróis caíram.",
		"begin": "Clique para começar a subida",
		"skip": "Pular ▶▶",
		"next": "clique para continuar",
	},
}

const TUTORIAL := {
	"en": [
		["The tower climbs by itself", "Your Stairborn climbs while you work. The little tower lives in the corner of your taskbar: hover it to see the party and the floor, click it to open the Expedition."],
		["Fights and bonfires", "Fights are automatic. Every 10 floors there is a bonfire: the party rests, equips its best gear and saves a checkpoint. If everyone falls, they tumble back to the last bonfire and try again."],
		["Heroes", "You start alone. Mint new heroes with gold (random class and rarity) in the Party tab, or buy them in the Market. Up to 3 heroes climb together, the rest wait on the bench."],
		["Gear and skills", "Loot drops on the stairs. Drag items onto your heroes in the Equipment tab. Every level gives a skill point to spend in the Skills tab."],
		["Market and Ascension", "The Market restocks every 15 minutes. When the climb stalls, Ascend: start over and earn Souls for permanent upgrades."],
		["Closing the game", "Closing hides Stairborn in the system tray and the climb goes on. Right-click the tray icon to show it again or quit. Even with the game off, progress is calculated when you come back."],
	],
	"pt": [
		["A torre sobe sozinha", "Seu Stairborn sobe enquanto você trabalha. A torrezinha fica no canto da barra de tarefas: passe o mouse para ver o grupo e o andar, clique para abrir a Expedição."],
		["Lutas e fogueiras", "As lutas são automáticas. A cada 10 andares há uma fogueira: o grupo descansa, equipa o melhor que tem e salva um checkpoint. Se todos caírem, rolam de volta até a última fogueira e tentam de novo."],
		["Heróis", "Você começa sozinho. Faça mint de novos heróis com ouro (classe e raridade aleatórias) na aba Party, ou compre no Mercado. Até 3 heróis sobem juntos, o resto espera no banco."],
		["Equipamentos e habilidades", "Os itens caem nos degraus. Arraste itens para os heróis na aba Equipment. Cada nível dá um ponto para gastar na aba Skills."],
		["Mercado e Ascensão", "O Mercado renova o estoque a cada 15 minutos. Quando a subida travar, faça a Ascensão: recomece e ganhe Souls para melhorias permanentes."],
		["Fechando o jogo", "Fechar o jogo esconde o Stairborn na bandeja do sistema e a subida continua. Clique com o botão direito no ícone da bandeja para mostrar ou sair. Mesmo com o jogo desligado, o progresso é calculado quando você volta."],
	],
}

const UI := {
	"en": {"back": "Back", "next": "Next", "done": "Start climbing!", "how_to_play": "How to play", "tray_show": "Show tower", "tray_expedition": "Open Expedition", "tray_quit": "Quit", "replay_intro": "Replay intro"},
	"pt": {"back": "Voltar", "next": "Próximo", "done": "Começar a subir!", "how_to_play": "Como jogar", "tray_show": "Mostrar torre", "tray_expedition": "Abrir Expedição", "tray_quit": "Sair", "replay_intro": "Rever a introdução"},
}


static func lang() -> String:
	return "pt" if OS.get_locale_language() == "pt" else "en"


static func comic(key: String) -> String:
	return COMIC[lang()].get(key, COMIC["en"].get(key, key))


static func tutorial() -> Array:
	return TUTORIAL[lang()]


static func ui(key: String) -> String:
	return UI[lang()].get(key, UI["en"].get(key, key))
