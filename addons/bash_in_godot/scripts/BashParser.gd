extends Object
class_name BashParser

var pid: int
var ctx: BashContext
var error: String = ""

# `p` is the pid to use in case '$$' is used in the input
func _init(context: BashContext, p: int):
	ctx = context
	pid = p

func set_context(context: BashContext) -> void:
	ctx = context

func set_pid(p: int) -> void:
	pid = p

func clear_error() -> void:
	error = ""

# The goal of this function is to identify the commands among the tokens list.
# The very first token must be a PLAIN (the name of the command).
# Every tokens that is after a command's name belongs to this command and will be given as its arguments.
# An input can have multiple commands, each one separated by a pipe (|) or a semicolon (;).
# If they are separated by a pipe, then the standard output of the first one becomes the standard input of the second one.
# If they are separated by a semicolon, then they're completely independant from one another.
# The very next token after a pipe or a semicolon must be a PLAIN (which is the name of the following command).
# For example, the command: "echo -n 'yoyo' | tr y t'
# would give:
# [
#   [
#     {
#       "type": "command",
#       "name": "echo",
#       "options": ["-n", "yoyo"],
#       "redirections": []
#     },
#     {
#       "type": "command"
#       "name": "tr",
#       "options": ["y", "t"],
#       "redirections": []
#     }
#   ]
# ]
# However, the command "echo hello ; echo world" are two different commands that must be executed one after the other.
# If the first one fails, it does not stop the second one from being executed.
# It would give something like this:
# [
#   [
#     {
#       "type": "command",
#       "name": "echo",
#       "options": ["hello"],
#       "redirections": []
#     }
#   ],
#   [
#     {
#       "type": "command"
#       "name": "echo",
#       "options": ["world"],
#       "redirections": []
#     }
#   ]
# ]
# If the command has redirections, it will look something like this:
# "redirections": [{ "port": 1, "type": Tokens.WRITING_REDIRECTION, "target": BashToken(Tokens.PLAIN, "file.txt"), "copied": false }]
# == 1>file.txt
# if "copied" is `true`:
# == 1>&2 (target is the same as the redirection of port 2)
# Also, if this is just a variable affectation (yoyo=5 for example), then:
# [
#   [
#     {
#       "type": "variable",
#       "name": "yo",
#       "value": BashToken
#     }
#   ]
# ]
# Finally, if this is a for loop, then :
# [
#   [
#     {
#       "type": "for",
#       "variable_name": String,
#       "sequences": array of tokens
#       "body": array of tokens
#     }
#   ]
# ]
func parse(input) -> Array:
	var tokens_list := []
	if input is String:
		var lexer := BashLexer.new(input)
		if not lexer.error.empty():
			error = lexer.error
			return []
		tokens_list = lexer.tokens_list
	elif input is Array:
		tokens_list = input
	else:
		error = "Donnée invalides pour le parsing du code."
		return []
	if tokens_list.size() == 1 and tokens_list[0].is_eoi():
		return []
	var i := 0
	var e := 0
	var commands := [[]]
	var number_of_tokens := tokens_list.size()
	# Probably one of the weirdest thing in Bash:
	# variables affectations are ignored when they follow, or are followed by, a pipe.
	# As a consequence, we'll remove from the output of the parsing algorithm all variable affectations,
	# if a pipe is detected within the input.
	var has_pipe := false
	for t in tokens_list:
		if t.is_pipe():
			has_pipe = true
			break
	while i < number_of_tokens:
		if tokens_list[i].is_newline():
			i += 1
			continue
		var r = _parse_command(tokens_list.slice(i, number_of_tokens) if i > 0 else tokens_list)
		if r is String:
			error = r
			return []
		i += r.number_of_read_tokens
		if has_pipe and r.command.type == "variable":
			break
		commands[e].append(r.command)
		if i < number_of_tokens:
			if tokens_list[i].is_pipe():
				i += 1
			elif tokens_list[i].is_eoi():
				break
		if r.should_cut_node:
			i += 1
			if i >= number_of_tokens or tokens_list[i].is_eoi():
				break # ending the command with a semicolon should not throw an error
			commands.append([])
			e += 1
	return commands

func _parse_command(list: Array):
	if list.empty() or list[0].is_eoi():
		return "Erreur de syntaxe : bash attendait une commande mais il n'y a rien."
	if list[0].type != Tokens.PLAIN and list[0].type != Tokens.KEYWORD:
		return "Erreur de syntaxe : le symbole '" + str(list[0].value) + "' n'était pas attendu"
	var is_variable_affectation: bool = list.size() > 1 and list[1].is_equal_sign()
	if is_variable_affectation and not list[0].value.is_valid_identifier():
		return "Erreur de syntaxe : l'identifiant '" + list[0].value + "' n'est pas un nom de variable valide."
	if list[0].is_keyword_and_equals("for"):
		var for_loop = _parse_for_loop(list.slice(1, list.size()))
		if "error" in for_loop:
			return for_loop.error
		var size: int = for_loop.size
		for_loop.erase("size") # we don't need it anymore
		return {
			"number_of_read_tokens": size,
			"should_cut_node": not list[size].is_pipe(),
			"command": for_loop
		}
	var c := {
		"type": "command",
		"name": list[0].value,
		"options": [],
		"redirections": []
	} if not is_variable_affectation else {
		"type": 
		"variable",
		"name": list[0].value,
		"value": null
	}
	var number_of_tokens = list.size()
	var should_cut_node := false
	var found_redirection := false
	var i := 1
	while i < number_of_tokens:
		if list[i].is_pipe() or list[i].is_eoi():
			break
		elif list[i].is_line_separator():
			should_cut_node = true
			break
		else:
			if list[i].is_descriptor():
				var descriptor: int = list[i].value
				i += 1
				var redirection_type: String = list[i].type
				if descriptor == 1 and list[i].is_reading_redirection():
					return "Erreur de syntaxe : le descripteur " + str(descriptor) + " ne peut être en lecture."
				i += 1
				if i >= number_of_tokens:
					return "Erreur de syntaxe : fin inattendue de redirection."
				var copied: bool = false
				var target: BashToken
				if list[i].is_and():
					copied = true
					i += 1
					if i >= number_of_tokens:
						return "Erreur de syntaxe : valeur attendue pour la redirection copiée."
					target = list[i]
				elif list[i].is_plain() or list[i].is_command_substitution():
					target = list[i]
				else:
					return "Erreur de syntaxe : un chemin est attendu après une redirection."
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
					if i < number_of_tokens and list[i].is_line_separator():
						should_cut_node = true
					break # we want to end it now, even if there is another affectation right after ("a=5 b=7")
				else:
					c.options.append(list[i])
		i += 1
	return {
		"number_of_read_tokens": i,
		"should_cut_node": should_cut_node,
		"command": c
	}

# As soon as the parser encounters a FOR keyword,
# this function is called to interpret everything after that.
# The very first token of the list should be the variable name of the syntax.
# As a reminder, the syntax is the following:
# KEYWORD:for TOKEN:PLAIN KEYWORD:in ...(TOKEN:SUB | TOKEN:PLAIN | TOKEN:STRING | TOKEN:VAR) (NL | TOKEN:SEMICOLON)
#       KEYWORD: do (NL)?
#               ...COMMANDS
# KEYWORD:done
# Which is transformed into:
# {
#   "type": "for",
#   "variable_name": String
#   "sequences": the tokens after the 'in' keyword
#   "body": array of tokens (the parse method has to be called later so that the variables inside it don't get interpreted before their initialisation)
#   "size": number of tokens of the for loop (useful to continue the parsing process after the loop)
# }
# If an error occured, only { "error": String } is returned.
func _parse_for_loop(tokens: Array) -> Dictionary:
	var var_name := ""
	var sequences := []
	var number_of_tokens := tokens.size()
	if not tokens[0].is_plain():
		return {
			"error": "Erreur de syntaxe : le nom d'une variable est attendu après le mot-clé 'for'."
		}
	if not tokens[0].value.is_valid_identifier():
		return {
			"error": "Erreur de syntaxe : le nom de la variable de contrôle de la boucle 'for' n'est pas valide."
		}
	var_name = tokens[0].value
	if not tokens[1].is_keyword_and_equals("in"):
		return {
			"error": "Erreur de syntaxe : le mot-clé 'in' est attendu après la variable de contrôle de la boucle 'for'."
		}
	var i := 2
	while i < number_of_tokens and not tokens[i].is_line_separator():
		if not tokens[i].is_valid_token_in_for_loop():
			return {
				"error": "Erreur de syntaxe : le symbole '" + str(tokens[i].value) + "' n'est pas valide pour une boucle 'for'."
			}
		sequences.append(tokens[i])
		i += 1
	if sequences.empty():
		return {
			"error": "Erreur de syntaxe : des valeurs sont attendues sur lesquelles itérer avec la boucle 'for'."
		}
	i += 1 # jump over the semicolon/newline
	if i >= number_of_tokens:
		return {
			"error": "Erreur de syntaxe : le corps de la boucle 'for' est attendu."
		}
	if not tokens[i].is_keyword_and_equals("do"):
		return {
			"error": "Erreur de syntaxe : le mot-clé 'do' est attendu après la définition de la boucle."
		}
	i += 1 # jump over the `do` keyword
	# Now we have to parse everything that is inside of the body
	# I'm just giving all the tokens before the one that corresponds to the closing `done` keyword.
	# Note that we may have loops inside loops !!
	var done_keywords := 1 # exactly like we'd do with parenthesis, we'll stop the process as soon as the right loop gets closed.
	var beginning_index_of_body := i
	while i < number_of_tokens and done_keywords > 0:
		if tokens[i].is_keyword_and_equals("for"):
			done_keywords += 1
		elif tokens[i].is_keyword_and_equals("done"):
			done_keywords -= 1
		i += 1
	if done_keywords != 0:
		return {
			"error": "La boucle for n'a pas été fermée."
		}
	var body = tokens.slice(beginning_index_of_body, i - 2)
	return {
		"type": "for",
		"variable_name": var_name,
		"sequences": sequences,
		"body": body,
		"size": i + 1
	}
