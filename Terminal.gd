extends Panel
class_name Terminal

export var initialisation_text = "Terminal M100 1.0.\nVous pouvez entrer des commandes.\n-----------------\n"

onready var interface: RichTextLabel = $Interface; # the terminal
onready var prompt: LineEdit = $Prompt; # the input

var history := [] # array of strings containing all previous entered commands
var history_index := 0 # the position in the history. Except if travelling through the history it will have the size of history as value
var pwd := PathObject.new("/") # the absolute path we are currently on in the system_tree
var system_tree := SystemElement.new(1, "/", "", "", [
	SystemElement.new(0, "file.txt", "/", "Ceci est le contenu du fichier."),
	SystemElement.new(1, "folder", "/", "", [
		SystemElement.new(0, "answer_to_life.txt", "/folder", "42")
	])
])

func _ready():
	interface.append_bbcode(initialisation_text)

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

func _on_command_entered(new_text: String) -> void:
	prompt.clear()
	history.append(new_text)
	history_index = history.size()
	var command_delimiter := new_text.find(" ") if new_text.find(" ") != -1 else new_text.length()
	var command_name := new_text.substr(0, command_delimiter)
	var arguments := new_text.right(command_delimiter).strip_edges()
	var function := funcref(self, command_name)
	_print_command(command_name, arguments)
	if function.is_valid():
		# Because of the way we handle commands,
		# we must make sure that the user cannot execute functions
		# such as '_process' or '_ready'.
		if command_name.begins_with("_"):
			_print_error("Cette commande n'existe pas.")
			return
		function.call_func(arguments)
	else:
		_print_error("Cette commande n'existe pas.")

func _print_command(name: String, arguments: String):
	interface.append_bbcode("$ " + name + " " + arguments + "\n")

func _print_error(description: String):
	interface.append_bbcode("[color=red]" + description + "[/color]\n")

func _is_char_quote(character: String):
	return character == '"' or character == "'"

# This will parse the command's arguments
# so that it's readable and understandable by our algorithm.
# Basically, a flag can be written of two ways :
# - the short way, for example: "-a"
# - the long way, for example: "--all"
# We'll consider "--" in front of the flag.
# An argument is the combination of a flag before a value of any type.
# The result is composed of two-string arrays [flag_name, flag_value]
# We must proceed this way because we need the strings to be considered as a whole option.
# If we were to use `split(" ")` then the strings would be splitted, causing unexpected behaviors.
# Returns false if an error occured (if the syntax is not correct for example)
func _parse_command_arguments(arguments: String):
	var result := []
	var cursor := 0
	var encountered_flags := [] # the list of all the previously parsed flags, to avoid duplications such as "ls -a -a"
	# Has arguments?
	if arguments.length() == 0:
		return result
	# It is possible that the command only accepts one argument,
	# and that this argument is a string
	if _is_char_quote(arguments[cursor]):
		var parsed_value = _parse_value(arguments)
		if parsed_value[2]:
			return "Des guillemets ont été ouvertes sans avoir été refermées."
		return [["", parsed_value[1]]]
	# it's also possible that the argument is just a word
	# it is the case for "echo yoyo" for example
	if arguments[cursor] != "-":
		return result
	# Read flags
	while cursor < arguments.length():
		var flag := ["", ""]
		var is_long_flag = false
		cursor += 1
		if cursor >= arguments.length():
			return "Syntaxe invalide."
		if arguments[cursor] == "-":
			is_long_flag = true
			cursor += 1
		if is_long_flag:
			while cursor < arguments.length():
				if arguments[cursor] == " ":
					break
				flag[0] += arguments[cursor]
				cursor += 1
			if flag[0] in encountered_flags:
				return "L'option " + flag[0] + " a été dupliquée."
			else:
				encountered_flags.append(flag[0])
		else:
			flag[0] = arguments[cursor]
			if flag[0] in encountered_flags:
				return "L'option " + flag[0] + " a été dupliquée."
			else:
				encountered_flags.append(flag[0])
			cursor += 1
			if cursor < arguments.length() and arguments[cursor] != " ":
				return "L'option \"" + flag[0] + "\" ne doit avoir qu'un seul caractère."
		var parsed_value = _parse_value(arguments.right(cursor))
		if parsed_value[2]:
			return "Des guillemets ont été ouvertes sans avoir été refermées."
		cursor += parsed_value[0]
		flag[1] = parsed_value[1]
		result.append(flag)
	return result

# Parses a value, which can be a string.
# Meaning that the "-" inside the string should not be interpreted as flags.
# And that the whole content is a unique value.
# Also, some characters must be escaped when there is "\" inside (if we want quotes inside of quotes for example).
# Returns [length, result, true if not closed]
func _parse_value(content: String):
	var cursor := 0
	var is_string := false
	var string_opener := ""
	var result := ""
	while cursor < content.length():
		if _is_char_quote(content[cursor]):
			if is_string:
				if content[cursor] == string_opener:
					if content[cursor - 1] != "\\":
						is_string = false
			else:
				string_opener = content[cursor]
				is_string = true
		if not is_string and content[cursor] == "-":
			break # this is another flag
		if content[cursor] != "\\":
			result += content[cursor]	
		cursor += 1
	result = result.strip_edges()
	if not result.empty() and _is_char_quote(result[0]):
		result = result.substr(1, result.length() - 2)
	return [cursor, result, is_string]

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
					base = _get_file_element_at(PathObject.new(base.absolute_path.path + ("" if base.absolute_path.equals("/") else "/") + segment))
					return base
	return base

func _get_pwd_file_element() -> SystemElement:
	var current_element = _get_file_element_at(pwd)
	if current_element == null:
		_print_error("Attention : le chemin actuel n'existe plus (" + pwd.path + "). Replacement à la racine.")
		pwd = PathObject.new("/")
		current_element = _get_file_element_at(pwd)
	return current_element

func echo(arguments: String):
	var parsing = _parse_command_arguments(arguments)
	if parsing is String:
		return _print_error(parsing)
	if parsing.size() > 1:
		return _print_error("L'option '" + parsing[1][0] + "' est inconnue.")
	var add_line_break = true
	var to_display = ""
	for flag in parsing:
		if flag[0] == "n":
			add_line_break = false
		else:
			if flag[0] == "":
				continue
			return _print_error("L'option '" + parsing[0][0] + "' est inconnue.")
	interface.append_bbcode((parsing[0][1] if parsing.size() > 0 else arguments) + ("\n" if add_line_break else ""))

func clear(arguments: String):
	interface.text = ""

func tree(arguments: String):
	interface.append_bbcode(_get_pwd_file_element().to_string()) # this is using the default _to_string methods recursively on the children of the root

func ls(arguments: String):
	var parsing = _parse_command_arguments(arguments)
	if parsing is String:
		return _print_error(parsing)
	var target = null
	var hide_secret_elements = true # the files or folders starting with "."
	if parsing.size() > 0: # meaning there is a flag
		# checking if the flags are correct
		if parsing.size() > 1:
			return _print_error("L'option \"" + parsing[1][0] + "\" est inconnue.")
		var path = ""
		for flag in parsing:
			if flag[0] == "a":
				hide_secret_elements = false
				path = flag[1]
			else:
				return _print_error("L'option \"" + flag[0] + "\" est inconnue.")
		if path.empty(): # "ls -a"
			target = _get_pwd_file_element()
		else: # "ls -a folder"
			path = PathObject.new(path)
			if not path.is_valid:
				return _print_error("Le chemin n'est pas valide.")
			target = _get_file_element_at(path)
	else:
		if arguments.empty(): # "ls"
			target = _get_pwd_file_element()
		else: # "ls folder"
			var path = PathObject.new(arguments)
			if not path.is_valid:
				return _print_error("Le chemin n'est pas valide.")
			target = _get_file_element_at(path)
	if target == null:
		return _print_error("La destination n'existe pas.")
	if target.is_file():
		interface.append_bbcode(target.filename)
		return
	for child in target.children:
		if hide_secret_elements and child.is_hidden():
			continue
		if child.is_folder():
			interface.append_bbcode("[color=green]" + child.filename + "[/color]\n")
		else:
			interface.append_bbcode(child.filename + "\n")

func pwd(arguments: String):
	interface.append_bbcode(pwd.path + "\n")

func cd(arguments: String):
	var path = PathObject.new(arguments)
	if not path.is_valid:
		return _print_error("Le chemin n'est pas valide.")
	var element = _get_file_element_at(path)
	if element == null:
		return _print_error("La destination n'existe pas.")
	if element.is_file():
		return _print_error("Vous ne pouvez pas ouvrir un fichier.")
	pwd = element.absolute_path

func cat(arguments: String):
	var path = PathObject.new(arguments)
	if not path.is_valid:
		return _print_error("Le chemin n'est pas valide.")
	var element = _get_file_element_at(path)
	if element == null:
		return _print_error("La destination n'existe pas.")
	if not element.is_file():
		return _print_error("La destination doit être un fichier !")
	interface.append_bbcode((element.content if not element.content.empty() else "Le fichier est vide.") + "\n")

func touch(arguments: String):
	var path = PathObject.new(arguments)
	if not path.is_valid:
		return _print_error("Le chemin n'est pas valide.")
	var element = _get_file_element_at(path)
	if element != null:
		return _print_error("Le fichier existe déjà.")
	if path.is_leading_to_folder():
		return _print_error("La cible n'est pas un fichier.")
	var parent = _get_file_element_at(PathObject.new(path.parent) if path.parent != null else pwd)
	if parent == null:
		return _print_error("Le dossier du fichier à créer n'existe pas.")
	parent.append(
		SystemElement.new(0, path.file_name, parent.absolute_path.path, "")
	)
