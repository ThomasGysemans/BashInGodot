extends Object
class_name BashToken

var type: String
var value = null # just a few tokens can have a null value`. Even when it's useless, it is best for the error mesages
var metadata = null # metadata will be null for all tokens except for STRING because we need to know what quotes were used.

func _init(t: String, v, m = null):
	type = t
	value = v
	metadata = m

func is_plain() -> bool:
	return type == Tokens.PLAIN

func is_flag() -> bool:
	return type == Tokens.FLAG or type == Tokens.LONG_FLAG

func is_negative_digit() -> bool:
	if type == Tokens.FLAG:
		if value.is_valid_integer():
			return int("-" + value) < 0
		else:
			return false
	return false

func is_flag_and_equals(name: String):
	return is_flag() and value == name

func is_string() -> bool:
	return type == Tokens.STRING

func is_word() -> bool:
	return is_string() or is_plain()

func is_pipe() -> bool:
	return type == Tokens.PIPE

func is_eoi() -> bool:
	return type == Tokens.EOI

func is_descriptor() -> bool:
	return type == Tokens.DESCRIPTOR

func is_descriptor_and_equals(number: int) -> bool:
	return type == Tokens.DESCRIPTOR and value == number

func is_writing_redirection() -> bool:
	return type == Tokens.WRITING_REDIRECTION

func is_append_writing_redirection() -> bool:
	return type == Tokens.APPEND_WRITING_REDIRECTION

func is_reading_redirection() -> bool:
	return type == Tokens.READING_REDIRECTION

func is_redirection() -> bool:
	return is_writing_redirection() or is_append_writing_redirection() or is_reading_redirection()

func is_equal_sign() -> bool:
	return type == Tokens.EQUALS

func is_variable() -> bool:
	return type == Tokens.VARIABLE

func is_keyword() -> bool:
	return type == Tokens.KEYWORD

func is_keyword_and_equals(keyword: String) -> bool:
	return is_keyword() and value == keyword

# (n)>&(m)
func is_and() -> bool:
	return type == Tokens.AND

func is_command_substitution() -> bool:
	return type == Tokens.SUBSTITUTION

func is_semicolon() -> bool:
	return type == Tokens.SEMICOLON

func is_newline() -> bool:
	return type == Tokens.NL

func is_line_separator() -> bool:
	return is_newline() or is_semicolon()

func is_valid_token_in_for_loop() -> bool:
	return is_plain() or is_string() or is_variable() or is_command_substitution()

func equals(another: BashToken) -> bool:
	if self == another: return true
	return self.type == another.type and self.value == another.value and self.metadata == another.metadata

func _to_string():
	return "[" + type + ":" + str(value) + ("(" + str(metadata) + ")" if metadata != null else "") + "]"
