extends Object
class_name SystemElement

# this is a class meant to describe an element in a system tree.
# the root will always be a folder of name "/".
# Everything should inherit from such folder.
# The root is also the only element authorized to have no parent.

# the numeric values of each kind of permission
const X = 1 # execution/crossing
const W = 2 # writing
const R = 4 # reading

var type: int # either 0 for file or 1 for folder
var filename: String # the name of the file
var base_dir: String # the parent absolute path. For root it would be an empty string ("")
var content: String # only if it's a file, otherwise empty string ("")
var children := [] # an array of SystemElement. Typed arrays will only be possible in Godot v4
var absolute_path = null # computed and immutable value
var permissions: String # the octal format (777)
var creation_date := Time.get_datetime_dict_from_system()
var creator_name := "unknown"
var group_name := "unknown"

# How do permissions work?
# three different sets of permissions for user, group and other
# three different kinds of permissions : read, write, execute
# the permissions are three octal digits and each digit is a permission:
# read adds 4
# write add 2
# execute adds 1
# therefore, permissions 644 sets "-rw-r--r--"
# meaning read and write for the user,
# read for the group
# read for the others

static func are_permissions_valid(p: String) -> bool:
	if p.length() != 3: return false
	var regex := RegEx.new()
	regex.compile("[0-7]{3}")
	var result := regex.search(p)
	return result != null

# A SystemElement represents a file or a folder (it's kind of the same thing).
# Here the list of parameters:
# - t: the type of the element. 0 for a file, 1 for a folder.
# - name: the name of the element.
# - p: the absolute path of the parent of the element (the path to where it is contained).
# - c: the content of the file (USE THIS ONLY IF t=0)
# - ch: the children of the folder (USE THIS ONLY IF t=1)
# - creator: the name of the user that created this file.
# - group: the name of the group that created this file.
func _init(t: int, name: String, p, c = "", ch = [], creator: String = "", group: String = "", given_permissions: String = ""):
	type = t
	filename = name
	base_dir = p
	content = c
	children = ch
	absolute_path = PathObject.new(base_dir + "/" + filename) if not base_dir.empty() else PathObject.new("/")
	creator_name = creator
	group_name = group
	if given_permissions.empty():
		set_default_permissions()
	else:
		if are_permissions_valid(given_permissions):
			permissions = given_permissions
		else:
			set_default_permissions()
			push_warning("The " + ("file" if t == 0 else "folder") + " '" + name + "' received invalid permissions: '" + given_permissions + "'. Default permissions were given instead.")
	if content.length() > 0 and type == 1:
		push_error("It is not possible for a folder to have content. The object was destroyed. Invalid file's name: " + filename)
		self.free()
	if children.size() > 0 and type == 0:
		push_error("A file cannot contain other files. The object was destroyed. Invalid file's name: " + filename)
		self.free()

func append(element: SystemElement):
	children.append(element)

func set_default_permissions() -> void:
	if is_folder():
		permissions = "755" # default permissions of a folder
	else:
		permissions = "644" # default permissions of a file

func count_depth() -> int:
	if base_dir == "/":
		return 1
	else:
		return base_dir.count("/") + 1

func is_file() -> bool:
	return type == 0

func is_folder() -> bool:
	return type == 1

func is_hidden() -> bool:
	return filename.begins_with(".")

func rename(new_name: String) -> void:
	filename = new_name

# When we copy/move of a file to new location,
# the absolute path of the object must be changed,
# otherwise it would cause very weird behaviours.
# We also have to change the absolute path, and the base_dir property,
# of every children the element may contain.
# `new_absolute_path` is either a String or an instance of PathObject.
# Be careful with this, as this function can throw an unexpected error if the type is wrong.
# Returns the instance of the object in case it needs to be chained.
func move_inside_of(new_absolute_path):
	var new_path_object: PathObject 
	if new_absolute_path is String:
		self.base_dir = new_absolute_path # we have the absolute path of the folder it must be inside of
		new_path_object = PathObject.new(new_absolute_path + "/" + filename) # the absolute path is: base_dir/filename
	else:
		self.base_dir = new_absolute_path.path # same as above but with the object instead of the String
		new_path_object = PathObject.new(new_absolute_path.path + "/" + filename)
	self.absolute_path = new_path_object
	# The base_dir is the new_absolute_path
	# The path that the children must have is therefore the base_dir of their parent (this object)
	# before the parent of the absolute_path they already have.
	# The filename will be added to their absolute_path afterwards recursively.
	for child in self.children:
		child.move_inside_of(self.base_dir + "/" + child.absolute_path.parent)
	return self

# Checks if two elements are equal.
# If their type is different, it returns false.
# If their absolute path is different, it returns false.
# If the elements are files, then it returns true if their content is the same.
# If the elements are folders, the functions becomes recursive and is applied on each child.
func equals(another: SystemElement) -> bool:
	if self == another: return true
	if another == null: return false
	if self.type != another.type: return false
	if !self.absolute_path.equals(another.absolute_path): return false
	if self.is_file():
		return self.content == another.content
	else:
		var found_equal := false
		for child1 in self.children:
			for child2 in another.children:
				if child1.equals(child2):
					found_equal = true
					break
			if not found_equal:
				return false
	return true

# Sets the permissions using the octal format.
# Example is: chmod 777 file.txt
# where "777" would be the value of `p` given to this function.
func set_permissions(p: String) -> bool:
	if not are_permissions_valid(p):
		return false
	permissions = p
	return true

# Here the input is on one category only,
# Example is: chmod u+x file.txt
# where "u+x" would be the value of `p` given to this function.
func set_specific_permission(p: String) -> bool:
	if p.length() < 2 or p.length() > 3:
		return false
	var regex := RegEx.new()
	regex.compile("^(u|o|g)?(\\+|-){1}(r|w|x)$")
	var result := regex.search(p)
	if result == null:
		return false
	var target := result.get_string(1) if not result.get_string(1).empty() else "u"
	var type := 1 if result.get_string(2) == "+" else 0 # 1 for "+", 0 for "-"
	var permission_string := result.get_string(3)
	var permission_integer := R if permission_string == "r" else (W if permission_string == "w" else X)
	var permission_index := 0
	match target:
		"u": permission_index = 0
		"g": permission_index = 1
		"o": permission_index = 2
	var current_value := _translate_octal_to_string(int(permissions[permission_index]))
	if type == 0 and current_value.find(permission_string) != -1:
		permissions[permission_index] = str(int(permissions[permission_index]) - permission_integer)
	elif type == 1 and current_value.find(permission_string) == -1:
		permissions[permission_index] = str(int(permissions[permission_index]) + permission_integer)
	return true

func _translate_octal_to_string(octal: int) -> String:
	match octal:
		1: return "--x"
		2: return "-w-"
		3: return "-wx"
		4: return "r--"
		5: return "r-x"
		6: return "rw-"
		7: return "rwx"
		_: return "---"

func build_permissions_string() -> String:
	var string = "d" if is_folder() else "-"
	for p in permissions:
		string += _translate_octal_to_string(int(p))
	return string

func calculate_size() -> int:
	if is_file():
		return content.to_utf8().size()
	else:
		var total := 0
		for child in children:
			total += child.calculate_size()
		return total

func get_formatted_creation_date() -> String:
	return str(creation_date.day).pad_zeros(2) + "/" \
		+ str(creation_date.month).pad_zeros(2) + "/" \
		+ str(creation_date.year) + " " \
		+ str(creation_date.hour).pad_zeros(2) + ":" + str(creation_date.minute).pad_zeros(2)

func info_long_format() -> String:
	return build_permissions_string() \
		+ creator_name + " " \
		+ group_name + " " \
		+ str(calculate_size()) + " " \
		+ get_formatted_creation_date() + " " \
		+ filename + "\n"

# For permissions, even though Unix is a multi-user thing,
# we'll only have one user using the terminal,
# so we don't really care about the permissions
# granted to the group or the others.

func can_read() -> bool:
	return int(permissions[0]) >= 4

func can_write() -> bool:
	return permissions[0] in ["2", "3", "6", "7"]

func can_execute_or_go_through() -> bool:
	return permissions[0] in ["1", "3", "5", "7"]

func _to_string():
	var string = filename if is_file() else "[color=green]" + filename + "[/color]\n"
	for child in children:
		if child.is_hidden():
			continue
		string += "   ".repeat(child.count_depth()) + "[color=gray]--[/color] " + child.to_string() + "\n"
	return string
