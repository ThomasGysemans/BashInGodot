extends Object
class_name BashContext

# Each context will be an array of dictionaries:
# [{ name: String, token: Token }]
# Note that the default value of a variable in Bash is an empty string
# (so it's the value that is returned when the variable doesn't exist).
var context := []

# Sets the value of a variable.
# If it doesn't exist, it's created.
# Returns true if the variable was created, false otherwise.
func set_variable(name: String, token: BashToken) -> bool:
	var new_value = int(token.value) if token.value.is_valid_integer() else (float(token.value) if token.value.is_valid_float() else token.value)
	var new_token = BashToken.new(token.type, new_value)
	for variable in context:
		if variable.name == name:
			variable.token = new_token
			return false
	context.append({
		"name": name,
		"token": new_token
	})
	return true

# Returns an empty string by default.
func get_variable_value(name: String) -> String:
	for variable in context:
		if variable.name == name:
			return str(variable.token.value)
	return ""

func _to_string() -> String:
	var string := ""
	for i in range(0,context.size()):
		string += context[i].name + "="
		if context[i].token.value is String:
			string += '"' + context[i].token.value + '"'
		else:
			string += str(context[i].token.value)
		if i + 1 < context.size():
			string += ", "
	return string
