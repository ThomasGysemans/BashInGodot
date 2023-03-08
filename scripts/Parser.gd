extends Object
class_name Parser

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
		return [Token.new(Tokens.EOF, null)]
	var pos := 0
	var result := []
	var length = input.length()
	while pos < length:
		if input[pos] == " ":
			pos += 1
			continue
		elif _is_char_quote(input[pos]):
			var parsed_string = _read_string(input.right(pos))
			if not parsed_string.string_closed:
				error = "Erreur de syntaxe : une chaine de caractères n'a pas été fermée."
				return []
			else:
				pos += parsed_string.value.length() + 2
			result.append(Token.new(Tokens.STRING, parsed_string.value))
		elif input[pos] == "|":
			result.append(Token.new(Tokens.PIPE, null))
		elif input[pos] == "-":
			pos += 1
			if pos >= length or input[pos] == " ":
				result.append(Token.new(Tokens.PLAIN, "-"))
			else:
				if input[pos] == "-":
					pos += 1
					var flag_name = ""
					while pos < length and input[pos] != " ":
						flag_name += input[pos]
						pos += 1
					if flag_name.empty():
						result.append(Token.new(Tokens.PLAIN, "--"))
					else:
						result.append(Token.new(Tokens.LONG_FLAG, flag_name))
				else:
					result.append(Token.new(Tokens.FLAG, input[pos]))
					pos += 1
					if pos < length and input[pos] != " ":
						error = "Erreur de syntaxe : l'option '" + input[pos - 1] + "' est trop grande."
						return []
		else: # an identifier (Tokens.PLAIN)
			var identifier = ""
			while pos < length and input[pos] != " ":
				identifier += input[pos]
				pos += 1
			result.append(Token.new(Tokens.PLAIN, identifier))
		pos += 1
	result.append(Token.new(Tokens.EOF, null))
	return result

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
				string_opener = content[cursor]
		if content[cursor] != "\\":
			result += content[cursor]	
		cursor += 1
	return {
		"value": result.strip_edges().substr(1, result.length() - 1),
		"string_closed": closed
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
#     "options": ["-n", "yoyo"]
#   },
#   {
#     "name": "tr",
#     "options": ["y", "t"]
#   }
# ]
func parse() -> Array:
	var i := 0
	var commands := []
	var number_of_tokens := tokens_list.size()
	while i < number_of_tokens:
		var c = _parse_command(tokens_list.slice(i, number_of_tokens) if i > 0 else tokens_list)
		if c is String:
			error = c
			return []
		commands.append(c)
		i += c.options.size() + 1
		if i < number_of_tokens:
			if tokens_list[i].is_pipe():
				i += 1
			elif tokens_list[i].is_eof():
				break
	return commands

func _parse_command(list:Array):
	if list.size() == 0 or list[0].is_eof():
		return "Erreur de syntaxe : BASH attendait une commande mais il n'y a rien."
	if list[0].type != Tokens.PLAIN:
		return "Erreur de syntaxe : '" + str(list[0].value) + "' n'est pas une commande."
	var c := { "name": list[0].value, "options": [] }
	for i in range(1, list.size()):
		if list[i].is_pipe() or list[i].is_eof():
			return c
		c.options.append(list[i])
	return c

func _is_char_quote(character: String) -> bool:
	return character == '"' or character == "'"

func _to_string():
	return str(tokens_list)
