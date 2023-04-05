extends Object
class_name M99

const MEMO := [
	"0xy = STR xy  | R -> mem(xy)",
	"1xy = LDA xy  | A <- mem(xy)",
	"2xy = LDB xy  | B <- mem(xy)",
	"3xy = MOV x y | y <- x (R:0, A:1, B:2)",
	"400 = ADD     | R <- A + B",
	"401 = SUB     | R <- A - B",
	"5xy = JMP xy  | go to xy",
	"6xy = JPP xy  | R > 0 => saute vers l'adresse xy",
	"7xy = JEQ xy  | R=xy => ignore la cellule suivante",
	"8xy = JNE xy  | R!=xy => ignore la cellule suivante"
]

var help_text := "L'aide a été ouverte.\nTapez la commande \"show\" pour en sortir.\n\nLe M99 est une simulation théorique du langage Assembler.\nPour faire simple, il s'agit d'instructions très basiques qui à elles seules\nreprésentent toutes les opérations successives que peut réaliser un processeur.\nLes instructions sont représentées en 3 nombres dont la signification est affichée dans le Mémo.\nVous pouvez également les écrire dans leur équivalent mnémonique.\nPar exemple : \"199 299 400 599\" = \"LDA 99 LDB 99 ADD HLT\".\n\nDans le M99, la position d'une cellule se compose de deux chiffres : x et y.\nLa première cellule est 00, la dernière est 99.\nLe premier chiffre correspond à la ligne horizontale, celle du haut,\net le second chiffre à la ligne de gauche, celle verticale.\n\nPour sauvegarder des constantes, utilisez les \"registres\" A ou B,\nou stockez directement la valeur dans une cellule\ninaccessible choisie avec l'instruction STR.\n\nPour manipuler des données entrées par un utilisateur, remplissez le tableau des entrées,\net le programme lira chacune des entrées quand demandé par LDA 99 ou LDB 99.\n\n" + ("\n".join(MEMO)) + "\n\nCi-dessous la liste des commandes possibles.\nEntrez \"man nom_de_la_commande\" pour avoir de l'aide sur une commande particulière."

var started := false
var PROGRAM = null
var REGISTRY_A := 0
var REGISTRY_B := 0
var REGISTRY_R := 0
var INPUTS := []
var OUTPUT = null
var current_input_index := -1

var COMMANDS := {
	"help": {
		"reference": funcref(self, "help"),
		"manual": {
			"name": "help - commande si vous avez besoin d'aide quant à M99.",
			"synopsis": ["[b]help[/b]"],
			"description": "Utilisez cette commande si vous avez besoin de rappels quant au fonctionnement du M99. En plus d'une explication, retrouvez également la liste de toutes les commandes utilisables pour manipuler le programme.",
			"options": [],
			"examples": []
		}
	},
	"exit": {
		"reference": funcref(self, "exitm99"),
		"manual": {
			"name": "exit - arrête le M99.",
			"synopsis": ["[b]exit[/b]"],
			"description": "Permet d'arrêter le processus M99 afin de retourner à la console. Les données ne sont pas supprimées.",
			"options": [],
			"examples": []
		}
	},
	"show": {
		"reference": funcref(self, "showm99"),
		"manual": {
			"name": "show - recharge l'affichage.",
			"synopsis": ["[b]show[/b]"],
			"description": "Supprime les messages d'erreur et autres pour une interface plus claire.",
			"options": [],
			"examples": []
		}
	},
	"set": {
		"reference": funcref(self, "setm99"),
		"manual": {
			"name": "set - définis une cellule.",
			"synopsis": ["[b]set[/b] [u]position[/u] [u]commande[/u]"],
			"description": "Définis la valeur d'une cellule du programme à une certaine position tout en vérifiant la validité syntaxique de la commande.",
			"options": [],
			"examples": [
				"set 05 LDA 99",
				"set 05 199"
			]
		}
	},
	"fill": {
		"reference": funcref(self, "fillm99"),
		"manual": {
			"name": "fill - définis plusieurs cellules avec les commandes données.",
			"synopsis": ["[b]fill[/b] [u]position[/u] [u]...commandes[/u]"],
			"description": "À une position donnée seront placées les commandes données. La syntaxe des commandes est également vérifiée, à la même manière que la commande \"set\".",
			"options": [],
			"examples": [
				"fill 05 LDA 99 LDB 99 ADD STR 99 HLT",
				"fill 05 199 299 400 099 599"
			]
		}
	},
	"get": {
		"reference": funcref(self, "get_m99_cell"),
		"manual": {
			"name": "get - renvoie la valeur d'une cellule.",
			"synopsis": ["[b]get[/b] [u]pos[/u]"],
			"description": "Renseigne la valeur de la cellule de position donnée, ou \"vide\" si aucune commande n'est définie à cette emplacement.",
			"options": [],
			"examples": [
				"get 05"
			]
		}
	},
	"execute": {
		"reference": funcref(self, "executem99"),
		"manual": {
			"name": "execute - exécute le programme actuel.",
			"synopsis": ["[b]execute[/b] [[u]position[/u]]"],
			"description": "Chaque instruction sera exécutée une à une en partant du point de départ. En cas de rencontre avec une cellule vide, l'exécution ignore la cellule et continue. Pour arrêter le programme, il doit rencontrer une instruction qui fait sauter vers la cellule 99 telle que 599 etc.",
			"options": [],
			"examples": [
				"execute",
				"execute 90"
			]
		}
	},
	"remove": {
		"reference": funcref(self, "remove_m99_cells"),
		"manual": {
			"name": "remove - supprime une cellule.",
			"synopsis": ["[b]remove[/b] [u]position[/u]"],
			"description": "Permet de supprimer la commande d'une cellule précise. Elle sera considérée comme étant \"vide\".",
			"options": [],
			"examples": [
				"remove 05"
			]
		}
	},
	"insert": {
		"reference": funcref(self, "insert_cells"),
		"manual": {
			"name": "insert - insère et décale les commandes à une position particulière.",
			"synopsis": ["[b]insert[/b] [u]position[/u] [u]...commandes[/u]"],
			"description": "Insère la suite de commandes données à une position donnée. Attention car cette commande décale toutes les suivantes, même les cellules vides. Ainsi, l'instruction à la position 98 sera supprimée si vous insérez une commande à une quelconque position.",
			"options": [],
			"examples": [
				"insert 08 LDA 01 LDB 02",
				"insert 08 101 202"
			]
		}
	},
	"set_inputs": {
		"reference": funcref(self, "inputsm99"),
		"manual": {
			"name": "set_inputs - insère une suite d'entrées que le programme pourra utiliser.",
			"synopsis": ["[b]set_inputs[/b] [u]...entrées[/u]"],
			"description": "Définis les entrées que le programme utilisera lorsque une demande à la cellule 99 sera réalisée avec LDA ou LDB.",
			"options": [],
			"examples": [
				"set_inputs 1 2 3"
			]
		}
	},
	"add_inputs": {
		"reference": funcref(self, "add_m99_inputs"),
		"manual": {
			"name": "add_inputs - ajoute des entrées.",
			"synopsis": ["[b]add_inputs[/b] [u]...entrées[/u]"],
			"description": "Ajoute une suite d'entrées que le programme utilisera lors de la lecture de l'input en cellule 99.",
			"options": [],
			"examples": [
				"add_inputs 4 5 6"
			]
		}
	},
	"clear_inputs": {
		"reference": funcref(self, "clear_m99_inputs"),
		"manual": {
			"name": "clear_inputs - supprime toutes les entrées.",
			"synopsis": ["[b]clear_inputs[/b]"],
			"description": "Le tableau d'entrées est vidé.",
			"options": [],
			"examples": []
		}
	},
	"insert_inputs": {
		"reference": funcref(self, "insert_m99_inputs"),
		"manual": {
			"name": "insert_inputs - insère des entrées.",
			"synopsis": ["[b]insert_inputs[/b] [u]indice[/u] [u]...entrées[/u]"],
			"description": "Insère les entrées données à la position \"indice\" en décalant toutes celles qui suivent. Pour insérer au début de la liste, tout en décalant toutes les valeurs actuelles, l'indice doit être 0. Pour insérer à la fin de la liste, utilisez \"[b]add_inputs[/b]\".",
			"options": [],
			"examples": [
				"insert_inputs 2 7 8"
			]
		}
	},
	"shift_inputs": {
		"reference": funcref(self, "shift_m99_inputs"),
		"manual": {
			"name": "shift_inputs - décale toutes les entrées.",
			"synopsis": ["[b]shift_inputs[/b] [u]indice[/u] [u]nombre[/u]"],
			"description": "Décale toutes les entrées de la liste d'un certain nombre à partir de la position \"indice\". Si indice est égal à 0, alors l'intégralité des entrées seront décalées et des 0 vont combler les trous.",
			"options": [],
			"examples": [
				"shift_inputs 0 0"
			]
		}
	},
	"remove_inputs": {
		"reference": funcref(self, "remove_m99_inputs"),
		"manual": {
			"name": "remove_inputs - supprime un certain nombre d'entrées.",
			"synopsis": ["[b]remove_inputs[/b] [u]indice[/u] [u]nombre[/u]"],
			"description": "Depuis \"indice\" un certain nombre d'entrées renseignées sont supprimées de la liste.",
			"options": [],
			"examples": [
				"remove_inputs 2 2"
			]
		}
	}
}

func init_blank_M99() -> void:
	PROGRAM = [
		["109", "", "", "", "", "", "", "", "", ""],
		["299", "", "", "", "", "", "", "", "", ""],
		["310", "", "", "", "", "", "", "", "", ""],
		["099", "", "", "", "", "", "", "", "", ""],
		["320", "", "", "", "", "", "", "", "", ""],
		["099", "", "", "", "", "", "", "", "", ""],
		["599", "", "", "", "", "", "", "", "", ""],
		["000", "", "", "", "", "", "", "", "", ""],
		["000", "", "", "", "", "", "", "", "", ""],
		["666", "", "", "", "", "", "", "", "", ""]
	]
	REGISTRY_A = 0
	REGISTRY_B = 0
	REGISTRY_R = 0
	INPUTS = []
	current_input_index = -1

func buildm99() -> String:
	var output := "M99 se lance... Prêt !\nEntrez \"help\" si vous avez besoin.\n\n"
	output += "   "
	for i in range(0, 10):
		output += "  " + str(i) + "  "
	output += "    Mémo : \n"
	for y in range(0, 10):
		output += "\n"
		output += " " + str(y) + " "
		for x in range(0, 10):
			if y == 9 and x == 9:
				output += "  " + ("o" if OUTPUT == null else str(OUTPUT)) + "  "
			else:
				output += " " + (PROGRAM[y][x] if not PROGRAM[y][x].empty() else " - ") + " "
		output += "      • " + MEMO[y] + "\n"
	output += "\n   R" + " ".repeat(str(REGISTRY_R).length()) + " A" + " ".repeat(str(REGISTRY_A).length()) + " B" + " ".repeat(str(REGISTRY_B).length()) + "\n"
	output += "   " + str(REGISTRY_R) + "  " + str(REGISTRY_A) + "  " + str(REGISTRY_B) + "\n\n"
	output += "   entrées = " + str(INPUTS) + "\n"
	return output

func exitm99(options: Array) -> Dictionary:
	if options.size() > 0:
		return {
			"error": "Aucune option n'est acceptée."
		}
	started = false
	return {
		"output": "",
		"modified_program": false,
		"error": null
	}

func set_m99_inputs(inputs: Array) -> void:
	INPUTS = inputs

func _read_m99_pos(pos: String) -> Dictionary:
	if pos.length() > 2:
		return {
			"error": "Une position s'écrit en 1 ou 2 nombres : \"xy\", ou juste \"y\" auquel cas x=0 implicitement."
		}
	if not pos.is_valid_integer():
		return {
			"error": "La position ne semble pas être un nombre valide."
		}
	var pos_int = int(pos)
	if pos_int < 0 or pos_int > 100:
		return {
			"error": "La position n'est pas valide."
		}
	pos = "0".repeat(2 - pos.length()) + pos
	var x = int(pos[0])
	var y = int(pos[1])
	return {
		"x": x,
		"y": y
	}

func next_m99_pos(address: Dictionary) -> Dictionary:
	if address.y == 9 and address.x == 9:
		return {
			"error": "Limite atteinte."
		}
	var new_x:int = address.x
	var new_y:int
	if address.y == 9:
		new_y = 0
		new_x += 1
	else:
		new_y = address.y + 1
	return {
		"x": new_x,
		"y": new_y
	}

# get <pos>
func get_m99_cell(options: Array) -> Dictionary:
	if options.size() != 1 or not options[0].is_plain():
		return {
			"error": "La position de la cellule est attendue."
		}
	var plain_pos: String = options[0].value
	var pos := _read_m99_pos(options[0].value)
	if "error" in pos:
		return pos
	var cell:String = PROGRAM[pos.y][pos.x]
	var value = "vide" if cell.empty() else cell
	return {
		"output": "Cellule(" + plain_pos + ") = " + value,
		"error": null,
		"modified_program": false
	}

func _validate_mov_command(x:int, y:int):
	if x == y:
		return {
			"error": "La commande \"MOV\" ne peut déplacer un registre vers lui-même."
		}
	elif x < 0 or x > 2 or y < 0 or y > 2:
		return {
			"error": "La commande \"MOV\" ne peut avoir une valeur, tant en x que en y, différente de 0, 1 ou 2."
		}
	return {}

func _is_digital_command(name: String) -> bool:
	return name.is_valid_integer()

func _read_digital_command(name: String) -> Dictionary:
	if not name.is_valid_integer():
		return {
			"error": "La commande \"MOV\" attend 2 nombres représentant les registres." if name == "MOV" else "Un nombre valide est attendu."
		}
	var value_int = int(name)
	if name.length() != 3 or \
			value_int < 0 or \
			value_int >= 900 or \
			(name[0] == "4" and value_int > 401):
		return {
			"error": "La valeur \"" + name + "\" n'est pas valide."
		}
	if name[0] == "3":
		var x := int(name[1])
		var y := int(name[2])
		var checkup = _validate_mov_command(x, y)
		if "error" in checkup:
			return checkup
	return {
		"command": name
	}

func _read_mnemonic_command(name: String, options: Array) -> Dictionary:
	if name == "ADD":
		return {
			"value": "400",
			"size": 1
		}
	elif name == "SUB":
		return {
			"value": "401",
			"size": 1
		}
	elif name == "HLT":
		return {
			"value": "599",
			"size": 1
		}
	else:
		var head: int = -1
		match name:
			"STR": head = 0
			"LDA": head = 1
			"LDB": head = 2
			"MOV": head = 3
			"JMP": head = 5
			"JPP": head = 6
			"JEQ": head = 7
			"JNE": head = 8
		if head == -1:
			return {
				"error": "La commande \"" + name + "\" est inconnue."
			}
		if head == 3:
			if options.size() < 2:
				return {
					"error": "La commande MOV attend deux arguments : x et y."
				}
			if not options[0].value.is_valid_integer() or not options[1].value.is_valid_integer():
				return {
					"error": "Les nombres sont invalides pour la commande MOV."
				}
			var x = int(options[0].value)
			var y = int(options[1].value)
			var checkup = _validate_mov_command(x, y)
			if "error" in checkup:
				return checkup
			return {
				"value": str(head) + str(x) + str(y),
				"size": 3
			}
		else:
			if options.size() == 0:
				return {
					"error": "La commande '" + name + "' a besoin d'un argument (xy)."
				}
			var xy = options[0].value
			if xy.length() != 2:
				return {
					"error": "Valeur incorrecte pour la commande '" + name + "'."
				}
			return {
				"value": str(head) + xy,
				"size": 2
			}

# set <pos> <value>
# set <pos> <name> (<xy> OR <x> <y>)
func setm99(options: Array) -> Dictionary:
	if options.size() < 2:
		return {
			"error": "Nombre d'arguments invalide."
		}
	if not options[0].is_plain():
		return {
			"error": "Le premier argument doit être la position de la cellule à modifier."
		}
	var pos = _read_m99_pos(options[0].value)
	if "error" in pos:
		return pos
	if not options[1].is_plain():
		return {
			"error": "Le second argument ne semble pas valide."
		}
	if pos.x == 9 and pos.y == 9:
		return {
			"error": "Impossible de définir une commande pour la cellule 99."
		}
	var value: String = ""
	var name: String = options[1].value
	if _is_digital_command(name):
		# Is it the mnemonic name or the digital representation?
		# It must be the digital representation if this is the last token, or if it's ADD or SUB.
		var checkup = _read_digital_command(name)
		if "error" in checkup:
			return checkup
		value = name
	else:
		var checkup = _read_mnemonic_command(name, options.slice(2, options.size() - 1))
		if "error" in checkup:
			return checkup
		value = checkup.value
	PROGRAM[pos.y][pos.x] = value # y x
	return {
		"output": "",
		"modified_program": true,
		"error": null
	}

func fill_M99_with(program: Array, starting_point := { "x":0,"y":0 }) -> Dictionary:
	var address = starting_point
	for instr in program:
		PROGRAM[address.y][address.x] = instr
		address = next_m99_pos(address)
		if "error" in address:
			return address
	return {}

func _read_multiple_commands(options: Array) -> Dictionary:
	var i := 0
	var commands := []
	while i < options.size():
		var name: String = options[i].value
		if _is_digital_command(name):
			var checkup = _read_digital_command(name)
			if "error" in checkup:
				return checkup
			commands.append(name)
			i += 1
		else:
			var checkup = _read_mnemonic_command(name, options.slice(i + 1, options.size() - 1))
			if "error" in checkup:
				return checkup
			commands.append(checkup.value)
			i += checkup.size
	return {
		"commands": commands
	}

# fill <pos> <...values>
func fillm99(options: Array) -> Dictionary:
	if options.size() < 2:
		return {
			"error": "Au moins deux arguments sont attendus : la position de départ et une valeur"
		}
	if not options[0].is_plain():
		return {
			"error": "Le premier argument doit être la position de départ."
		}
	var pos = _read_m99_pos(options[0].value)
	if "error" in pos:
		return pos
	var checkup = _read_multiple_commands(options.slice(1, options.size() - 1))
	if "error" in checkup:
		return checkup
	fill_M99_with(checkup.commands, pos)
	return {
		"modified_program": true,
		"output": "",
		"error": null
	}

func showm99(options: Array) -> Dictionary:
	if options.size() > 0:
		return {
			"error": "Aucune option n'est attendue."
		}
	return {
		"modified_program": true, # to force a refresh of the screen
		"output": "",
		"error": null
	}

func _add_input(option: BashToken, at: int = -1) -> String:
	if at == -1:
		at = INPUTS.size()
	if option.is_plain():
		var value = option.value
		if not value.is_valid_integer():
			return "La valeur '" + value + "' n'est pas un nombre valide."
		var int_value = int(value)
		if int_value < 0 or int_value > 99:
			return "La valeur '" + value + "' n'est pas comprise entre 0 et 99."
		if INPUTS.size() == 99:
			return "Limite de valeurs atteintes ! (99)"
		INPUTS.insert(at, int(value))
	else:
		return "L'option '" + str(option.value) + "' n'est pas valide."
	return ""

# set_inputs 42 67 99
func inputsm99(options: Array) -> Dictionary:
	INPUTS = []
	for option in options:
		var result = _add_input(option)
		if not result.empty():
			return {
				"error": result
			}
	return {
		"output": "",
		"modified_program": true,
		"error": null
	}

func add_m99_inputs(options: Array) -> Dictionary:
	if options.size() == 0:
		return {
			"error": "Au moins une valeur est attendue."
		}
	for option in options:
		var result = _add_input(option)
		if not result.empty():
			return {
				"error": result
			}
	return {
		"output": "",
		"modified_program": true,
		"error": null
	}

func clear_m99_inputs(options: Array) -> Dictionary:
	if options.size() > 0:
		return {
			"error": "Aucun argument n'est attendu."
		}
	INPUTS = []
	return {
		"output": "",
		"modified_program": true,
		"error": null
	}

# insert <index> <...values>
func insert_cells(options: Array) -> Dictionary:
	if options.size() < 2:
		return {
			"error": "Pas assez d'arguments !"
		}
	if not options[0].is_plain() or not options[0].value.is_valid_integer():
		return {
			"error": "Le premier argument doit être la position à partir de laquelle insérer les éléments."
		}
	var given_pos = _read_m99_pos(options[0].value)
	if "error" in given_pos:
		return given_pos
	var checkup = _read_multiple_commands(options.slice(1, options.size() - 1))
	if "error" in checkup:
		return checkup
	# to simplify the operations,
	# we'll create an empty copy of the PROGRAM
	# From 0 to the given pos, we'll just copy.
	# When reached the given pos, we'll insert the given commands.
	# And then, we'll insert what was after the given pos in the original PROGRAM.
	var copy := [
		["", "", "", "", "", "", "", "", "", ""],
		["", "", "", "", "", "", "", "", "", ""],
		["", "", "", "", "", "", "", "", "", ""],
		["", "", "", "", "", "", "", "", "", ""],
		["", "", "", "", "", "", "", "", "", ""],
		["", "", "", "", "", "", "", "", "", ""],
		["", "", "", "", "", "", "", "", "", ""],
		["", "", "", "", "", "", "", "", "", ""],
		["", "", "", "", "", "", "", "", "", ""],
		["", "", "", "", "", "", "", "", "", ""]
	]
	if get_pc_count_from_pos(given_pos) + checkup.commands.size() >= 99:
		return {
			"error": "Trop d'éléments à insérer !"
		}
	var pos_i = { "x":0,"y":0 }
#	breakpoint
	while not (pos_i.x == given_pos.x and pos_i.y == given_pos.y):
		copy[pos_i.y][pos_i.x] = PROGRAM[pos_i.y][pos_i.x]
		pos_i = next_m99_pos(pos_i)
		if "error" in pos_i:
			return pos_i
	var copy_given_pos = given_pos
	for command in checkup.commands:
		copy[copy_given_pos.y][copy_given_pos.x] = command
		copy_given_pos = next_m99_pos(copy_given_pos)
		if "error" in copy_given_pos:
			return copy_given_pos
	while true: # we don't include the input/output cell
		copy[copy_given_pos.y][copy_given_pos.x] = PROGRAM[pos_i.y][pos_i.x]
		pos_i = next_m99_pos(pos_i)
		if "error" in pos_i:
			return pos_i
		copy_given_pos = next_m99_pos(copy_given_pos)
		if "error" in copy_given_pos:
			return copy_given_pos
		if copy_given_pos.x == 9 and copy_given_pos.y == 9:
			break
	PROGRAM = copy
	return {
		"output": "",
		"modified_program": true,
		"error": null
	}

# insert_inputs <index> <...values>
func insert_m99_inputs(options: Array) -> Dictionary:
	if options.size() < 2:
		return {
			"error": "Pas assez d'arguments."
		}
	if not options[0].is_plain() or not options[0].value.is_valid_integer():
		return {
			"error": "Le premier argument doit être la position à partir de laquelle insérer les éléments."
		}
	var index:int = int(options[0].value)
	for i in range(1, options.size()):
		var result = _add_input(options[i], index + i - 1)
		if not result.empty():
			return {
				"error": result
			}
	return {
		"output": "",
		"modified_program": true,
		"error": null
	}

# shift_inputs <index> <count>
func shift_m99_inputs(options: Array) -> Dictionary:
	if options.size() != 2:
		return {
			"error": "La commande 'shift_inputs' attend 2 arguments : le début et le nombre d'espaces."
		}
	if not options[0].is_plain() or not options[0].value.is_valid_integer():
		return {
			"error": "L'indice de position initiale n'est pas un nombre valide."
		}
	var index:int = int(options[0].value)
	if index < 0 or index > 100 or index >= INPUTS.size():
		return {
			"error": "Indice invalide."
		}
	if not options[1].is_plain() or not options[1].value.is_valid_integer():
		return {
			"error": "Le nombre d'éléments à déplacer n'est pas valide."
		}
	var n:int = int(options[1].value)
	if n < 0:
		return {
			"error": "Nombre d'éléments invalide."
		}
	if INPUTS.size() + n > 99:
		return {
			"error": "Ceci va faire dépasser la limite de 99 entrées."
		}
	for i in range(index, index + n):
		INPUTS.insert(i, 0)
	return {
		"output": "",
		"modified_program": true,
		"error": null
	}

# remove <beginning> <count=1>
func remove_m99_inputs(options: Array) -> Dictionary:
	if options.size() == 0:
		return {
			"error": "Une position est attendue."
		}
	if options.size() > 2:
		return {
			"error": "Trop d'arguments."
		}
	if not options[0].is_plain() or not options[0].value.is_valid_integer():
		return {
			"error": "Un nombre est attendu en tant que position de l'élément, ou des éléments, à supprimer."
		}
	var index := int(options[0].value)
	var count := 1
	if options.size() == 2:
		if not options[1].is_plain() or not options[1].value.is_valid_integer():
			return {
				"error": "Le second argument est censé être un nombre."
			}
		count = int(options[1].value)
	if index >= INPUTS.size():
		return {
			"error": "La position " + str(index) + " est trop grande."
		}
	for i in range(min(index + count - 1, INPUTS.size()), index - 1, -1): # [1, 2, 3, 4, 5] : remove 2 2 = remove 4 3, index is inclusive
		INPUTS.remove(i)
	return {
		"output": "",
		"modified_program": true,
		"error": null
	}

# remove <beginning> <count=1>
func remove_m99_cells(options: Array) -> Dictionary:
	if options.size() == 0:
		return {
			"error": "Une position est attendue."
		}
	if options.size() > 2:
		return {
			"error": "Trop d'arguments."
		}
	if not options[0].is_plain():
		return {
			"error": "Le premier argument doit être la position de départ."
		}
	var pos = _read_m99_pos(options[0].value)
	if "error" in pos:
		return pos
	var count = 1
	if options.size() == 2:
		if not options[1].is_plain() or not options[1].value.is_valid_integer():
			return {
				"error": "Le second argument est censé être un nombre."
			}
		count = int(options[1].value)
	for i in range(0, count):
		if pos.x == 9 and pos.y == 9:
			break
		PROGRAM[pos.y][pos.x] = ""
		var next_pos = next_m99_pos(pos)
		if "error" in next_pos:
			return next_pos
		pos = next_pos
	return {
		"output": "",
		"modified_program": true,
		"error": null
	}

# execute <pos>
func executem99(options: Array) -> Dictionary:
	if options.size() > 1:
		return {
			"error": "Trop d'arguments !"
		}
	var address := { "x": 0, "y": 0 }
	if options.size() == 1:
		var pos = _read_m99_pos(options[0].value)
		if "error" in pos:
			return pos
		address = pos
	var result = execute_m99_program(address)
	if result == false:
		return {
			"error": "Le programme a planté !"
		}
	return {
		"error": null,
		"output": "" if (current_input_index) == (INPUTS.size() - 1) else "[color=yellow]Attention : trop d'entrées par rapport à celles demandées par le programme exécuté (" + str(current_input_index + 1) + "/" + str(INPUTS.size()) + ").[/color]",
		"modified_program": true
	}

func read_address(x:int, y:int):
	if x == 9 and y == 9:
		if OUTPUT != null:
			var tmp = OUTPUT
			OUTPUT = null
			return tmp
		elif current_input_index == (INPUTS.size() - 1):
			return "Aucune entrée n'a été donnée."
		else:
			current_input_index += 1
			return INPUTS[current_input_index]
	else:
		var cell: String = PROGRAM[y][x]
		if cell.empty():
			return "La cellule est vide."
		return int(cell)

func get_pc_count_from_pos(pos:Dictionary) -> int:
	return pos.x * 10 + pos.y

func get_pos_from_pc_count(PC:int) -> Dictionary:
	return {
		"y": PC % 10,
		"x": PC / 10
	}

# Executes each instruction of the program at a precise starting point.
# The result will be stored in the output cell (99)
# or will be the value of the R registry.
# It's to the developer to decide how to use his result.
# As a reminder, we're reading the grid column by column.
# Note that this function assumes that the program doesn't have syntax errors.
func execute_m99_program(starting_point: Dictionary = { "x":0,"y":0 }) -> bool:
	current_input_index = -1
	REGISTRY_R = 0
	REGISTRY_A = 0
	REGISTRY_B = 0
	OUTPUT = null
	var PC:int = get_pc_count_from_pos(starting_point)
	while PC < 98: # we don't read the output/input address
		var cell:String = PROGRAM[PC % 10][PC / 10]
		if cell.empty():
			PC += 1
			continue
		var skipped:bool = false
		var head:int = int(cell[0])
		var x:int = int(cell[1])
		var y:int = int(cell[2])
		match head:
			0: # STR xy = stores R at address xy
				if x == 9 and x == 9:
					OUTPUT = REGISTRY_R
				else:
					var R_value = str(REGISTRY_R)
					if R_value.length() > 3:
						return false
					PROGRAM[y][x] = "0".repeat(3 - R_value.length()) + R_value
				REGISTRY_R = 0
			1: # LDA xy = store the value at address xy in A
				var value = read_address(x, y)
				if value is String:
					return false
				REGISTRY_A = value
			2: # LDB xy = store the value at address xy in B
				var value = read_address(x, y)
				if value is String:
					return false
				REGISTRY_B = value
			3: # MOV x y = x -> y where x and y are integers: 0=R, 1=A, 2=B
				var from:int = x
				var to  :int = y
				if from == 0:
					if to == 1:
						REGISTRY_A = REGISTRY_R
					elif to == 2:
						REGISTRY_B = REGISTRY_R
					REGISTRY_R = 0
				elif from == 1:
					if to == 0:
						REGISTRY_R = REGISTRY_A
					elif to == 2:
						REGISTRY_B = REGISTRY_A
					REGISTRY_A = 0
				elif from == 2:
					if to == 0:
						REGISTRY_R = REGISTRY_B
					elif to == 1:
						REGISTRY_A = REGISTRY_B
					REGISTRY_B = 0
			4: # add or substract registries A and B and store value to R 
				if int(cell[2]) == 0:
					REGISTRY_R = REGISTRY_A + REGISTRY_B
				else:
					REGISTRY_R = REGISTRY_A - REGISTRY_B
			5: # JMP xy = jump to address xy
				var address = int(cell[1] + cell[2])
				if address == 99:
					return true
				PC = address
				skipped = true
			6: # JPP xy = jump to address xy only if R > 0
				if REGISTRY_R > 0:
					var address = int(cell[1] + cell[2])
					if address == 99:
						return true
					PC = address
					skipped = true
			7: # JEQ xy = step over the next cell only if R == xy
				if REGISTRY_R == int(cell[1] + cell[2]):
					PC += 2
					skipped = true
			8: # JNE xy = step over the next cell only if R != xy
				if REGISTRY_R != int(cell[1] + cell[2]):
					PC += 2
					skipped = true
		if skipped:
			skipped = false
			continue
		PC += 1
	return true
