extends Object
class_name BashToken

var type: String
var value = null

func _init(t: String, v):
	type = t
	value = v

func is_plain() -> bool:
	return type == Tokens.PLAIN

func is_flag() -> bool:
	return type == Tokens.FLAG or type == Tokens.LONG_FLAG

func is_flag_and_equals(name: String):
	return is_flag() and value == name

func is_word() -> bool:
	return type == Tokens.STRING or is_plain()

func is_pipe() -> bool:
	return type == Tokens.PIPE

func is_eof() -> bool:
	return type == Tokens.EOF

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

# (n)>&(m)
func is_and() -> bool:
	return type == Tokens.AND

func _to_string():
	return "[" + type + ":" + str(value) + "]"
