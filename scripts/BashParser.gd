extends Object
class_name BashParser

var command: String
var tokens_list := []
var error := ""

func _init(c: String):
	command = c.strip_edges()
	tokens_list = _read(command)

# Transforms the input as a list of tokens
# so that it is easier to read for an algorithm.
# It eliminates the problem of the unlimited white space delimiter for example.
# For example:
# input="echo "yoyo" | tr y t"
# would give [PLAIN, STRING, PIPE, PLAIN, PLAIN, PLAIN]
# the very first item of the list is the name of a command, and the first "PLAIN" after a PIPE is also a command
func _read(input: String) -> Array:
	if input.empty():
		return [BashToken.new(Tokens.EOF, null)]
	var pos := 0
	var result := []
	var length := input.length()
	while pos < length:
		if input[pos] == " ":
			pos += 1
			continue
		elif input[pos] == "0" or input[pos] == "1" or input[pos] == "2":
			var descriptor := input[pos]
			var word_pos := pos
			pos += 1
			while pos < length and input[pos] == " ":
				pos += 1
			if pos >= length:
				result.append(BashToken.new(Tokens.PLAIN, descriptor))
				break
			var redirection := _read_redirection(input, pos, length)
			if redirection.error != null:
				error = redirection.error
				return []
			else:
				# It was actually an identifier starting with this number
				if redirection.token == null:
					var identifier := _read_identifier(input, word_pos, length)
					result.append(identifier.token)
					pos = identifier.pos
					continue
				else:
					result.append(BashToken.new(Tokens.DESCRIPTOR, int(descriptor)))
					result.append(redirection.token)
				pos = redirection.pos
		elif input[pos] == ">" or input[pos] == "<":
			var redirection := _read_redirection(input, pos, length)
			if redirection.error != null:
				error = redirection.error
				return []
			else:
				result.append(redirection.token)
				pos = redirection.pos
		elif input[pos] == "&":
			result.append(BashToken.new(Tokens.AND, null))
			pos += 1
			while pos < length and input[pos] == " ":
				pos += 1
			if pos >= length:
				error = "Erreur de syntaxe : descripteur attendu après une telle redirection"
				return []
			var d_value: String = input[pos]
			if d_value == "0" or d_value == "1" or d_value == "2":
				result.append(BashToken.new(Tokens.DESCRIPTOR, int(d_value)))
				pos += 1
			else:
				error = "Erreur de syntaxe : les descripteurs valides sont 0, 1 ou 2."
				return []
			continue
		elif _is_char_quote(input[pos]):
			var parsed_string = _read_string(input.right(pos))
			if not parsed_string.string_closed:
				error = "Erreur de syntaxe : une chaine de caractères n'a pas été fermée."
				return []
			else:
				pos += parsed_string.value.length() + 2
			result.append(BashToken.new(Tokens.STRING, parsed_string.value))
		elif input[pos] == "|":
			result.append(BashToken.new(Tokens.PIPE, null))
		elif input[pos] == "-":
			pos += 1
			if pos >= length or input[pos] == " ":
				result.append(BashToken.new(Tokens.PLAIN, "-"))
			else:
				if input[pos] == "-":
					pos += 1
					var flag_name = ""
					while pos < length and input[pos] != " ":
						flag_name += input[pos]
						pos += 1
					if flag_name.empty():
						result.append(BashToken.new(Tokens.PLAIN, "--"))
					else:
						result.append(BashToken.new(Tokens.LONG_FLAG, flag_name))
				else:
					result.append(BashToken.new(Tokens.FLAG, input[pos]))
					pos += 1
					while pos < length and input[pos] != " ":
						result.append(BashToken.new(Tokens.FLAG, input[pos]))
						pos += 1
		else: # an identifier (Tokens.PLAIN)
			var identifier := _read_identifier(input, pos, length)
			result.append(identifier.token)
			pos = identifier.pos
		pos += 1
	result.append(BashToken.new(Tokens.EOF, null))
	return result

# Reads a word, a path (something that isn't anything else)
func _read_identifier(input: String, pos: int, length: int) -> Dictionary:
	var identifier := ""
	while pos < length and input[pos] != " ":
		identifier += input[pos]
		pos += 1
	return {
		"token": BashToken.new(Tokens.PLAIN, identifier),
		"pos": pos
	}

# Reads a string ("yo", 'yo')
func _read_string(content: String):
	var cursor := 0
	var string_opener := ""
	var result := ""
	var closed := false
	while cursor < content.length():
		if _is_char_quote(content[cursor]):
			if content[cursor] == string_opener:
				if content[cursor - 1] != "\\":
					closed = true
					break
			else:
				if string_opener.empty():
					string_opener = content[cursor]
		if content[cursor] != "\\":
			result += content[cursor]	
		cursor += 1
	return {
		"value": result.strip_edges().substr(1, result.length() - 1),
		"string_closed": closed
	}

# When we are executing this function, it's because we've just seen a number (0, 1 or 2).
# `pos` is therefore the next character.
# The goal is now to check if this number is part of a redirection.
# If it is, it needs to output the token (<, > or >>).
# It returns a dictionary {"token": BashToken or nul, "pos": int, "error": String or null}
# "token" can be null of it's not a redirection ('echo 2' for example should not interpreted as a redirection)
func _read_redirection(input: String, pos: int, length: int) -> Dictionary:
	if input[pos] == ">":
		pos += 1
		if pos >= length:
			return {
				"error": "fin de redirection inattendue"
			}
		if input[pos] == ">":
			return {
				"token": BashToken.new(Tokens.APPEND_WRITING_REDIRECTION, null),
				"error": null,
				"pos": pos
			}
		else:
			return {
				"token": BashToken.new(Tokens.WRITING_REDIRECTION, null),
				"error": null,
				"pos": pos - 1
			}
	elif input[pos] == "<":
		pos += 1
		if pos >= length:
			return {
				"error": "fin de redirection inattendue"
			}
		if input[pos] == "<":
			return {
				"error": "Erreur de support : la redirection '<<' n'est pas prise en charge car incompréhensible, sorry!"
			}
		else:
			return {
				"token": BashToken.new(Tokens.READING_REDIRECTION, null),
				"error": null,
				"pos": pos - 1
			}
	else:
		return {
			"token": null,
			"error": null,
			"pos": pos
		}

# The goal of this function is to identify the commands among the tokens list.
# The very first token must be a PLAIN (the name of the command).
# Every tokens that is after a command's name belongs to this command and will be given as its arguments.
# A command can have multiple subcommands, each one separated by a pipe (|).
# The very next token after a pipe must be a PLAIN (which is the name of the following command).
# For example, the command: "echo -n 'yoyo' | tr y t'
# would give:
# [
#   {
#     "name": "echo",
#     "options": ["-n", "yoyo"],
#     "redirections": []
#   },
#   {
#     "name": "tr",
#     "options": ["y", "t"],
#     "redirections": []
#   }
# ]
# If the command has redirections, it will look something like this:
# { "port": 1, "type": Tokens.WRITING_REDIRECTION, "target": "file.txt", "copied": false }
# == 1>file.txt
# if "copied" is `true`:
# == 1>&2 (target is the same as the redirection of port 2)
func parse() -> Array:
	var i := 0
	var commands := []
	var number_of_tokens := tokens_list.size()
	while i < number_of_tokens:
		var r = _parse_command(tokens_list.slice(i, number_of_tokens) if i > 0 else tokens_list)
		if r is String:
			error = r
			return []
		commands.append(r.command)
		i += r.number_of_read_tokens
		if i < number_of_tokens:
			if tokens_list[i].is_pipe():
				i += 1
			elif tokens_list[i].is_eof():
				break
	return commands

func _parse_command(list:Array):
	if list.empty() or list[0].is_eof():
		return "Erreur de syntaxe : BASH attendait une commande mais il n'y a rien."
	if list[0].type != Tokens.PLAIN:
		return "Erreur de syntaxe : '" + str(list[0].value) + "' n'est pas une commande."
	var c := { "name": list[0].value, "options": [], "redirections": [] }
	var i := 1
	var found_redirection := false
	var number_of_tokens = list.size()
	while i < number_of_tokens:
		if list[i].is_pipe() or list[i].is_eof():
			break
		elif list[i].is_descriptor():
			var descriptor: int = list[i].value
			i += 1
			var redirection_type: String = list[i].type
			if descriptor == 1 and list[i].is_reading_redirection():
				return "Erreur de syntaxe : le descripteur " + str(descriptor) + " ne peut être en lecture."
			i += 1
			if i >= number_of_tokens:
				return "Erreur de syntaxe : fin inattendue de redirection."
			var copied: bool = false
			var target = null # a String if there is no copy, an integer otherwise
			if list[i].is_and():
				copied = true
				i += 1
				target = list[i].value
			elif list[i].is_plain():
				target = list[i].value
			else:
				return "Erreur de syntaxe : un chemin est attendu après une redirection"
			c.redirections.append({
				"port": descriptor,
				"type": redirection_type,
				"target": target,
				"copied": copied
			})
			found_redirection = true
		else:
			if found_redirection:
				return "Erreur de syntaxe : fin de commande attendue"
			c.options.append(list[i])
		i += 1
	return {
		"number_of_read_tokens": i,
		"command": c
	}

func _is_char_quote(character: String) -> bool:
	return character == '"' or character == "'"

func _to_string():
	return str(tokens_list)
