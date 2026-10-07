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
	"es": {
		"tower": "Más allá de la última aldea del mundo, una torre atraviesa el cielo. Nadie ha visto jamás su cima.",
		"heroes": "Durante generaciones, héroes de todos los reinos vinieron a conquistarla...",
		"lost": "...ninguno regresó jamás.",
		"withering": "Ahora la tierra se marchita. Los ancianos dicen que el destino del mundo aguarda en la Cima.",
		"birth": "Entonces, al pie de la Torre, nació un niño. La gente lo llamó... el Stairborn.",
		"first_step": "Nacido de los escalones, subirá donde todos los héroes cayeron.",
		"begin": "Haz clic para comenzar la subida",
		"skip": "Saltar ▶▶",
		"next": "haz clic para continuar",
	},
}

const TUTORIAL := {
	"en": [
		["The tower climbs by itself", "Your Stairborn climbs while you work. The little tower floats wherever you drop it (drag it, even to another monitor). Hover it to see the party; click it or the round buttons to open the menu."],
		["Wounds, mana and bonfires", "HP and mana do NOT come back between floors. Skills cost mana. Every 10 floors a bonfire heals everything and saves a checkpoint. With Auto-rest on, a hurt party walks back to the bonfire by itself."],
		["Falling hurts", "If everyone falls, the party tumbles back to the bonfire and drops a quarter of its gold. The floor number turns green, yellow, orange or red to show how dangerous the next floor is."],
		["Heroes", "You start alone. In the HEROES panel, Mint a hero for gold: random class, name and rarity. Up to 3 heroes fight; the others wait in the reserve, and you choose who swaps in."],
		["Gear, skills and merging", "Loot is rare. Nothing equips itself: drag items onto heroes in INVENTORY (equipped items become bound). MERGE items: REFINE (4 alike → 1 of the next rarity) or EVOLVE (3 of one set → 1 of the next set). Each level gives 1 skill point for the job tree in TALENTS; learned skills are cast automatically."],
		["Souls", "When the climb stalls (floor 50+), Ascend in the SOULS panel: start over and earn Souls for permanent bonuses. Closing the game hides it in the tray; the climb goes on."],
	],
	"pt": [
		["A torre sobe sozinha", "Seu Stairborn sobe enquanto você trabalha. A torrezinha flutua onde você a deixar (arraste, até para outro monitor). Passe o mouse para ver o grupo; clique nela ou nos botões redondos para abrir o menu."],
		["Ferimentos, mana e fogueiras", "Vida e mana NÃO voltam entre os andares. As habilidades gastam mana. A cada 10 andares uma fogueira cura tudo e salva o checkpoint. Com o Auto-descanso ligado, o grupo ferido volta sozinho para a fogueira."],
		["Cair dói", "Se todos caírem, o grupo rola de volta até a fogueira e perde um quarto do ouro. O número do andar fica verde, amarelo, laranja ou vermelho para mostrar o perigo do próximo andar."],
		["Heróis", "Você começa sozinho. No painel HERÓIS, faça Mint de um herói com ouro: classe, nome e raridade aleatórios. Até 3 heróis lutam; os outros esperam na reserva, e você escolhe quem entra."],
		["Itens, habilidades e fusão", "Os itens são raros. Nada se equipa sozinho: arraste os itens para os heróis no INVENTÁRIO (item equipado fica vinculado). FUNDA itens: REFINAR (4 itens iguais → 1 de raridade acima) ou EVOLUIR (3 itens de um conjunto → 1 do próximo conjunto). Cada nível dá 1 ponto de habilidade para a árvore da classe em TALENTOS; as habilidades aprendidas saem sozinhas (lançamento automático)."],
		["Almas", "Quando a subida travar (andar 50+), faça a Ascensão no painel ALMAS: recomece e ganhe Almas para bônus permanentes. Fechar o jogo esconde ele na bandeja e a subida continua."],
	],
	"es": [
		["La torre sube sola", "Tu Stairborn sube mientras trabajas. La torrecita flota donde la dejes (arrástrala, incluso a otro monitor). Pasa el ratón para ver al grupo; haz clic en ella o en los botones redondos para abrir el menú."],
		["Heridas, maná y hogueras", "Los PV y el maná NO se recuperan entre pisos. Las habilidades gastan maná. Cada 10 pisos una hoguera lo cura todo y guarda un punto de control. Con el Auto-descanso activado, un grupo herido vuelve solo a la hoguera."],
		["Caer duele", "Si todos caen, el grupo rueda de vuelta a la hoguera y pierde una cuarta parte de su oro. El número del piso se pone verde, amarillo, naranja o rojo para mostrar lo peligroso que es el siguiente piso."],
		["Héroes", "Empiezas solo. En el panel HÉROES, haz mint de un héroe con oro: clase, nombre y rareza aleatorios. Hasta 3 héroes luchan; los demás esperan en la reserva y tú eliges quién entra."],
		["Equipo, habilidades y fusión", "El botín es escaso. Nada se equipa solo: arrastra los objetos a los héroes en INVENTARIO (lo equipado queda vinculado). FUSIONA objetos: REFINAR (4 iguales → 1 de la siguiente rareza) o EVOLUCIONAR (3 de un conjunto → 1 del siguiente conjunto). Cada nivel da 1 punto de habilidad para el árbol de clase en TALENTOS; las habilidades aprendidas se lanzan solas."],
		["Almas", "Cuando la subida se estanque (piso 50+), Asciende en el panel ALMAS: empieza de nuevo y gana Almas para bonificaciones permanentes. Cerrar el juego lo oculta en la bandeja; la subida continúa."],
	],
}

const UI := {
	"en": {"back": "Back", "next": "Next", "done": "Start climbing!", "how_to_play": "How to play", "tray_show": "Show tower", "tray_expedition": "Open Expedition", "tray_quit": "Quit", "replay_intro": "Replay intro"},
	"es": {"back": "Atrás", "next": "Siguiente", "done": "¡A subir!", "how_to_play": "Cómo jugar", "tray_show": "Mostrar torre", "tray_expedition": "Abrir Expedición", "tray_quit": "Salir", "replay_intro": "Ver la introducción"},
	"pt": {"back": "Voltar", "next": "Próximo", "done": "Começar a subir!", "how_to_play": "Como jogar", "tray_show": "Mostrar torre", "tray_expedition": "Abrir Expedição", "tray_quit": "Sair", "replay_intro": "Rever a introdução"},
}


static func lang() -> String:
	var code: String = load("res://core/loc.gd").current()
	return code if code in ["pt", "es"] else "en"


static func comic(key: String) -> String:
	return COMIC[lang()].get(key, COMIC["en"].get(key, key))


static func tutorial() -> Array:
	return TUTORIAL[lang()]


static func ui(key: String) -> String:
	return UI[lang()].get(key, UI["en"].get(key, key))
