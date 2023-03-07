extends Object
class_name SystemElement

# this is a class meant to describe an element in a system tree.
# the root will always be a folder of name "/".
# Everything should inherit from such folder.
# The root is also the only element authorized to have no parent

var type: int # either 0 for file or 1 for folder
var filename: String # the name of the file
var parent: String # the parent absolute path. For root it would be an empty string ("")
var content: String # only if it's a file, otherwise empty string ("")
var children := [] # an array of SystemElement. Typed arrays will only be possible in Godot v4
var absolute_path = null # computed and immutable value

func _init(t: int, name: String, p, c = "", ch = []):
	type = t
	filename = name
	parent = p
	content = c
	children = ch
	absolute_path = PathObject.new(parent + "/" + filename)
	if content.length() > 0 and type == 1:
		push_error("It is not possible for a folder to have content. The object was destroyed.\nInvalid file's name: " + filename)
		self.free()
	if children.size() > 0 and type == 0:
		push_error("A file cannot contain other files. The object was destroyed.\nInvalid file's name: " + filename)
		self.free()

func append(element: SystemElement):
	children.append(element)

func count_depth() -> int:
	if parent == "/":
		return 1
	else:
		return parent.count("/") + 1

func is_file():
	return type == 0

func is_folder():
	return type == 1

func is_hidden():
	return filename.begins_with(".")

func _to_string():
	var string = filename if is_file() else "[color=green]" + filename + "[/color]\n"
	for child in children:
		string += "   ".repeat(child.count_depth()) + "[color=gray]--[/color] " + child.to_string() + "\n"
	return string
