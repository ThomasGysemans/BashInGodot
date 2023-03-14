extends Object
class_name BashToken

var type: String
var value = null

func _init(t: String, v):
	type = t
	value = v

func is_flag() -> bool:
	return type == Tokens.FLAG or type == Tokens.LONG_FLAG

func is_flag_and_equals(name: String):
	return is_flag() and value == name

func is_word() -> bool:
	return type == Tokens.STRING or type == Tokens.PLAIN

func is_pipe() -> bool:
	return type == Tokens.PIPE

func is_eof() -> bool:
	return type == Tokens.EOF

func _to_string():
	return "[" + type + ":" + str(value) + "]"
