#warning-ignore-all:return_value_discarded
extends Panel

const INIT_TEXT = "Terminal M100 1.0.\nLe terminal fait maison [b]simplifié[/b].\nEntrez \"help\" si vous avez besoin d'aide.\n-----------------\n"

export(String) var user_name
export(String) var group_name

onready var interface: RichTextLabel = $Interface; # the terminal
onready var prompt: LineEdit = $Prompt; # the input

var terminal := Terminal.new()
var history := [] # array of strings containing all previous entered commands
var history_index := 0 # the position in the history. Except if travelling through the history it will have the size of history as value

func _ready():
	if user_name != null:
		terminal.user_name = user_name
	if group_name != null:
		terminal.group_name = group_name
	terminal.set_root([
		SystemElement.new(0, "file.txt", "/", "Ceci est le contenu du fichier.", [], user_name, group_name),
		SystemElement.new(1, "folder", "/", "", [
			SystemElement.new(0, "answer_to_life.txt", "/folder", "42", [], user_name, group_name),
			SystemElement.new(0, ".secret", "/folder", "this is a secret", [], user_name, group_name)
		], user_name, group_name)
	])
	interface.append_bbcode(INIT_TEXT)

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
			var possibilites := [] # array of string containing the possible names to autocomplete with
			var word_position := prompt.text.find_last(" ")
			if word_position == -1:
				word_position = 0
			var full_path := prompt.text.right(word_position).strip_edges()
			var base_dir := full_path.left(full_path.find("/")) + "/" if full_path.find("/") != -1 else ""
			var word_to_complete := ""
			if full_path.find("/") != -1:
				word_to_complete = full_path.right(full_path.find("/") + 1)
			else:
				word_to_complete = full_path
			var element = terminal.get_parent_element_from(PathObject.new(full_path)) if not word_to_complete.empty() else terminal.get_file_element_at(PathObject.new(full_path))
			if not element.can_read():
				return # cannot autocomplete with the files contained in a folder we can't read from
			for child in element.children:
				if child.filename.begins_with(word_to_complete):
					possibilites.append(child.filename)
			if possibilites.size() > 0:
				if possibilites.size() == 1:
					prompt.text = (prompt.text.substr(0, word_position) + " " + base_dir + possibilites[0]).strip_edges()
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
					prompt.text = (prompt.text.substr(0, word_position) + " " + base_dir + word).strip_edges()
				prompt.grab_focus()
				prompt.set_cursor_position(prompt.text.length())

func _on_command_entered(new_text: String):
	prompt.clear()
	history.append(new_text)
	history_index = history.size()
	_print_command(new_text)
	var result := terminal.execute(new_text, interface)
	if not result.empty():
		_print_error(result)

func _print_command(command: String):
	interface.append_bbcode("$ " +  command + "\n")

func _print_error(description: String):
	interface.append_bbcode("[color=red]" + description + "[/color]\n")
