extends Object
class_name PathObject

const NORMALIZING_PATH_REGEX = "\\/+"
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
	is_valid = regex.search(p) != null
	path = normalize_path(p) if is_valid else p
	if is_valid:
		type = 1 if path.ends_with("/") else 0
		segments = path.split("/", false)
		parent = segments[segments.size() - 2] if segments.size() > 1 else null
		for i in range(segments.size()):
			if segments[i].empty():
				segments[i] = "/"
		if parent != null and parent.empty():
			parent = "/"
		if type == 0:
			file_name = path.right(path.find_last("/")+1)

# In Bash, the path "/myfolder////////myfile.txt" is valid,
# it is the same as "/myfolder/myfile.txt".
# This needs to be handled.
func normalize_path(p: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\/+")
	var result = regex.search_all(p)
	if result.empty():
		return p # because it might be just the name of the relative destination, example: "cd folder"
	for r in result:
		p = p.replace(r.get_string(), "/")
	return p

func is_leading_to_file() -> bool:
	return type == 0

func is_leading_to_folder() -> bool:
	return type == 1

func is_absolute() -> bool:
	return path.begins_with("/")

func equals(other_path) -> bool:
	if other_path is String:
		return self.path == other_path
	return self.path ==  other_path.path # otherwise it is considered to be another PathObject

func _to_string():
	return path
