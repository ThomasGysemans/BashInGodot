tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("Console", "Panel", preload("res://addons/bash_in_godot/scripts/ConsoleNode.gd"), preload("res://addons/bash_in_godot/console.svg"))

func _exit_tree():
	remove_custom_type("Console")
