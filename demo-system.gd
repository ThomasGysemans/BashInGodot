extends Node2D

# Give this file to a node,
# and give it as export variable of the terminals
# so that they all share common attributes.

export var user_name: String
export var group_name: String

# The shared structure of files and folders.
# The name must be "system".
# It is optional.
var system := System.new([
	SystemElement.new(0, "file.txt", "/", "", [], user_name, group_name),
	SystemElement.new(1, "folder", "/", "", [
		SystemElement.new(0, "answer_to_life.txt", "/folder", "42", [], user_name, group_name),
		SystemElement.new(0, ".secret", "/folder", "ratio", [], user_name, group_name),
	], user_name, group_name),
])

# The DNS configuration that the console will be able to use.
# The name of the variable must be "dns".
# It is optional.
var dns := DNS.new([
	{
		"ipv4": "196.168.10.1",
		"ipv6": "",
		"name": "example.com",
		"mac": "00-B0-D0-63-C2-26"
	}
])

# The IP address that will be used by the terminal as source.
# The name must be "ip_address".
# It is optional, but if not given, the command "ping" will throw an error.
var ip_address := "192.168.10.2"

# The maximum number of characters printed on the same line for a paragraph.
# Use this if you have several consoles on the same screen and if you want
# them to share the same property.
# Override the property by setting an the export variable of the same name on the console node.
var max_paragraph_size := 50

# If you want to define exactly what commands
# can be used, then use the array below.
# All the commands that are not in the array
# will be set as not allowed.
# A not-allowed command appears like if it didn't exist at all.
#var allowed_commands := ["echo", "cat"]

# On the other hand, you can precise
# what commands are **not** allowed:
#var forbidden_commands := ["startm99"]

# Note that "allowed_commands" will always be read before "forbidden_commands".
