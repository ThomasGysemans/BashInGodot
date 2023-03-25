extends Node2D

export var user_name: String
export var group_name: String

var system := System.new([
	SystemElement.new(0, "file.txt", "/", "", [], user_name, group_name),
	SystemElement.new(1, "folder", "/", "", [
		SystemElement.new(0, "answer_to_life.txt", "/folder", "42", [], user_name, group_name),
		SystemElement.new(0, ".secret", "/folder", "ratio", [], user_name, group_name),
	], user_name, group_name),
])
