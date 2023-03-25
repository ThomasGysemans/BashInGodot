extends Object
class_name System

# This class is meant to represent the content of a computer.
# List the files and folders that multiple consoles can share.

var root: SystemElement

# Define the children elements of root in this array
func _init(children: Array):
	root = SystemElement.new(1, "/", "", "", children, "root", "admin")

# The absolute path is the only way to get an element.
func get_element_with_absolute_path(path: PathObject):
	if not path.is_absolute():
		return "The path is not absolute."
	var base = root
	var found := false
	for i in range(0, path.segments.size()):
		for child in base.children:
			if not base.can_execute_or_go_through():
				return "Permission refusée"
			if child.filename == path.segments[i]:
				base = child
				found = true
				break
		if not found:
			return null
		found = false
	return base

# Returns the SystemElement instance located at the given path.
# Returns null if the element doesn't exist.
# Returns a String if a particular error has occured.
func get_file_element_at(path: PathObject, pwd: PathObject):
	var base: SystemElement
	if path.is_absolute():
		var element = get_element_with_absolute_path(path)
		if element is String:
			return element
		base = element
	else:
		# A relative path is read until an absolute path can be built out of it.
		# That's why we need to know where the current folder is (using the PWD).
		base = get_element_with_absolute_path(pwd)
		var segments = (path.segments if not path.segments.empty() else [path.path])
		for segment in segments:
			if segment == ".":
				continue
			else:
				if segment == "..":
					var dest: String = base.absolute_path.path.substr(0, base.absolute_path.path.find_last("/"))
					if dest.length() == 0:
						base = root
					else:
						base = get_file_element_at(PathObject.new(dest), pwd)
				else:
					if base == null:
						return null
					var element = get_file_element_at(PathObject.new(base.absolute_path.path + ("" if base.absolute_path.equals("/") else "/") + segment), pwd)
					if element is String:
						return element
					base = element
	return base
