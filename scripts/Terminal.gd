extends Panel

# CANCELLED BECAUSE UNEXPLAINED BEHAVIOUR IN BASH
# this regex matches the whole alphabet (including accents)
# the modifier "i" is added here with "(?i)" even though it should not be necessary
#const REGEX_ALPHA = "(?i)[A-zÀ-úûüÿŸœŒ]+"
#const REGEX_DIGITS = "\\d+"
#const REGEX_BLANK = "\\s+"
#const REGEX_SPACE = "[ ]+"
#const REGEX_LOWER = "[a-zà-úûüÿœ]+"
#const REGEX_UPPER = "[A-ZÀ-ÙÛÜŸŒ]+"

const INIT_TEXT = "Terminal M100 1.0.\nVous pouvez entrer des commandes.\n-----------------\n"

onready var interface: RichTextLabel = $Interface; # the terminal
onready var prompt: LineEdit = $Prompt; # the input

var history := [] # array of strings containing all previous entered commands
var history_index := 0 # the position in the history. Except if travelling through the history it will have the size of history as value
var pwd := PathObject.new("/") # the absolute path we are currently on in the system_tree
var system_tree := SystemElement.new(1, "/", "", "", [
	SystemElement.new(0, "file.txt", "/", "Ceci est le contenu du fichier."),
	SystemElement.new(1, "folder", "/", "", [
		SystemElement.new(0, "answer_to_life.txt", "/folder", "42"),
		SystemElement.new(0, ".secret", "/folder", "this is a secret")
	])
])

func _ready():
	interface.append_bbcode(INIT_TEXT)

func _process(_delta):
	if Input.is_action_just_pressed("ui_up") && history_index > 0:
		history_index -= 1
		prompt.text = history[clamp(history_index, 0, history.size() - 1)]
	if Input.is_action_just_pressed("ui_down"):
		if history_index < history.size() - 1:
			history_index += 1
			prompt.text = history[history_index]
		elif prompt.text != "":
			history_index += 1
			prompt.clear()
	if Input.is_action_just_pressed("autocompletion"):
		prompt.grab_focus()
		if not prompt.text.empty():
			var element = _get_pwd_file_element()
			var possibilites = [] # array of string containing the possible names to autocomplete with
			var word_position = prompt.text.find_last(" ")
			if word_position == -1:
				word_position = 0
			var word_to_complete = prompt.text.right(word_position).strip_edges()
			for child in element.children:
				if child.filename.begins_with(word_to_complete):
					possibilites.append(child.filename)
			if possibilites.size() > 0:
				if possibilites.size() == 1:
					prompt.text = (prompt.text.substr(0, word_position) + " " + possibilites[0]).strip_edges()
				else:
					var pos = word_to_complete.length()
					var word = possibilites[0].substr(0, pos)
					for i in range(1, possibilites[0].length()):
						word = possibilites[0].substr(0, pos + i)
						var found_difference = false
						for y in range(1, possibilites.size()):
							if not possibilites[y].begins_with(word):
								found_difference = true
								break
						if found_difference:
							break
					# if we found a difference, it also means that we went one character too far,
					# hence the substring of `word`
					word = word.substr(0, word.length() - 1)
					if word == word_to_complete:
						return # useless to change the text
					prompt.text = (prompt.text.substr(0, word_position) + " " + word).strip_edges()
				prompt.grab_focus()
				prompt.set_cursor_position(prompt.text.length())

func _on_command_entered(new_text: String):
	prompt.clear()
	history.append(new_text)
	history_index = history.size()
	_print_command(new_text)
	var parser = Parser.new(new_text)
	if not parser.error.empty():
		return _print_error(parser.error)
	var parsing = parser.parse()
	if not parser.error.empty():
		return _print_error(parser.error)
	var standard_input = ""
	for command in parsing:
		var function: FuncRef
		# handling one by one the exceptions,
		# (the command whose name is a function that cannot be redefined manually here)
		if command.name == "tr":
			function = funcref(self, "tr_")
		else:
			function = funcref(self, command.name)
		if not function.is_valid() or command.name.begins_with("_"):
			# Because of the way we handle commands,
			# we must make sure that the user cannot execute functions
			# such as '_process' or '_ready'.
			return _print_error("Cette commande n'existe pas.")
		else:
			var result = function.call_func(command.options, standard_input)
			if result.error != null:
				return _print_error("Commande '" + command.name + "' : " + result.error)
			else:
				standard_input = result.output
	if not standard_input.empty():
		interface.append_bbcode(standard_input)

func _print_command(command: String):
	interface.append_bbcode("$ " +  command + "\n")

func _print_error(description: String):
	interface.append_bbcode("[color=red]" + description + "[/color]\n")

func _get_file_element_at(path: PathObject):
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
		base = _get_file_element_at(pwd)
		for segment in path.segments:
			if segment == ".":
				continue
			else:
				if segment == "..":
					var dest: String = base.absolute_path.path.substr(0, base.absolute_path.path.find_last("/"))
					if dest.length() == 0:
						base = system_tree
					else:
						base = _get_file_element_at(PathObject.new(dest))
				else:
					if base == null:
						return null
					base = _get_file_element_at(PathObject.new(base.absolute_path.path + ("" if base.absolute_path.equals("/") else "/") + segment))
					#return base
	return base

func _get_pwd_file_element() -> SystemElement:
	var current_element = _get_file_element_at(pwd)
	if current_element == null:
		_print_error("Attention : le chemin actuel n'existe plus (" + pwd.path + "). Replacement à la racine.")
		pwd = PathObject.new("/")
		current_element = _get_file_element_at(pwd)
	return current_element

func echo(options: Array, _standard_input: String) -> Dictionary:
	var to_display := ""
	if options.size() > 0:
		if options[0].is_flag_and_equals("n"):
			for i in range(1, options.size()):
				to_display += options[i].value
		else:
			for i in range(0, options.size()):
				to_display += options[i].value
			to_display += "\n"
	else:
		to_display = "\n"
	return {
		"output": to_display,
		"error": null
	}

func grep(options: Array, standard_input: String) -> Dictionary:
	if standard_input.empty():
		return {
			"output": "",
			"error": null
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
	var output := standard_input.replace(search.get_string(), "[color=blue]" + search.get_string() + "[/color]")
	return {
		"output": output,
		"error": null
	}

# `tr` already exists and cannot be redefined to match the required signature,
# hence the "_" at the end of the functions' name, which will be ignored by the interpreter.
# Such exception must be handled manually.
func tr_(options: Array, standard_input: String) -> Dictionary:
	if standard_input.empty():
		return {
			"output": "",
			"error": null
		}
	if options.size() != 2:
		return {
			"error": "deux pattern doivent être spécifiés"
		}
	if options[0].is_flag() or options[1].is_flag():
		return {
			"error": "aucune option n'est acceptée"
		}
	var to_replace := RegEx.new()
	to_replace.compile(options[0].value)
	var search := to_replace.search(standard_input)
	var output := standard_input.replace(search.get_string(), options[1].value)
	return {
		"output": output,
		"error": null
	}

func cat(options: Array, _standard_input: String) -> Dictionary:
	if options.size() > 1:
		return { "error": "Commande 'cat' : trop d'arguments" }
	if options.size() == 0:
		return { "error": "Commande 'cat' : un chemin doit être spécifié" }
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return { "error": "Commande 'cat' : le chemin n'est pas valide" }
	var element = _get_file_element_at(path)
	if element == null:
		return { "error": "Commande 'cat' : la destination n'existe pas" }
	if not element.is_file():
		return { "error": "Commande 'cat' : La destination doit être un fichier !" }
	var output = (element.content if not element.content.empty() else "Le fichier est vide.") + "\n"
	return {
		"output": output,
		"error": null
	}

func ls(options: Array, _standard_input: String) -> Dictionary:
	var target = null
	var hide_secret_elements = true
	if options.size() == 0:
		target = _get_pwd_file_element()
	elif options.size() == 1:
		if options[0].is_flag():
			if options[0].value == "a":
				hide_secret_elements = false
			else:
				return {
					"error": "l'option '" + options[0].value + "' n'existe pas.",
				}
			target = _get_pwd_file_element()
		else:
			if options[0].is_word():
				target = _get_file_element_at(PathObject.new(options[0].value))
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
			target = _get_file_element_at(PathObject.new(options[1].value))
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

func clear(options: Array, _standard_input: String) -> Dictionary:
	interface.text = ""
	return {
		"output": "",
		"error": null
	}

func tree(options: Array, _standard_input: String) -> Dictionary:
	return {
		"output": _get_pwd_file_element().to_string(), # this is using the default _to_string methods recursively on the children of the root
		"error": null
	}

func pwd(options: Array, _standard_input: String) -> Dictionary:
	return {
		"output": pwd.path + "\n",
		"error": null
	}

func cd(options: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0:
		pwd = PathObject.new("/")
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
	var element = _get_file_element_at(path)
	if element == null:
		return {
			"error": "la destination n'existe pas."
		}
	if element.is_file():
		return {
			"error": "la destination doit être un dossier."
		}
	pwd = element.absolute_path
	return {
		"output": "",
		"error": null
	}

func touch(options: Array, _standard_input: String) -> Dictionary:
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
	var element = _get_file_element_at(path)
	if element != null: # if the file already exists, we ignore
		return {
			"output": "",
			"error": null
		}
	if path.is_leading_to_folder():
		return {
			"error": "la cible n'est pas un fichier"
		}
	var parent = _get_file_element_at(PathObject.new(path.parent) if path.parent != null else pwd)
	if parent == null:
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
