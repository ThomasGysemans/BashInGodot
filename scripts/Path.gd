extends Object
class_name PathObject

const NORMALIZING_PATH_REGEX := "\\/+"
const PATH_REGEX = "^(?<travelback>(?:\\.{0,2}\\/?)*)(?<name>[\\w\\-]+\\/?)*(?<extension>\\.[\\w]+)?$"

var path: String # An IMMUTABLE path
var parent = null # a String or null if it has no parent. Example of a path without parent: "yoyo", contrary to "/yoyo"
var file_name = null
var type: int # 0 for file, 1 for folder
var segments := []
var is_valid: bool

# For performance reasons, the computations are only done once.
# Therefore, the path cannot be changed.
func _init(p: String):
	var regex = RegEx.new()
	regex.compile(PATH_REGEX)
	type = 1 if p.ends_with("/") else 0
	path = simplify_path(p)
	if path.begins_with("//"):
		path = path.right(1)
	is_valid = regex.search(path) != null
	if is_valid:
		segments = path.split("/", false)
		parent = segments[segments.size() - 2] if segments.size() > 1 else null
		if type == 1:
			file_name = segments[segments.size() - 1] if segments.size() >= 1 else null
		else:
			file_name = path.get_file()

# String.simplify_path() is a built-in method to get the path to its smallest equivalent.
# However it doesn't interact well with how I actually want to manage paths,
# so to save performance we'll still use it,
# but by exluding the situations where I don't want it to change the given path
static func simplify_path(p: String) -> String:
	if p.begins_with("."):
		return p
	elif p.ends_with("/"):
		if p == "/":
			return p
		return p.substr(0, -1).simplify_path() + "/" 
	else:
		return p.simplify_path()

func is_leading_to_file() -> bool:
	return type == 0

func is_leading_to_folder() -> bool:
	return type == 1

func is_absolute() -> bool:
	return path.is_abs_path()

func equals(other_path) -> bool:
	if other_path is String:
		return self.path == other_path.simplify_path()
	return self.path ==  other_path.path # otherwise it is considered to be another PathObject

func _to_string():
	return path
