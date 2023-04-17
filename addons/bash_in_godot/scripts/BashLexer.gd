extends Object
class_name BashLexer

var command: String
var tokens_list := []
var error := ""

# `c` is the input
func _init(c: String):
	command = c.strip_edges()
	tokens_list = read(command)

func reset() -> void:
	command = ""
	tokens_list = []

# Transforms the input as a list of tokens
# so that it is easier to read for an algorithm.
# It eliminates the problem of the unlimited white space delimiter for example.
# For example:
# input="echo "yoyo" | tr y t"
# would give [PLAIN, STRING, PIPE, PLAIN, PLAIN, PLAIN]
# the very first item of the list is the name of a command, and the first "PLAIN" after a PIPE is also a command
func read(input: String) -> Array:
	if input.empty():
		return [BashToken.new(Tokens.EOI, null)]
	var pos := 0
	var result := []
	var length := input.length()
	var can_accept_variable := true # a variable affectation must be the very first thing on the line, but note that "a=5 b=6" is possible
	while pos < length:
		if input[pos] == " " or input[pos] == "\t":
			pos += 1
			continue
		# Before adding the for loops, 
		# everything had to be on one line,
		# but now we have to consider the possibility
		# of having a multi-line nodes such as loops.
		elif input[pos] == "\n":
			# If there are several new-line tokens at the same time,
			# then just ignore them and append to the result only the first one
			if result.size() > 0 and result[-1].is_newline():
				pos += 1
				continue
			result.append(BashToken.new(Tokens.NL, 'nl'))
		elif input[pos] == ";":
			result.append(BashToken.new(Tokens.SEMICOLON, ';'))
		elif input[pos] == "$":
			pos += 1
			if pos >= length or input[pos] == " ":
				result.append(BashToken.new(Tokens.PLAIN, "$"))
				break
			elif input[pos] == "$":
				result.append(BashToken.new(Tokens.VARIABLE, "$")) # the pid number ($$)
			elif input[pos] == "(": # substitution
				pos += 1
				var parenthesis_count = 1 # when it reaches 0 it means the right parenthesis was closed
				var subtitution_content := ""
				while pos < length and parenthesis_count > 0:
					if input[pos] == "(":
						parenthesis_count += 1
					elif input[pos] == ")":
						parenthesis_count -= 1
						if parenthesis_count == 0: # we break right away because we don't want the final parenthesis to be in the `substitution_content`.
							pos += 1
							break
					elif _is_char_quote(input[pos]): # we don't want to count the parenthesis a string might contain
						var parsed_string = _read_string(input.right(pos))
						if not parsed_string.string_closed:
							error = "Erreur de syntaxe : une chaine de caractères n'a pas été fermée."
							return []
						else:
							pos += parsed_string.value.length() + 2
						subtitution_content += parsed_string.quote + parsed_string.value + parsed_string.quote
						continue
					subtitution_content += input[pos]
					pos += 1
				if parenthesis_count != 0:
					error = "Erreur de syntaxe : une substitution de commande n'a pas été fermée."
					return []
				result.append(BashToken.new(Tokens.SUBSTITUTION, subtitution_content))
			else:
				var name = _read_identifier(input, pos, length, false)
				if name.token.value.is_valid_identifier():
					result.append(BashToken.new(Tokens.VARIABLE, name.token.value))
				else:
					# if the identifier is not valid,
					# return a PLAIN token with value "$" + the identifier
					result.append(BashToken.new(Tokens.PLAIN, "$" + name.token.value))
				pos = name.pos
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
			result.append(BashToken.new(Tokens.AND, '&'))
			pos += 1
			while pos < length and input[pos] == " ":
				pos += 1
			if pos >= length:
				error = "Erreur de syntaxe : descripteur attendu après une telle redirection"
				return []
			var d_value: String = input[pos]
			# it might be a variable,
			# or a command substitution
			if d_value == "$":
				continue
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
			result.append(BashToken.new(Tokens.PIPE, '|'))
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
			if identifier.token.value in Tokens.KEYWORDS:
				result.append(BashToken.new(Tokens.KEYWORD, identifier.token.value))
				pos = identifier.pos
				continue
			result.append(identifier.token)
			pos = identifier.pos
			if pos < length and input[pos] == "=":
				pos += 1
				if can_accept_variable:
					result.append(BashToken.new(Tokens.EQUALS, '='))
					if pos < length:
						if _is_char_quote(input[pos]):
							var string = _read_string(input.right(pos))
							if not string.string_closed:
								error = "Erreur de syntaxe : une chaine de caractères n'a pas été fermée lors de la création d'une variable."
								return []
							else:
								pos += string.value.length() + 2
							result.append(BashToken.new(Tokens.STRING, string.value, { "quote": string.quote }))
						else:
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
	result.append(BashToken.new(Tokens.EOI, null))
	return result

# Reads a word, a path (something that isn't anything else)
func _read_identifier(input: String, pos: int, length: int, count_equals_sign: bool) -> Dictionary:
	var identifier := ""
	if count_equals_sign: # we want to include "=" in the identifier
		while pos < length and (not input[pos] in [" ", "$", ">", "<", ">>", "\n"]):
			identifier += input[pos]
			pos += 1
	else: # we don't want to include the "=" in the indentifier (hence stopping as soon as we encounter one)
		while pos < length and (not input[pos] in [" ", "$", ">", "<", ">>", "=", "\n"]):
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
				"token": BashToken.new(Tokens.APPEND_WRITING_REDIRECTION, '>>'),
				"error": null,
				"pos": pos
			}
		else:
			return {
				"token": BashToken.new(Tokens.WRITING_REDIRECTION, '>'),
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
				"token": BashToken.new(Tokens.READING_REDIRECTION, '<'),
				"error": null,
				"pos": pos - 1
			}
	else:
		return {
			"token": null,
			"error": null,
			"pos": pos
		}

func _is_char_quote(character: String) -> bool:
	return character == '"' or character == "'"

func _to_string():
	return str(tokens_list)
