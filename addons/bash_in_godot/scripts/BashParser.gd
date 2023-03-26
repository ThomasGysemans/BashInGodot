extends Object
class_name BashParser

var command: String
var tokens_list := []
var error := ""
var pid := 42

func _init(c: String, p: int):
	command = c.strip_edges()
	tokens_list = _read(command)
	pid = p

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
	var can_accept_variable := true # a variable affectation must be the very first thing on the line, but note that "a=5 b=6" is possible
	while pos < length:
		if input[pos] == " ":
			pos += 1
			continue
		elif input[pos] == "$":
			pos += 1
			if pos >= length or input[pos] == " ":
				result.append(BashToken.new(Tokens.PLAIN, "$"))
				break
			elif input[pos] == "$":
				result.append(BashToken.new(Tokens.VARIABLE, "$")) # the pid number ($$)
			else:
				var name = _read_identifier(input, pos, length, false)
				if name.token.value.is_valid_identifier():
					result.append(BashToken.new(Tokens.VARIABLE, name.token.value))
				else:
					# if the identifier is not valid,
					# return a PLAIN token with value "$" + the identifier
					result.append(BashToken.new(Tokens.PLAIN, "$" + name.token.value))
				pos = name.pos
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
					var identifier := _read_identifier(input, word_pos, length, true)
					result.append(identifier.token)
					pos = identifier.pos
					continue
				else:
					result.append(BashToken.new(Tokens.DESCRIPTOR, int(descriptor)))
					result.append(redirection.token)
				pos = redirection.pos
		elif input[pos] == ">" or input[pos] == "<":
			if input[pos] == ">":
				result.append(BashToken.new(Tokens.DESCRIPTOR, 1)) # default redirection for ">" or ">>"
			else:
				result.append(BashToken.new(Tokens.DESCRIPTOR, 0)) # default redirection for "<" or "<<"
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
			result.append(BashToken.new(Tokens.STRING, parsed_string.value, { "quote": parsed_string.quote }))
		elif input[pos] == "|":
			result.append(BashToken.new(Tokens.PIPE, null))
			can_accept_variable = true # echo yoyo | yoyo=55 is possible
		elif input[pos] == "-":
			pos += 1
			if pos >= length or input[pos] == " ":
				result.append(BashToken.new(Tokens.PLAIN, "-"))
			elif input[pos] == "$":
				result.append(BashToken.new(Tokens.PLAIN, "-"))
				continue
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
					# We want -la to become two tokens: -l and -a
					# We want -3 to be a token too,
					# however we want -30 to be a PLAIN token
					if (pos + 1) < length and (input[pos] + input[pos+1]).is_valid_integer():
						result.append(BashToken.new(Tokens.PLAIN, "-" + input[pos] + input[pos+1]))
						pos += 2
						continue
					result.append(BashToken.new(Tokens.FLAG, input[pos]))
					pos += 1
					while pos < length and input[pos] != " ":
						result.append(BashToken.new(Tokens.FLAG, input[pos]))
						pos += 1
		else: # an identifier (Tokens.PLAIN), which might also be a variable affectation
			var identifier := _read_identifier(input, pos, length, !can_accept_variable)
			if identifier.token.value.empty(): # in case we have input = "=2"
				can_accept_variable = false
				continue
			result.append(identifier.token)
			pos = identifier.pos
			if pos < length and input[pos] == "=":
				pos += 1
				if can_accept_variable:
					result.append(BashToken.new(Tokens.EQUALS, null))
					if pos < length:
						var value = _read_identifier(input, pos, length, true)
						result.append(value.token)
						pos = value.pos + 1
					else:
						result.append(BashToken.new(Tokens.PLAIN, "")) # it's possible to write "variable="
				else:
					if pos < length and input[pos] != " ":
						var next = _read_identifier(input, pos, length, true)
						result[-1].value += "=" + next.token.value
						pos = next.pos + 1
			else:
				can_accept_variable = false # meaning it was something else, so after that no variable affectation can be made.
			continue
		pos += 1
	result.append(BashToken.new(Tokens.EOF, null))
	return result

# Reads a word, a path (something that isn't anything else)
func _read_identifier(input: String, pos: int, length: int, count_equals_sign: bool) -> Dictionary:
	var identifier := ""
	if count_equals_sign: # we want to include "=" in the identifier
		while pos < length and input[pos] != " " and input[pos] != "$":
			identifier += input[pos]
			pos += 1
	else: # we don't want to include the "=" in the indentifier (hence stopping as soon as we encounter one)
		while pos < length and input[pos] != " " and input[pos] != "$" and input[pos] != "=":
			identifier += input[pos]
			pos += 1
	return {
		"token": BashToken.new(Tokens.PLAIN, identifier),
		"pos": pos
	}

# Reads a string ("yo", 'yo')
func _read_string(content: String):
	var cursor := 0
	var quote := ""
	var result := ""
	var closed := false
	while cursor < content.length():
		if _is_char_quote(content[cursor]):
			if content[cursor] == quote:
				if content[cursor - 1] != "\\":
					closed = true
					break
			else:
				if quote.empty():
					quote = content[cursor]
		if content[cursor] != "\\":
			result += content[cursor]	
		cursor += 1
	return {
		"value": result.strip_edges().substr(1, result.length() - 1),
		"string_closed": closed,
		"quote": quote
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
#     "type": "command",
#     "name": "echo",
#     "options": ["-n", "yoyo"],
#     "redirections": []
#   },
#   {
#     "type": "command"
#     "name": "tr",
#     "options": ["y", "t"],
#     "redirections": []
#   }
# ]
# If the command has redirections, it will look something like this:
# "redirections": [{ "port": 1, "type": Tokens.WRITING_REDIRECTION, "target": "file.txt", "copied": false }]
# == 1>file.txt
# if "copied" is `true`:
# == 1>&2 (target is the same as the redirection of port 2)
# Finally, if the line is just a variable affectation (yoyo=5 for example), then:
# [
#   {
#     "type": "variable",
#     "name": "yo",
#     "value": BashToken
#   }
# ]
func parse(context: BashContext) -> Array:
	var i := 0
	var commands := []
	var number_of_tokens := tokens_list.size()
	var interpreted_tokens_list := interpret_tokens_variables_with(context)
	# Probably one of the weirdest thing in Bash:
	# variables affectations are ignored when they follow, or are followed by, a pipe.
	# As a consequence, we'll remove from the output of the parsing algorithm all variable affectations.
	var has_pipe := false
	for t in interpreted_tokens_list:
		if t.is_pipe():
			has_pipe = true
			break
	while i < number_of_tokens:
		var r = _parse_command(interpreted_tokens_list.slice(i, number_of_tokens) if i > 0 else interpreted_tokens_list)
		if r is String:
			error = r
			return []
		i += r.number_of_read_tokens
		if has_pipe and r.command.type == "variable":
			break
		commands.append(r.command)
		if i < number_of_tokens:
			if interpreted_tokens_list[i].is_pipe():
				i += 1
			elif interpreted_tokens_list[i].is_eof():
				break
	return commands

func _parse_command(list: Array):
	if list.empty() or list[0].is_eof():
		return "Erreur de syntaxe : BASH attendait une commande mais il n'y a rien."
	if list[0].type != Tokens.PLAIN:
		return "Erreur de syntaxe : '" + str(list[0].value) + "' n'est pas une commande."
	var is_variable_affectation: bool = list.size() > 1 and list[1].is_equal_sign()
	if is_variable_affectation and not list[0].value.is_valid_identifier():
		return "Erreur de syntaxe : l'identifiant '" + list[0].value + "' n'est pas un nom de variable valide."
	var c := { "type": "command", "name": list[0].value, "options": [], "redirections": [] } if not is_variable_affectation else { "type": "variable", "name": list[0].value, "value": null }
	var number_of_tokens = list.size()
	var found_redirection := false
	var i := 1
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
			if list[i].is_equal_sign():
				i += 1 # ignoring the "="
				c.value = list[i] # getting the value, and even if the value is empty ("a=") it will have a PLAIN token afterwards
				i += 1 # jumping over the value
				break # we want to end it now, even if there is another affectation right after ("a=5 b=7")
			else:
				c.options.append(list[i])
		i += 1
	return {
		"number_of_read_tokens": i,
		"command": c
	}

func interpret_tokens_variables_with(context: BashContext) -> Array:
	var list := []
	for i in range(0, tokens_list.size()):
		var token = tokens_list[i]
		if token.is_variable():
			# If multiple variables are chained like this: "$$$yoyo"
			# then we want a single token representing the concatenation of their value.
			# To do that, If we detect that the previous token that we interpreted was also a variable,
			# then we add to the value of the previous interpreted token the interpreted value of the current token.
			var value: String = str(pid) if token.value == "$" else context.get_variable_value(token.value)
			if i > 0 and tokens_list[i-1].is_variable():
				list[i-1].value += value
			else:
				list.append(BashToken.new(Tokens.PLAIN, value))
		elif token.is_string():
			if token.metadata.quote == "'":
				list.append(token)
			else:
				list.append(interpret_string(token, context))
		elif token.is_plain() and token.value == "$$":
			list.append(BashToken.new(Tokens.PLAIN, str(pid)))
		else:
			list.append(token)
	return list

func interpret_string(token: BashToken, context) -> BashToken:
	var identifier := ""
	var identifier_pos := 0
	var i := 0
	var value_to_add := ""
	var new_token := BashToken.new(Tokens.STRING, "", { "quote": '"' })
	while i < token.value.length():
		if token.value[i] == "$":
			identifier_pos = i
			i += 1
			if i >= token.value.length():
				new_token.value += "$"
				break
			if token.value[i] == "$":
				identifier = "$$"
				i += 1
			elif token.value[i] == " ":
				new_token.value += "$"
				continue
			else:
				while i < token.value.length() and token.value[i] != " ":
					if not (identifier + token.value[i]).is_valid_identifier():
						break
					identifier += token.value[i]
					i += 1
			if identifier == "$$":
				value_to_add = str(pid)
			else:
				value_to_add = context.get_variable_value(identifier)
			new_token.value += value_to_add
			identifier = ""
		else:
			new_token.value += token.value[i]
			i += 1
	return new_token

func _is_char_quote(character: String) -> bool:
	return character == '"' or character == "'"

func _to_string():
	return str(tokens_list)
