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
		["The tower climbs by itself", "Your Stairborn climbs while you work. The little tower floats wherever you drop it (drag it, even to another monitor). Hover it to see the party; click it or the round buttons to open the menu."],
		["Wounds, mana and bonfires", "HP and mana do NOT come back between floors. Skills cost mana. Every 10 floors a bonfire heals everything and saves a checkpoint. With Auto-rest on, a hurt party walks back to the bonfire by itself."],
		["Falling hurts", "If everyone falls, the party tumbles back to the bonfire and drops a quarter of its gold. The floor number turns green, yellow, orange or red to show how dangerous the next floor is."],
		["Heroes", "You start alone. In the HEROES panel, Mint a hero for gold: random class, name and rarity. Up to 3 heroes fight; the others wait in the reserve, and you choose who swaps in."],
		["Gear, talents and skills", "Loot drops on the stairs. Drag items onto heroes in INVENTORY, and burn spare items in the Forge to make a better one. Each level gives a talent point (TALENTS); new skills unlock at levels 10 and 25 (SKILLS)."],
		["Souls", "When the climb stalls (floor 50+), Ascend in the SOULS panel: start over and earn Souls for permanent bonuses. Closing the game hides it in the tray; the climb goes on."],
	],
	"pt": [
		["A torre sobe sozinha", "Seu Stairborn sobe enquanto você trabalha. A torrezinha flutua onde você a deixar (arraste, até para outro monitor). Passe o mouse para ver o grupo; clique nela ou nos botões redondos para abrir o menu."],
		["Ferimentos, mana e fogueiras", "Vida e mana NÃO voltam entre os andares. As skills gastam mana. A cada 10 andares uma fogueira cura tudo e salva o checkpoint. Com o Auto-descanso ligado, o grupo ferido volta sozinho para a fogueira."],
		["Cair dói", "Se todos caírem, o grupo rola de volta até a fogueira e perde um quarto do ouro. O número do andar fica verde, amarelo, laranja ou vermelho para mostrar o perigo do próximo andar."],
		["Heróis", "Você começa sozinho. No painel HEROES, faça Mint de um herói com ouro: classe, nome e raridade aleatórios. Até 3 heróis lutam; os outros esperam na reserva, e você escolhe quem entra."],
		["Itens, talentos e skills", "Os itens caem nos degraus. Arraste itens para os heróis no INVENTORY e queime os que sobram na Forja para criar um melhor. Cada nível dá um ponto de talento (TALENTS); skills novas liberam nos níveis 10 e 25 (SKILLS)."],
		["Souls", "Quando a subida travar (andar 50+), faça a Ascensão no painel SOULS: recomece e ganhe Souls para bônus permanentes. Fechar o jogo esconde ele na bandeja e a subida continua."],
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
