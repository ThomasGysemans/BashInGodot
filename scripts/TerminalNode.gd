#warning-ignore-all:return_value_discarded
extends Panel

const INIT_TEXT = "Terminal M100 1.0.\nLe terminal fait maison [b]simplifié[/b].\nEntrez \"help\" si vous avez besoin d'aide.\n-----------------\n"

onready var interface: RichTextLabel = $Interface; # the terminal
onready var prompt: LineEdit = $Prompt; # the input

var terminal := Terminal.new()
var history := [] # array of strings containing all previous entered commands
var history_index := 0 # the position in the history. Except if travelling through the history it will have the size of history as value

func _ready():
	interface.append_bbcode(INIT_TEXT)

# TODO: l'autocomplétion des noms de fichier doit se baser sur le chemin qu'on est en train d'écrire
# TODO: ajout du Token group pour pouvoir faire mkdir baste/{toto,tata}

func _process(_delta):
	if Input.is_action_just_pressed("ui_up") and history_index > 0:
		history_index -= 1
		prompt.text = history[clamp(history_index, 0, history.size() - 1)]
		prompt.grab_focus()
	if Input.is_action_just_pressed("ui_down"):
		if history_index < history.size() - 1:
			history_index += 1
			prompt.text = history[history_index]
			prompt.grab_focus()
		elif prompt.text != "":
			history_index += 1
			prompt.clear()
	if Input.is_action_just_pressed("autocompletion"):
		prompt.grab_focus()
		if not prompt.text.empty():
			var element = terminal.get_pwd_file_element()
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
	var parser = BashParser.new(new_text)
	if not parser.error.empty():
		return _print_error(parser.error)
	var parsing = parser.parse()
	if not parser.error.empty():
		return _print_error(parser.error)
	var standard_input = ""
	for command in parsing:
		var function = terminal.COMMANDS[command.name] if command.name in terminal.COMMANDS else null
		if function == null or not function.reference.is_valid() or command.name.begins_with("_"):
			# Because of the way we handle commands,
			# we must make sure that the user cannot execute functions
			# such as '_process' or '_ready'.
			return _print_error("Cette commande n'existe pas.")
		else:
			var result = function.reference.call_func(command.options, standard_input)
			if result.error != null:
				return _print_error("Commande '" + command.name + "' : " + result.error)
			else:
				if command.name == "clear":
					interface.text = ""
				standard_input = result.output
	if not standard_input.empty():
		interface.append_bbcode(standard_input)

func _print_command(command: String):
	interface.append_bbcode("$ " +  command + "\n")

func _print_error(description: String):
	interface.append_bbcode("[color=red]" + description + "[/color]\n")
