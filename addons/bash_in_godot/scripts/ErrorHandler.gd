extends Object
class_name ErrorHandler

# Because GDScript doesn't have a proper way to handle exceptions,
# we have to do it manually.
# When a specific error occurs deep inside our logic,
# we define the error here and test whether there is an error or not upwards.

var has_error := false
var error_desc := ""

func clear() -> String:
	has_error = false
	var c = error_desc
	error_desc = ""
	return c

func throw_error(desc: String, return_value = null):
	error_desc = desc
	has_error = true
	return return_value

func throw_permission_error(return_value = null):
	return throw_error("Permission refusée", return_value)

func _to_string() -> String:
	return error_desc
