#warning-ignore-all:return_value_discarded
extends Panel
class_name Terminal

var COMMANDS := {
	"man": {
		"reference": funcref(self, "man"),
		"manual": {
			"name": "man - affiche la page du manuel expliquant une commande précise.",
			"synopsis": ["[b]man[/b] [u]nom[/u]"],
			"description": "Cette commande fait référence au manuel qui contient une explication de toutes les commandes disponibles. Le 'nom' doit être le nom d'une commande valide, sinon une erreur sera renvoyée.",
			"options": [],
			"examples": []
		}
	},
	"echo": {
		"reference": funcref(self, "echo"),
		"manual": {
			"name": "echo - affiche un texte dans le terminal.",
			"synopsis": ["[b]echo[/b] [-n] [[u]contenu[/u] [u]...[/u]]"],
			"description": "Affiche tout le contenu séparé par un espace blanc entre le nom de la commande et la fin de la commande, sauf s'il y a l'option -n qui permet de ne pas continuer le résultat par un '\\n'.",
			"options": [
				{
					"name": "-n",
					"description": "N'ajoute pas un retour à la ligne à la fin du contenu."
				}
			],
			"examples": [
				"echo -n hello, world",
				"echo \"hello world\""
			]
		}
	},
	"grep": {
		"reference": funcref(self, "grep"),
		"manual": {
			"name": "grep - cherche un pattern dans l'entrée standard.",
			"synopsis": ["[b]grep[/b] [u]pattern[/u]"],
			"description": "Cherche dans l'entrée standard les lignes qui correspondent au pattern donné. Si le pattern n'y est pas trouvé, la ligne est ignorée. S'il est trouvé, elle est affichée et ce qui correspond au pattern est mis en évidence.",
			"options": [],
			"examples": [
				"cat fichier.txt | grep hello"
			]
		}
	},
	"tr": {
		"reference": funcref(self, "tr_"),
		"manual": {
			"name": "tr - remplace, ou supprime, un pattern précis depuis l'entrée standard pour l'afficher dans la sortie standard.",
			"synopsis": [
				"[b]tr[/b] [b]-d[/b] [u]pattern[/u]",
				"[b]tr[/b] [u]pattern[/u] [u]remplacement[/u]"
			],
			"description": "Remplace le pattern par la chaine de remplacement donné. Si l'option -d est précisée, toutes les occurrences du pattern seront supprimées. Le résultat est affiché dans la sortie standard.",
			"options": [
				{
					"name": "-d",
					"description": "supprime les occurrences du pattern plutôt que de les remplacer."
				}
			],
			"examples": [
				"echo buste | tr u a",
				"echo truc | tr -d u"
			]
		}
	},
	"cat": {
		"reference": funcref(self, "cat"),
		"manual": {
			"name": "cat - affiche le contenu d'un fichier en sortie standard.",
			"synopsis": ["[b]cat[/b] [u]fichier[/u]"],
			"description": "Renvoie le contenu du fichier donné, s'il existe, dans la sortie standard. Cette action ne peut pas être réalisée sur un dossier.",
			"options": [],
			"examples": [
				"cat fichier.txt"
			]
		}
	},
	"ls": {
		"reference": funcref(self, "ls"),
		"manual": {
			"name": "ls - liste le contenu d'un dossier",
			"synopsis": ["[b]ls[/b] [[b]-a[/b]] [[u]dossier[/u]]"],
			"description": "La commande va lister le contenu des dossiers, en colorant en vert les dossiers, et en blanc les fichiers. Par défaut, les fichiers et dossiers cachés (c'est-à-dire ceux préfixés par un point) ne serront pas affichés. Pour les afficher, utilisez l'option -a.",
			"options": [
				{
					"name": "-a",
					"description": "Affiche les fichiers cachés (ceux préfixés d'un point)"
				}
			],
			"examples": [
				"ls folder",
				"ls -a folder"
			]
		}
	},
	"clear": {
		"reference": funcref(self, "clear"),
		"manual": {
			"name": "clear - vide le terminal de son contenu textuel.",
			"synopsis": ["[b]clear[/b]"],
			"description": "Le contenu du terminal est supprimé pour reprendre sur un écran vide.",
			"options": [],
			"examples": []
		}
	},
	"pwd": {
		"reference": funcref(self, "pwd"),
		"manual": {
			"name": "pwd - retourne le chemin absolu du dossier courant",
			"synopsis": ["[b]pwd[/b]"],
			"description": "La commande pwd écrit dans la sortie standard le chemin absolu du dossier courant. Naviguez dans les dossiers en utilisant la commande \"cd\".",
			"options": [],
			"examples": []
		}
	},
	"cd": {
		"reference": funcref(self, "cd"),
		"manual": {
			"name": "cd - définis le chemin courant comme étant la cible.",
			"synopsis": ["[b]cd[/b] [[u]chemin[/u]]"],
			"description": "Définis la variable $PWD comme étant le chemin absolu de la destination ciblée par le chemin donné. Ne pas donner de chemin revient à écrire la racine, \"/\".",
			"options": [],
			"examples": [
				"cd folder",
				"cd"
			]
		}
	},
	"touch": {
		"reference": funcref(self, "touch"),
		"manual": {
			"name": "touch - crée un nouveau fichier selon la destination donnée.",
			"synopsis": ["[b]touch[/b] [u]chemin[/u]"],
			"description": "La commande crée un nouveau fichier avec le nom donné dans le chemin. La cible doit nécessairement être un fichier. Pour créer un dossier, il vous faut utiliser la commande \"mkdir\".",
			"options": [],
			"examples": [
				"touch folder/file.txt"
			]
		}
	},
	"mkdir": {
		"reference": funcref(self, "mkdir"),
		"manual": {
			"name": "mkdir - crée un nouveau dossier selon la destination donnée.",
			"synopsis": ["[b]mkdir[/b] [u]chemin[/u]"],
			"description": "La commande crée un nouveau dossier avec le nom donné dans le chemin. Pour créer un fichier, vous devriez utiliser la commande \"touch\".",
			"options": [],
			"examples": [
				"mkdir folder/newfolder"
			]
		}
	},
	"rm": {
		"reference": funcref(self, "rm"),
		"manual": {
			"name": "rm - supprime de manière définitive un élément.",
			"synopsis": ["[b]rm[/b] [[b]-rd[/b]] [u]file[/u]"],
			"description": "Cette commande permet de supprimer un fichier, ou un dossier si spécifiée avec l'option -d. Par défaut, un dossier qui n'est pas vide ne peut être supprimé, sauf si l'option -r (pour \"récursif\") est mentionnée.",
			"options": [
				{
					"name": "d",
					"description": "Permet de supprimer un dossier. Inutile si -r est mentionnée."
				},
				{
					"name": "r",
					"description": "Permet de supprimer un dossier et son contenu avec."
				}
			],
			"examples": [
				"rm file.txt",
				"rm -d emptyfolder",
				"rm -r folder"
			]
		}
	},
	"cp": {
		"reference": funcref(self, "cp"),
		"manual": {
			"name": "cp - copie un élément vers une aute destination.",
			"synopsis": ["[b]rm[/b] [u]origine[/u] [u]destination[/u]"],
			"options": [],
			"description": "Réalise la copie de l'élément d'origine vers la nouvelle destination. La copie devient indépendante de l'originale. Si une copie d'un dossier vers un autre dossier est réalisée, et que cet autre dossier contient des fichiers de même nom que le premier, alors ces fichiers seront remplacés, leur contenu ainsi perdu.",
			"examples": [
				"cp file.txt copiedfile.txt",
				"cp file.txt folder/file.txt",
				"cp folder copiedfolder"
			]
		}
	},
	"mv": {
		"reference": funcref(self, "mv"),
		"manual": {
			"name": "mv - déplace un élément vers une nouvelle destination.",
			"synopsis": ["[b]mv[/b] [u]origine[/u] [u]destination[/u]"],
			"description": "Déplace un élément d'origine vers une nouvelle destination. Ceci permet de renommer un élément. Si un déplacement a lieu d'un élément vers un autre qui existe déjà, alors, si la cible est un fichier, il est remplacé et l'élément d'origine est supprimé, ou s'il s'agit d'un dossier alors il est placé comme enfant de la cible.",
			"options": [],
			"examples": [
				"mv file.txt renamedfile.txt",
				"mv file.txt folder",
				"mv folder otherfolder"
			]
		}
	},
	"help": {
		"reference": funcref(self, "help"),
		"manual": {
			"name": "help - commande custom si vous avez besoin d'aide.",
			"synopsis": ["[b]help[/b]"],
			"description": "Cette commande est custom, elle permet d'obtenir de l'aide sur le fonctionnement même du terminal, ainsi que des indices si nécessaire.",
			"options": [],
			"examples": []
		}
	},
	"tree": {
		"reference": funcref(self, "tree"),
		"manual": {
			"name": "tree - affiche une reconstitution de l'arborescence du dossier courant",
			"synopsis": ["[b]tree[/b]"],
			"description": "Cette commande est utile pour afficher le contenu du dossier courant, ainsi que le contenu des sous-dossiers, de façon à avoir une vue globale de l'environnement de travail. En revanche, elle ne permet pas de visualiser les fichiers cachés.",
			"options": [],
			"examples": []
		}
	}
}

var PWD := PathObject.new("/") # the absolute path we are currently on in the system_tree
var system_tree := SystemElement.new(1, "/", "", "", [
	SystemElement.new(0, "file.txt", "/", "Ceci est le contenu du fichier."),
	SystemElement.new(1, "folder", "/", "", [
		SystemElement.new(0, "answer_to_life.txt", "/folder", "42"),
		SystemElement.new(0, ".secret", "/folder", "this is a secret")
	])
])

func execute(input: String, interface: RichTextLabel = null) -> String:
	var parser := BashParser.new(input)
	if not parser.error.empty():
		return parser.error
	var parsing := parser.parse()
	if not parser.error.empty():
		return parser.error
	var standard_input := ""
	for command in parsing:
		var function = COMMANDS[command.name] if command.name in COMMANDS else null
		# Because of the way we handle commands,
		# we must make sure that the user cannot execute functions
		# such as '_process' or '_ready'.
		if function == null or not function.reference.is_valid() or command.name.begins_with("_"):
			return "Cette commande n'existe pas."
		else:
			var command_redirections = interpret_redirections(command.redirections)
			for i in range(0, command_redirections.size()):
				if command_redirections[i] != null and command_redirections[i].target == null:
					return "Impossible de localiser, ni de créer, la destination du descripteur " + str(i) + "."
			var result = function.reference.call_func(command.options, command.redirections, command_redirections[0].target.content if command_redirections[0] != null else standard_input)
			if command_redirections[2] != null:
				if result.error == null:
					if command_redirections[2].type == Tokens.WRITING_REDIRECTION:
						command_redirections[2].target.content = ""
				else:
					if command_redirections[2].type == Tokens.WRITING_REDIRECTION:
						command_redirections[2].target.content = "Commande '" + command.name + "' : " + result.error
					elif command_redirections[2].type == Tokens.APPEND_WRITING_REDIRECTION:
						command_redirections[2].target.content += "Commande '" + command.name + "' : " + result.error
					return "" # if there is an error, we have to stop the program anyway
			if result.error != null:
				return "Commande '" + command.name + "' : " + result.error
			else:
				if command_redirections[1] != null:
					if command_redirections[1].type == Tokens.WRITING_REDIRECTION:
						command_redirections[1].target.content = result.output
					elif command_redirections[1].type == Tokens.APPEND_WRITING_REDIRECTION:
						command_redirections[1].target.content += result.output
				else:
					standard_input = result.output
				if interface != null and command.name == "clear":
					interface.text = ""
	if interface != null and not standard_input.empty():
		interface.append_bbcode(standard_input)
	return ""

func get_file_element_at(path: PathObject):
	if not path.is_valid:
		return null
	var base: SystemElement
	if path.is_absolute():
		base = system_tree
		var found = false
		for i in range(0, path.segments.size()):
			for child in base.children:
				if child.filename == path.segments[i]:
					base = child
					found = true
					break
			if not found:
				return null
			found = false
	else:
		base = get_pwd_file_element()
		var segments = (path.segments if not path.segments.empty() else [path.path])
		for segment in segments:
			if segment == ".":
				continue
			else:
				if segment == "..":
					var dest: String = base.absolute_path.path.substr(0, base.absolute_path.path.find_last("/"))
					if dest.length() == 0:
						base = system_tree
					else:
						base = get_file_element_at(PathObject.new(dest))
				else:
					if base == null:
						return null
					base = get_file_element_at(PathObject.new(base.absolute_path.path + ("" if base.absolute_path.equals("/") else "/") + segment))
	return base

func get_pwd_file_element() -> SystemElement:
	return get_file_element_at(PWD)

func get_parent_element_from(path: PathObject) -> SystemElement:
	return get_file_element_at(PathObject.new(path.parent) if path.parent != null else PWD)

func copy_element(e: SystemElement) -> SystemElement:
	return SystemElement.new(e.type, e.filename, e.parent, e.content, e.children)

func copy_children_of(e: SystemElement) -> Array:
	var list := []
	for child in e.children:
		list.append(copy_element(child))
	return list

# Merges two file elements.
# The origin can be a file or a folder,
# but the destination must be a folder.
# If the origin is a file and destination contains the same file,
# then the file inside the destination will receive the origin's content.
# If the origin is a folder, then the files with the same name will get replaced,
# and the new files will be appened to the destination.
# Returns true for success, false for failure
func merge(origin: SystemElement, destination: SystemElement) -> bool:
	if not destination.is_folder():
		return false
	var found_same_filename_inside_folder := false
	if origin.is_file():
		for child in destination.children:
			if child.filename == origin.filename:
				child.content = origin.content
				found_same_filename_inside_folder = true
				return true
		if not found_same_filename_inside_folder:
			destination.append(copy_element(origin).move_inside_of(destination.absolute_path))
	else:
		for child1 in origin.children:
			for child2 in destination.children:
				if child2.filename == child1.filename:
					child2.content = child1.content
					found_same_filename_inside_folder = true
					break
			if not found_same_filename_inside_folder:
				destination.append(copy_element(child1).move_inside_of(destination.absolute_path))
			else:
				found_same_filename_inside_folder = false
	return true

func move(origin: SystemElement, destination: PathObject) -> bool:
	if not destination.is_valid or origin == null:
		return false
	var new_name: String = origin.filename if destination.is_leading_to_folder() else destination.file_name
	var origin_parent: SystemElement = get_parent_element_from(origin.absolute_path)
	var destination_dir: SystemElement = get_file_element_at(destination) if destination.is_leading_to_folder() else get_parent_element_from(destination)
	if destination_dir == null:
		return false
	var copy = copy_element(origin)
	copy.rename(new_name)
	copy.move_inside_of(destination_dir.absolute_path)
	destination_dir.append(copy)
	origin_parent.children.erase(origin)
	return true

func _cut_paragraph(paragraph: String, line_length: int) -> Array:
	if paragraph.length() <= line_length:
		return [paragraph]
	var lines := []
	var i := 0
	var pos := 0
	while i < (paragraph.length() / line_length):
		var e := 0
		while (pos+line_length+e) < paragraph.length() and paragraph[pos+line_length+e] != " ":
			e += 1
		lines.append(paragraph.substr(pos, line_length + e).strip_edges())
		pos += line_length + e
		i += 1
	lines.append(paragraph.substr(pos).strip_edges())
	return lines

func build_manual_page_using(manual: Dictionary) -> String:
	var output := ""
	output += "[b]NOM[/b]\n\t" + manual.name + "\n\n"
	output += "[b]SYNOPSIS[/b]\n"
	for synopsis in manual.synopsis:
		output += "\t" + synopsis
	output += "\n\n[b]DESCRIPTION[/b]\n"
	var description_lines := _cut_paragraph(manual.description, 50)
	for line in description_lines:
		output += "\t" + line + "\n"
	if not manual.options.empty():
		output += "[b]OPTIONS[/b]\n"
		for option in manual.options:
			output += "\t[b]" + option.name + "[/b]\n"
			output += "\t\t" + option.description + "\n"
	if not manual.examples.empty():
		output += "\n[b]EXEMPLES[/b]\n"
		for example in manual.examples:
			output += "\t" + example + "\n"
	return output

# When we have redirections,
# if the file doesn't exist on the standard output,
# then we must create it.
func get_file_or_make_it(path: PathObject):
	if not path.is_valid or path.is_leading_to_folder():
		return null
	var element: SystemElement = get_file_element_at(path)
	if not element == null:
		return element
	var parent_element = get_parent_element_from(path)
	if parent_element == null or not parent_element.is_folder():
		return null
	var new_file := SystemElement.new(0, path.file_name, parent_element.absolute_path.path)
	parent_element.append(new_file)
	return new_file

# Read the redirections of a command
# in order to make the following model:
# [standard_input, standard_output, error_output]
# where all three are either null or an object:
# { "type": String (Tokens.WRITING_REDIRECTION for example), "target": SystemElement }
func interpret_redirections(redirections: Array) -> Array:
	var result := [null, null, null]
	for i in range(0, redirections.size()):
		if redirections[i].copied:
			result[redirections[i].port] = result[redirections[i].target]
		else:
			result[redirections[i].port] = redirections[i]
	if result[0] != null:
		result[0] = {
			"type": result[0].type,
			"target": get_file_element_at(PathObject.new(result[0].target)) # if it doesn't exist, we ignore
		}
	for i in range(1, result.size()):
		if result[i] != null:
			result[i] = {
				"type": result[i].type,
				"target": get_file_or_make_it(PathObject.new(result[i].target))
			}
	return result

func man(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0:
		return {
			"error": "quelle page du manuel désirez-vous ?"
		}
	if options.size() > 1 or not options[0].is_word():
		return {
			"error": "uniquement le nom d'une commande est attendue."
		}
	if not options[0].value in COMMANDS:
		return {
			"error": "'" + options[0].value + "' est une commande inconnue"
		}
	return {
		"output": build_manual_page_using(COMMANDS[options[0].value].manual),
		"error": null
	}

# feature that should be overwritten to match the requirements of the game
func help(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() > 0:
		return {
			"error": "aucun argument n'est attendu"
		}
	return {
		"output": build_manual_page_using(COMMANDS["help"].manual),
		"error": null
	}

func echo(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	var to_display := ""
	var line_break := true
	for option in options:
		if option.is_eof():
			break
		if option.is_flag():
			if option.value == "n":
				if line_break:
					line_break = false
			else:
				to_display += "-" + option.value
		else:
			to_display += " " + option.value
	return {
		"output": to_display.strip_edges() + ("\n" if line_break else ""),
		"error": null
	}

func grep(options: Array, redirections: Array, standard_input: String) -> Dictionary:
	if standard_input.empty():
		return {
			"error": "Une entrée standard doit être spécifiée"
		}
	if options.size() == 0:
		return {
			"error": "un pattern doit être spécifié."
		}
	if options.size() > 1:
		return {
			"error": "arguments en trop"
		}
	var regex := RegEx.new()
	regex.compile(options[0].value)
	var search := regex.search(standard_input)
	var output := ""
	if search != null:
		output = standard_input.replace(search.get_string(), "[color=blue]" + search.get_string() + "[/color]")
	return {
		"output": output,
		"error": null
	}

# `tr` already exists and cannot be redefined to match the required signature,
# hence the "_" at the end of the functions' name, which will be ignored by the interpreter.
# Such exception must be handled manually.
func tr_(options: Array, redirections: Array, standard_input: String) -> Dictionary:
	if standard_input.empty() or options.size() != 2:
		return {
			"error": "deux pattern doivent être spécifiés"
		}
	var del := false
	if options[0].is_flag():
		if options[0].value == "d":
			del = true
		else:
			return {
				"error": "l'option '" + options[0].value + "' est inconnue."
			}
	var to_replace := RegEx.new()
	to_replace.compile(options[1].value if del else options[0].value)
	var search := to_replace.search(standard_input)
	var output := standard_input
	if search != null:
		if del:
			output = standard_input.replace(search.get_string(), "")
		else:
			var wanted_string := search.get_string()
			var wanted_length := wanted_string.length()
			var replacement := options[1].value.repeat(wanted_length/options[1].value.length() + 1).left(wanted_length) as String
			output = standard_input.replace(wanted_string, replacement)
	return {
		"output": output,
		"error": null
	}

func cat(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() > 1:
		return { "error": "trop d'arguments" }
	if options.size() == 0:
		return { "error": "un chemin doit être spécifié" }
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return { "error": "le chemin n'est pas valide" }
	var element = get_file_element_at(path)
	if element == null:
		return { "error": "la destination n'existe pas" }
	if not element.is_file():
		return { "error": "la destination doit être un fichier !" }
	var output = (element.content if not element.content.empty() else "Le fichier est vide.") + "\n"
	return {
		"output": output,
		"error": null
	}

func ls(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	var target = null
	var hide_secret_elements = true
	if options.size() == 0:
		target = get_pwd_file_element()
	elif options.size() == 1:
		if options[0].is_flag():
			if options[0].value == "a":
				hide_secret_elements = false
			else:
				return {
					"error": "l'option '" + options[0].value + "' n'existe pas.",
				}
			target = get_pwd_file_element()
		else:
			if options[0].is_word():
				var p := PathObject.new(options[0].value)
				if not p.is_valid:
					return {
						"error": "le chemin n'est pas valide."
					}
				target = get_file_element_at(p)
			else:
				return {
					"error": "valeur inattendue '" + options[0].value + "'."
				}
	elif options.size() == 2:
		if not options[0].is_flag():
			return {
				"error": "valeur inattendue '" + options[0].value + "'. Peut-être vouliez-vous mettre une option ?"
			}
		else:
			if options[0].value == "a":
				hide_secret_elements = false
			else:
				return {
					"error": "l'option '" + options[0].value + "' n'existe pas."
				}
			if not options[1].is_word():
				return {
					"error": "valeur inattendue '" + options[1].value + "'."
				}
			var p := PathObject.new(options[1].value)
			if not p.is_valid:
				return {
					"error": "le chemin n'est pas valide."
				}
			target = get_file_element_at(p)
	if target == null:
		return {
			"error": "la destination n'existe pas."
		}
	if target.is_file():
		return {
			"error": "la destination doit être un dossier."
		}
	var output = ""
	for child in target.children:
		if hide_secret_elements and child.is_hidden():
			continue
		else:
			if child.is_folder():
				output += "[color=green]" + child.filename + "[/color]\n"
			else:
				output += child.filename + "\n"
	return {
		"output": output,
		"error": null
	}

func clear(_options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	return {
		"output": "",
		"error": null
	}

func tree(_options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	return {
		"output": get_pwd_file_element().to_string(), # this is using the default _to_string methods recursively on the children of the root
		"error": null
	}

func pwd(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() != 0:
		return {
			"error": "aucun argument n'est attendu."
		}
	return {
		"output": PWD.path + "\n",
		"error": null
	}

func cd(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0:
		PWD = PathObject.new("/")
		return { "output": "", "error": null }
	elif options.size() > 1:
		return {
			"error": "un seul chemin est attendu."
		}
	if not options[0].is_word():
		return {
			"error": "l'argument '" + options[0].value + "' doit être un chemin."
		}
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return {
			"error": "le chemin donné n'est pas valide."
		}
	var element = get_file_element_at(path)
	if element == null:
		return {
			"error": "la destination n'existe pas."
		}
	if element.is_file():
		return {
			"error": "la destination doit être un dossier."
		}
	PWD = element.absolute_path
	return {
		"output": "",
		"error": null
	}

func touch(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0 or not options[0].is_word():
		return {
			"error": "un chemin est attendu en argument"
		}
	if options.size() > 1:
		return {
			"error": "un seul chemin est attendu en argument"
		}
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return {
			"error": "le chemin n'est pas valide"
		}
	var element = get_file_element_at(path)
	if element != null: # if the file already exists, we ignore
		return {
			"output": "",
			"error": null
		}
	if path.is_leading_to_folder():
		return {
			"error": "la cible n'est pas un fichier"
		}
	var parent = get_parent_element_from(path)
	if parent == null or not parent.is_folder():
		return {
			"error": "le dossier du fichier à créer n'existe pas"
		}
	parent.append(
		SystemElement.new(0, path.file_name, parent.absolute_path.path, "")
	)
	return {
		"output": "",
		"error": null
	}

func mkdir(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0 or not options[0].is_word():
		return {
			"error": "un chemin valide est attendu"
		}
	if options.size() > 1:
		return {
			"error": "un seul et unique chemin est attendu"
		}
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return {
			"error": "le chemin n'est pas valide"
		}
	var element = get_file_element_at(path)
	if element != null:
		return {
			"error": "la destination existe déjà"
		}
	var parent = get_file_element_at(PathObject.new(path.parent) if path.parent != null else PWD)
	if parent == null or not parent.is_folder():
		return {
			"error": "Le dossier parent de la destination n'existe pas"
		}
	parent.append(
		SystemElement.new(1, path.segments[-1], parent.absolute_path.path, "")
	)
	return {
		"output": "",
		"error": null
	}

func rm(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0:
		return {
			"error": "une destination est attendue"
		}
	var directory = false
	var recursive = false
	var i = 0
	while i < options.size() and options[i].is_flag():
		if options[i].value == "d":
			directory = true
		elif options[i].value == "r":
			recursive = true
		else:
			return {
				"error": "l'option '" + options[i].value + "' est inconnue."
			}
		i += 1
	if recursive:
		directory = true
	if not options[i].is_word():
		return {
			"error": "un chemin est attendu"
		}
	var path = PathObject.new(options[i].value)
	if not path.is_valid:
		return {
			"error": "le chemin n'est pas valide"
		}
	var element: SystemElement = get_file_element_at(path)
	if element == null:
		return {
			"error": "la destination n'existe pas"
		}
	if element.absolute_path.equals("/"):
		return {
			"error": "tu ne peux pas supprimer la racine, p'tit malin"
		}
	if element.absolute_path.equals(PWD):
		return {
			"error": "tu ne peux pas supprimer le dossier dans lequel tu te situes"
		}
	if element.is_file():
		var parent = get_parent_element_from(path)
		if parent == null:
			return {
				"error": "le dossier parent de la cible n'existe pas"
			}
		parent.children.erase(element)
	else:
		if not directory:
			return {
				"error": "la cible est un dossier"
			}
		elif element.children.size() > 0 and not recursive:
			return {
				"error": "la cible n'est pas vide"
			}
		else:
			var parent = get_parent_element_from(path)
			if parent == null:
				return {
					"error": "le dossier parent de la cible n'existe pas"
				}
			parent.children.erase(element)
	return {
		"output": "",
		"error": null
	}

func cp(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() != 2:
		return {
			"error": "deux chemins sont attendus"
		}
	if not options[0].is_word() or not options[1].is_word():
		return {
			"error": "il faut deux chemins en argument, l'origine puis la destination"
		}
	var cp1_path := PathObject.new(options[0].value)
	var cp2_path := PathObject.new(options[1].value)
	if not cp1_path.is_valid:
		return {
			"error": "le premier chemin est invalide."
		}
	if not cp2_path.is_valid:
		return {
			"error": "le second chemin est invalide."
		}
	var cp1 = get_file_element_at(cp1_path) as SystemElement
	var cp2 = get_file_element_at(cp2_path) as SystemElement
	if cp1 == null:
		return {
			"error": "le fichier d'origine doit exister"
		}
	if cp2 != null and cp1.equals(cp2):
		return {
			"error": "les éléments sont identiques"
		}
	# possible combinations:
	# if cp1 a file:
	# 	if cp2 exists:
	#   		if cp2 is file:
	#			copy the content of cp1 to cp2
	#		else:
	#			cp2 is a folder, if found file with the same name as cp1 then copy the content of cp1 to this file
	#			otherwise create the file which is a copy of cp1
	#	else:
	#		cp2 doesn't exist, we have to create it
	#		if the path of cp2 ressembles one of a folder, then create the folder of name cp2 and set cp1 as a child
	#		otherwise create the file cp2 which is basically a copy of cp1 but with the path of cp2
	# else:
	#	if cp2 exists:
	#		if cp2 is not a folder, then throw an error
	#		merge content of folder 1 into folder 2:
	#			if two files have the same name, then the content of the file in cp2 will be replaced by the content of the equivalent file
	#			if folder2 doesn't contain a file of the same name, then create a copy to place inside it
	#	else:
	#		create a folder and copy cp1's children
	if cp1.is_file():
		if cp2 != null:
			if cp2.is_file():
				cp2.content = cp1.content
			else:
				merge(cp1, cp2)
		else:
			if cp2_path.is_leading_to_folder():
				return {
					"error": "destination inconnue"
				}
			var parent_element := get_parent_element_from(cp2_path)
			if parent_element == null:
				return {
					"error": "le chemin du dossier parent de la cible n'existe pas"
				}
			var new_file := SystemElement.new(
				0,
				cp2_path.file_name,
				parent_element.absolute_path.path,
				cp1.content
			)
			parent_element.append(new_file)
	else:
		if cp2 != null:
			if not cp2.is_folder():
				return {
					"error": "si l'origine est un dossier alors laa cible doit être un dossier aussi"
				}
			merge(cp1, cp2)
		else:
			# the destination doesn't exist,
			# create a folder and copy the entire content as its children
			var parent_element := get_parent_element_from(cp2_path)
			var children := copy_children_of(cp1)
			for child in children:
				child.move_inside_of(parent_element.absolute_path.path + "/" + cp2_path.file_name)
			var target_element := SystemElement.new(1, cp2_path.file_name, parent_element.absolute_path.path, "", children)
			parent_element.append(target_element)
	return {
		"output": "",
		"error": null
	}

func mv(options: Array, redirections: Array, _standard_input: String) -> Dictionary:
	if options.size() != 2 or not options[0].is_word() or not options[1].is_word():
		return {
			"error": "deux chemins valides sont attendus"
		}
	var mv1_path := PathObject.new(options[0].value)
	var mv2_path := PathObject.new(options[1].value)
	if not mv1_path.is_valid:
		return {
			"error": "le premier chemin n'est pas valide"
		}
	if not mv2_path.is_valid:
		return {
			"error": "le second chemin n'est pas valide"
		}
	var mv1: SystemElement = get_file_element_at(mv1_path)
	var mv2: SystemElement = get_file_element_at(mv2_path)
	if mv1 == null:
		return {
			"error": "l'origine n'existe pas"
		}
	# if the origin is a file,
	# 	if the destination exists
	#		if the destination is a file,
	# 			override content of destination file with the origin's content
	#		else:
	#			move the origin inside the destination
#			delete mv1
	# 	else:
	#		move mv1 to mv2
	# else:
	#	if the destination exists:
	#		if the destination is a folder
	#			move the origine inside the destination
	#			delete mv1
	#		else:
	#			error (cannot move a folder to a file)
	#	else:
	#		move mv1 to mv2
	if mv1.is_file():
		if mv2 != null:
			var parent_mv1: SystemElement = get_parent_element_from(mv1_path)
			if mv2.is_file():
				mv2.content = mv1.content
			else:
				if merge(mv1, mv2) == false:
					return {
						"error": "la destination n'est pas un dossier"
					}
			parent_mv1.children.erase(mv1)
		else:
			if move(mv1, mv2_path) == false:
				return {
					"error": "la destination n'existe pas"
				}
	else:
		if mv2 != null:
			if mv2.is_folder():
				var parent_mv1: SystemElement = get_parent_element_from(mv1_path)
				mv2.append(copy_element(mv1).move_inside_of(mv2.absolute_path))
				parent_mv1.children.erase(mv1)
			else:
				return {
					"error": "la destination doit être un dossier"
				}
		else:
			if move(mv1, mv2_path) == false:
				return {
					"error": "la destination n'existe pas"
				}
	return {
		"output": "",
		"error": null
	}
