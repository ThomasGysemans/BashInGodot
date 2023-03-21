# GdUnit generated TestSuite
#warning-ignore-all:unused_argument
#warning-ignore-all:return_value_discarded
class_name TerminalTest
extends GdUnitTestSuite

# TestSuite generated from
const __source = 'res://scripts/Terminal.gd'
const INVALID_PATH_EXAMPLE := "//yo.yo/+é''([å])/sc.js"
const user_name := "vous"
const group_name := "votre_groupe"

var terminal: Terminal

func before_test() -> void:
	terminal = Terminal.new()
	terminal.PWD = PathObject.new("/")
	terminal.set_root([
		SystemElement.new(0, "file.txt", "/", "Ceci est le contenu du fichier.", [], user_name, group_name),
		SystemElement.new(1, "folder", "/", "", [
			SystemElement.new(0, "answer_to_life.txt", "/folder", "42", [], user_name, group_name),
			SystemElement.new(0, ".secret", "/folder", "this is a secret", [], user_name, group_name)
		], user_name, group_name)
	])

func after_test() -> void:
	terminal.free()

func _command(command_name: String, arguments: String, standard_input: String = "") -> Dictionary:
	return terminal.COMMANDS[command_name].reference.call_func(BashParser.new(command_name + " " + arguments).parse()[0].options, standard_input)

func _eof_token() -> BashToken:
	return BashToken.new(Tokens.EOF, null)

func _move_pwd_to(path: String):
	if not path.is_abs_path():
		print("Erreur lors de la configuration d'un test. La cible '" + path + "' n'est pas un chemin absolu.")
		assert_not_yet_implemented()
		return
	terminal.PWD = PathObject.new(path)

func _set_permissions_of(path: String, permissions: String) -> SystemElement:
	terminal.get_file_element_at(PathObject.new(path)).set_permissions(permissions)
	return terminal.get_file_element_at(PathObject.new(path))

func test_bashtoken() -> void:
	assert_bool(BashToken.new(Tokens.FLAG, "n").is_flag()).is_true()
	assert_bool(BashToken.new(Tokens.FLAG, "n").is_flag_and_equals("n")).is_true()
	assert_bool(BashToken.new(Tokens.LONG_FLAG, "verbose").is_flag_and_equals("verbose")).is_true()
	assert_bool(BashToken.new(Tokens.STRING, "yoyo").is_word()).is_true()
	assert_bool(BashToken.new(Tokens.PLAIN, "yoyo").is_word()).is_true()
	assert_bool(BashToken.new(Tokens.PIPE, null).is_pipe()).is_true()
	assert_bool(BashToken.new(Tokens.EOF, null).is_eof()).is_true()
	assert_bool(BashToken.new(Tokens.APPEND_WRITING_REDIRECTION, null).is_append_writing_redirection()).is_true()
	assert_bool(BashToken.new(Tokens.WRITING_REDIRECTION, null).is_writing_redirection()).is_true()
	assert_bool(BashToken.new(Tokens.READING_REDIRECTION, null).is_reading_redirection()).is_true()
	assert_bool(BashToken.new(Tokens.APPEND_WRITING_REDIRECTION, null).is_redirection()).is_true()
	assert_bool(BashToken.new(Tokens.WRITING_REDIRECTION, null).is_redirection()).is_true()
	assert_bool(BashToken.new(Tokens.READING_REDIRECTION, null).is_redirection()).is_true()
	assert_bool(BashToken.new(Tokens.AND, null).is_and()).is_true()

func test_system_element() -> void:
	assert_str(SystemElement.new(0, ".gitignore", "/").filename).is_equal(".gitignore")
	assert_str(SystemElement.new(1, "folder", "/").parent).is_equal("/")
	assert_str(SystemElement.new(0, "answer_to_life.txt", "/folder", "42").content).is_equal("42")
	assert_str(SystemElement.new(0, "folder", "/", "yoyo").content).is_equal("yoyo")
	assert_bool(SystemElement.new(0, "file.txt", "/").is_hidden()).is_false()
	assert_bool(SystemElement.new(0, ".gitignore", "/").is_hidden()).is_true()
	assert_bool(SystemElement.new(0, "file.txt", "/").is_file()).is_true()
	assert_bool(SystemElement.new(1, "folder", "/").is_folder()).is_true()
	assert_bool(terminal.system_tree.children[0].equals(SystemElement.new(0, "file.txt", "/"))).is_true()
	assert_bool(terminal.system_tree.children[1].children[0].equals(SystemElement.new(0, "answer_to_life.txt", "/folder"))).is_true()
	assert_int(terminal.system_tree.children.size()).is_equal(2)
	terminal.system_tree.append(SystemElement.new(0, "fake.txt", "/"))
	assert_int(terminal.system_tree.children.size()).is_equal(3)
	assert_int(terminal.system_tree.count_depth()).is_equal(1)
	assert_int(SystemElement.new(1, "child", "/folder").count_depth()).is_equal(2)
	assert_int(SystemElement.new(1, "child", "/root/folder").count_depth()).is_equal(3)

func test_are_permissions_valid() -> void:
	assert_bool(SystemElement.are_permissions_valid("644")).is_true()
	assert_bool(SystemElement.are_permissions_valid("777")).is_true()
	assert_bool(SystemElement.are_permissions_valid("111")).is_true()
	assert_bool(SystemElement.are_permissions_valid("770")).is_true()
	assert_bool(SystemElement.are_permissions_valid("007")).is_true()
	assert_bool(SystemElement.are_permissions_valid("778")).is_false()
	assert_bool(SystemElement.are_permissions_valid("-778")).is_false()
	assert_bool(SystemElement.are_permissions_valid("Z+x")).is_false()

func test_build_permissions_string() -> void:
	assert_str(SystemElement.new(0, "r", "/").build_permissions_string()).is_equal("-rw-r--r--")
	var element := SystemElement.new(0, "r", "/")
	assert_bool(element.set_permissions("123")).is_true()
	assert_str(element.build_permissions_string()).is_equal("---x-w--wx")
	assert_bool(element.set_permissions("456")).is_true()
	assert_str(element.build_permissions_string()).is_equal("-r--r-xrw-")
	assert_bool(element.set_permissions("777")).is_true()
	assert_str(element.build_permissions_string()).is_equal("-rwxrwxrwx")
	assert_str(SystemElement.new(1, "some_folder", "/").build_permissions_string()).is_equal("drwxr-xr-x")

func test_permissions() -> void:
	var element := SystemElement.new(0, "random.txt", "/", "content", [])
	assert_bool(element.can_read()).is_true()
	assert_bool(element.can_write()).is_true()
	assert_bool(element.can_execute_or_go_through()).is_false()
	assert_bool(element.set_permissions("111")).is_true() # ---x--x--x
	assert_bool(element.can_read()).is_false()
	assert_bool(element.can_write()).is_false()
	assert_bool(element.can_execute_or_go_through()).is_true()

func test_set_specific_permission() -> void:
	var element := SystemElement.new(0, "some_file.txt", "/", "content") # p=644
	assert_bool(element.set_specific_permission("U+x")).is_false()
	assert_bool(element.set_specific_permission("Z+x")).is_false()
	assert_bool(element.set_specific_permission("uçx")).is_false()
	assert_bool(element.set_specific_permission("çx")).is_false()
	assert_bool(element.set_specific_permission("u+o")).is_false()
	assert_bool(element.set_specific_permission("u+x")).is_true()
	assert_str(element.permissions).is_equal("744")
	assert_bool(element.set_specific_permission("u-x")).is_true()
	assert_str(element.permissions).is_equal("644")
	assert_bool(element.set_specific_permission("u+r")).is_true() # we already have "r"
	assert_str(element.permissions).is_equal("644")
	assert_bool(element.set_specific_permission("+w")).is_true()
	assert_str(element.permissions).is_equal("644")
	assert_bool(element.set_specific_permission("g+w")).is_true()
	assert_str(element.permissions).is_equal("664")
	assert_bool(element.set_specific_permission("+x")).is_true()
	assert_bool(element.set_specific_permission("g+x")).is_true()
	assert_bool(element.set_specific_permission("o+x")).is_true()
	assert_bool(element.set_specific_permission("o+w")).is_true()
	assert_str(element.permissions).is_equal("777")
	assert_bool(element.set_specific_permission("-r")).is_true()
	assert_str(element.permissions).is_equal("377")
	assert_bool(element.set_specific_permission("-x")).is_true()
	assert_str(element.permissions).is_equal("277")
	assert_bool(element.set_specific_permission("-w")).is_true()
	assert_str(element.permissions).is_equal("077")
	assert_bool(element.set_specific_permission("g-r")).is_true()
	assert_str(element.permissions).is_equal("037")
	assert_bool(element.set_specific_permission("g-x")).is_true()
	assert_str(element.permissions).is_equal("027")
	assert_bool(element.set_specific_permission("g-w")).is_true()
	assert_str(element.permissions).is_equal("007")
	assert_bool(element.set_specific_permission("o-r")).is_true()
	assert_str(element.permissions).is_equal("003")
	assert_bool(element.set_specific_permission("o-x")).is_true()
	assert_str(element.permissions).is_equal("002")
	assert_bool(element.set_specific_permission("o-w")).is_true()
	assert_str(element.permissions).is_equal("000")

func test_paths() -> void:
	assert_int(PathObject.new("/").type).is_equal(1)
	assert_str(PathObject.new("/").path).is_equal("/")
	assert_int(PathObject.new("file.txt").type).is_equal(0)
	assert_array(PathObject.new("parent/child").segments).contains_exactly(["parent", "child"])
	assert_str(PathObject.new("parent/child").file_name).is_equal("child")
	assert_str(PathObject.new("parent/child/").file_name).is_equal("child")
	assert_str(PathObject.new("file.txt").file_name).is_equal("file.txt")
	assert_str(PathObject.new("parent/child").parent).is_equal("parent")
	assert_bool(PathObject.new("pé&[å»]/child.txt").is_valid).is_false()
	assert_str(PathObject.new("yoyo").parent).is_null()
	assert_str(PathObject.new("yoyo").path).is_equal("yoyo")
	assert_bool(PathObject.new("/yoyo").is_absolute()).is_true()
	assert_bool(PathObject.new("yoyo").is_absolute()).is_false()
	assert_bool(PathObject.new("/yoyo").equals(PathObject.new("/yoyo"))).is_true()
	assert_bool(PathObject.new("////yo/./yo").is_valid).is_true()
	assert_str(PathObject.new("////yo/./yo").path).is_equal("/yo/yo")
	assert_array(PathObject.new(".").segments).contains_exactly(["."])
	assert_array(PathObject.new("..").segments).contains_exactly([".."])

func test_paths_move_inside_of() -> void:
	assert_bool(terminal.get_file_element_at(PathObject.new("file.txt")).move_inside_of(PathObject.new("/folder")).absolute_path.equals("/folder/file.txt")).is_true()

func test_simplify_path() -> void:
	assert_str(PathObject.simplify_path(".")).is_equal(".")
	assert_str(PathObject.simplify_path("..")).is_equal("..")
	assert_str(PathObject.simplify_path("folder/")).is_equal("folder/")
	assert_str(PathObject.simplify_path("/")).is_equal("/")
	assert_str(PathObject.simplify_path("../")).is_equal("../")
	assert_str(PathObject.simplify_path("../..")).is_equal("../..")

func test_strings() -> void:
	var lexer := BashParser.new('echo -n "C\'est nice"')
	assert_str(lexer.error).is_empty()
	assert_array(lexer.tokens_list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "echo"),
		BashToken.new(Tokens.FLAG, "n"),
		BashToken.new(Tokens.STRING, "C'est nice"),
		_eof_token()
	])

func test_lexer_simple_echo() -> void:
	var lexer := BashParser.new("echo -n 'yoyo'")
	var list := lexer.tokens_list
	assert_int(list.size()).is_equal(4)
	assert_array(list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "echo"),
		BashToken.new(Tokens.FLAG, "n"),
		BashToken.new(Tokens.STRING, "yoyo"),
		_eof_token()
	])

func test_lexer_pipe() -> void:
	var lexer := BashParser.new("ls -a | tr -d y")
	var list := lexer.tokens_list
	assert_int(list.size()).is_equal(7)
	assert_array(list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "ls"),
		BashToken.new(Tokens.FLAG, "a"),
		BashToken.new(Tokens.PIPE, null),
		BashToken.new(Tokens.PLAIN, "tr"),
		BashToken.new(Tokens.FLAG, "d"),
		BashToken.new(Tokens.PLAIN, "y"),
		_eof_token()
	])

func test_lexer_flags() -> void:
	var lexer := BashParser.new('rm -dr --verbose folder | echo "yoyo"')
	var list := lexer.tokens_list
	assert_int(list.size()).is_equal(9)
	assert_array(list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "rm"),
		BashToken.new(Tokens.FLAG, "d"),
		BashToken.new(Tokens.FLAG, "r"),
		BashToken.new(Tokens.LONG_FLAG, "verbose"),
		BashToken.new(Tokens.PLAIN, "folder"),
		BashToken.new(Tokens.PIPE, null),
		BashToken.new(Tokens.PLAIN, "echo"),
		BashToken.new(Tokens.STRING, "yoyo"),
		_eof_token()
	])

func test_lexer_with_numbered_redirections() -> void:
	var lexer := BashParser.new("cat file.txt 1>yoyo.txt 2<yoyo.txt 0>ksks")
	var list := lexer.tokens_list
	assert_array(list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "cat"),
		BashToken.new(Tokens.PLAIN, "file.txt"),
		BashToken.new(Tokens.DESCRIPTOR, 1),
		BashToken.new(Tokens.WRITING_REDIRECTION, null),
		BashToken.new(Tokens.PLAIN, "yoyo.txt"),
		BashToken.new(Tokens.DESCRIPTOR, 2),
		BashToken.new(Tokens.READING_REDIRECTION, null),
		BashToken.new(Tokens.PLAIN, "yoyo.txt"),
		BashToken.new(Tokens.DESCRIPTOR, 0),
		BashToken.new(Tokens.WRITING_REDIRECTION, null),
		BashToken.new(Tokens.PLAIN, "ksks"),
		_eof_token()
	])

func test_lexer_with_default_redirection() -> void:
	var lexer := BashParser.new("cat file.txt >yoyo.txt <yoyo.txt")
	var list := lexer.tokens_list
	assert_array(list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "cat"),
		BashToken.new(Tokens.PLAIN, "file.txt"),
		BashToken.new(Tokens.DESCRIPTOR, 1),
		BashToken.new(Tokens.WRITING_REDIRECTION, null),
		BashToken.new(Tokens.PLAIN, "yoyo.txt"),
		BashToken.new(Tokens.DESCRIPTOR, 0),
		BashToken.new(Tokens.READING_REDIRECTION, null),
		BashToken.new(Tokens.PLAIN, "yoyo.txt"),
		_eof_token()
	])

func test_lexer_with_default_appending_redirection() -> void:
	var lexer := BashParser.new("cat file.txt >>yoyo.txt")
	var list := lexer.tokens_list
	assert_array(list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "cat"),
		BashToken.new(Tokens.PLAIN, "file.txt"),
		BashToken.new(Tokens.DESCRIPTOR, 1),
		BashToken.new(Tokens.APPEND_WRITING_REDIRECTION, null),
		BashToken.new(Tokens.PLAIN, "yoyo.txt"),
		_eof_token()
	])

func test_lexer_with_numbered_appending_redirection() -> void:
	var lexer := BashParser.new("cat file.txt 2>>yoyo.txt")
	var list := lexer.tokens_list
	assert_array(list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "cat"),
		BashToken.new(Tokens.PLAIN, "file.txt"),
		BashToken.new(Tokens.DESCRIPTOR, 2),
		BashToken.new(Tokens.APPEND_WRITING_REDIRECTION, null),
		BashToken.new(Tokens.PLAIN, "yoyo.txt"),
		_eof_token()
	])

func test_lexer_with_copied_redirection() -> void:
	var lexer := BashParser.new("cat file 2>file.txt >&2")
	assert_array(lexer.tokens_list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "cat"),
		BashToken.new(Tokens.PLAIN, "file"),
		BashToken.new(Tokens.DESCRIPTOR, 2),
		BashToken.new(Tokens.WRITING_REDIRECTION, null),
		BashToken.new(Tokens.PLAIN, "file.txt"),
		BashToken.new(Tokens.DESCRIPTOR, 1),
		BashToken.new(Tokens.WRITING_REDIRECTION, null),
		BashToken.new(Tokens.AND, null),
		BashToken.new(Tokens.DESCRIPTOR, 2),
		_eof_token()
	])

func test_lexer_with_no_actual_redirection() -> void:
	var lexer := BashParser.new("echo 2 1 y 0yo 3")
	var list := lexer.tokens_list
	assert_array(list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "echo"),
		BashToken.new(Tokens.PLAIN, "2"),
		BashToken.new(Tokens.PLAIN, "1"),
		BashToken.new(Tokens.PLAIN, "y"),
		BashToken.new(Tokens.PLAIN, "0yo"),
		BashToken.new(Tokens.PLAIN, "3"),
		_eof_token()
	])

func test_lexer_with_appending_redirection_and_fake_descriptor() -> void:
	var lexer := BashParser.new("echo 2>>1")
	assert_array(lexer.tokens_list).contains_exactly([
		BashToken.new(Tokens.PLAIN, "echo"),
		BashToken.new(Tokens.DESCRIPTOR, 2),
		BashToken.new(Tokens.APPEND_WRITING_REDIRECTION, null),
		BashToken.new(Tokens.PLAIN, "1"),
		_eof_token()
	])

func test_parser() -> void:
	var lexer := BashParser.new("rm -dr --verbose / | echo yoyo")
	var result := lexer.parse()
	assert_int(result.size()).is_equal(2)
	assert_object(result[0]).is_equal({
		"name": "rm",
		"options": [
			BashToken.new(Tokens.FLAG, "d"),
			BashToken.new(Tokens.FLAG, "r"),
			BashToken.new(Tokens.LONG_FLAG, "verbose"),
			BashToken.new(Tokens.PLAIN, "/"),
		],
		"redirections": []
	})
	assert_object(result[1]).is_equal({
		"name": "echo",
		"options": [
			BashToken.new(Tokens.PLAIN, "yoyo")
		],
		"redirections": []
	})

func test_parser_with_redirections() -> void:
	var lexer := BashParser.new("cat file.txt >other.txt 2>&1")
	var result := lexer.parse()
	assert_str(lexer.error).is_empty()
	assert_int(result.size()).is_equal(1)
	assert_object(result[0]).is_equal({
		"name": "cat",
		"options": [
			BashToken.new(Tokens.PLAIN, "file.txt")
		],
		"redirections": [
			{
				"port": 1,
				"type": Tokens.WRITING_REDIRECTION,
				"target": "other.txt",
				"copied": false
			},
			{
				"port": 2,
				"type": Tokens.WRITING_REDIRECTION,
				"target": 1,
				"copied": true
			}
		]
	})

# cannot read from the standard output
func test_parser_with_redirections_error() -> void:
	var lexer := BashParser.new("echo yoyo 1<file.txt")
	var result := lexer.parse()
	assert_str(lexer.error).is_not_empty()
	lexer = BashParser.new("echo yoyo <<file.txt")
	result = lexer.parse()
	assert_str(lexer.error).is_not_empty()

func test_interpret_redirections() -> void:
	var redirections = BashParser.new("echo omg 1>folder/file.txt 2>&1 1>&2").parse()[0].redirections
	var interpretation = terminal.interpret_redirections(redirections)
	assert_object(interpretation[0]).is_null()
	assert_object(interpretation[1]).is_not_null()
	assert_object(interpretation[2]).is_not_null()
	assert_bool(interpretation[1].target.equals(terminal.get_file_element_at(PathObject.new("/folder/file.txt"))))
	assert_bool(interpretation[2].target.equals(terminal.get_file_element_at(PathObject.new("/folder/file.txt"))))
	assert_str(interpretation[1].type).is_equal(Tokens.WRITING_REDIRECTION)
	assert_str(interpretation[2].type).is_equal(Tokens.WRITING_REDIRECTION)

func test_interpret_default_redirection() -> void:
	var redirections = BashParser.new("echo omg >file.txt").parse()[0].redirections
	var interpretation = terminal.interpret_redirections(redirections)
	assert_object(interpretation[0]).is_null()
	assert_object(interpretation[1]).is_not_null()
	assert_object(interpretation[2]).is_null()

func test_interpret_complex_redirections() -> void:
	var redirections = BashParser.new("cat 0<file.txt 2>file2.txt 2>&2 2>&2 2>&2 1>>file2.txt").parse()[0].redirections
	var interpretation = terminal.interpret_redirections(redirections)
	assert_object(interpretation[0]).is_not_null()
	assert_object(interpretation[1]).is_not_null()
	assert_object(interpretation[2]).is_not_null()
	assert_object(interpretation[0].target).is_equal(terminal.get_file_element_at(PathObject.new("/file.txt")))
	assert_object(interpretation[1].target).is_equal(terminal.get_file_element_at(PathObject.new("/file2.txt")))
	assert_object(interpretation[2].target).is_equal(terminal.get_file_element_at(PathObject.new("/file2.txt")))
	assert_str(interpretation[0].type).is_equal(Tokens.READING_REDIRECTION)
	assert_str(interpretation[1].type).is_equal(Tokens.APPEND_WRITING_REDIRECTION)
	assert_str(interpretation[2].type).is_equal(Tokens.WRITING_REDIRECTION)

func test_interpret_redirections_with_errors() -> void:
	var redirections = BashParser.new("echo omg 1>folder").parse()[0].redirections
	var interpretaton = terminal.interpret_redirections(redirections)
	assert_bool(terminal.error_handler.has_error).is_true()
	terminal.error_handler.clear()
	_set_permissions_of("/folder", "644")
	redirections = BashParser.new("echo omg >folder/file.txt").parse()[0].redirections
	interpretaton = terminal.interpret_redirections(redirections)
	assert_bool(terminal.error_handler.has_error).is_true()

func test_execute() -> void:
	assert_str(terminal.execute("echo yoyo")).is_empty()
	assert_str(terminal.execute("yoyo")).is_not_empty()
	assert_str(terminal.execute("_process")).is_not_empty()

func test_execute_with_simple_redirections() -> void:
	assert_str(terminal.execute("echo -n yoyo 1>file.txt 2>error.txt")).is_empty()
	assert_str(terminal.get_file_element_at(PathObject.new("file.txt")).content).is_equal("yoyo")
	assert_object(terminal.get_file_element_at(PathObject.new("error.txt"))).is_not_null()
	assert_str(terminal.get_file_element_at(PathObject.new("error.txt")).content).is_empty()

func test_execute_with_complex_redirections() -> void:
	var previous_content: String = terminal.get_file_element_at(PathObject.new("file.txt")).content
	assert_str(terminal.execute("echo -n yoyo 1>>file.txt 2>>file.txt")).is_empty()
	assert_str(terminal.get_file_element_at(PathObject.new("file.txt")).content).is_equal(previous_content + "yoyo")

func test_execute_with_custom_standard_input() -> void:
	terminal.get_file_element_at(PathObject.new("file.txt")).content = "hello"
	assert_str(terminal.execute("tr e a 0<file.txt 1>result.txt")).is_empty()
	assert_str(terminal.get_file_element_at(PathObject.new("result.txt")).content).is_equal("hallo")

func test_execute_with_redirected_error() -> void:
	assert_str(terminal.execute("cat imaginary_file.txt 2>error.txt | rm file.txt")).is_empty()
	assert_object(terminal.get_file_element_at(PathObject.new("file.txt"))).is_not_null() # meaning `rm file.txt` was not executed
	assert_object(terminal.get_file_element_at(PathObject.new("error.txt"))).is_not_null()
	assert_str(terminal.get_file_element_at(PathObject.new("error.txt")).content).is_equal(terminal.execute("cat imaginary_file.txt"))

func test_execute_with_mistaken_redirection() -> void:
	assert_str(terminal.execute("tr y t 0<imaginary_file.txt")).is_not_empty() # meaning an error was thrown

func test_get_file_element_at() -> void:
	assert_str(terminal.get_file_element_at(PathObject.new("/")).absolute_path.path).is_equal("/")
	assert_object(terminal.get_file_element_at(PathObject.new("file.txt"))).is_not_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder"))).is_not_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder/answer_to_life.txt"))).is_not_null()
	_move_pwd_to("/folder")
	assert_object(terminal.get_file_element_at(PathObject.new("file.txt"))).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder"))).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("answer_to_life.txt"))).is_not_null()
	assert_bool(terminal.get_file_element_at(PathObject.new("..")).equals(terminal.get_file_element_at(PathObject.new("/")))).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new(".")).equals(terminal.get_file_element_at(terminal.PWD))).is_true()
	assert_bool(terminal.get_file_element_at(terminal.PWD).is_folder()).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new("/file.txt")).is_file()).is_true()
	assert_bool(terminal.get_file_element_at(terminal.PWD).is_file()).is_false()
	assert_bool(terminal.get_file_element_at(PathObject.new("/file.txt")).is_folder()).is_false()

func test_get_file_element_at_permission_denied() -> void:
	_set_permissions_of("/folder", "655") # we remove the "x" permission of the folder
	assert_object(terminal.get_file_element_at(PathObject.new("/folder"))).is_not_null()
	assert_bool(terminal.error_handler.has_error).is_false()
	assert_object(terminal.get_file_element_at(PathObject.new("/folder/answer_to_life.txt"))).is_null()
	assert_bool(terminal.error_handler.has_error).is_true()

func test_get_pwd_file_element() -> void:
	assert_object(terminal.get_pwd_file_element()).is_not_null()
	assert_bool(terminal.get_pwd_file_element().equals(terminal.get_file_element_at(terminal.PWD))).is_true()

func test_get_parent_element_from() -> void:
	assert_bool(terminal.get_parent_element_from(PathObject.new("/")).equals(terminal.system_tree))
	assert_object(terminal.get_file_element_at(PathObject.new("/imaginaryfolder/yoyo"))).is_null()
	assert_object(terminal.get_parent_element_from(PathObject.new("/imaginaryfolder/yoyo"))).is_null()
	assert_bool(terminal.get_parent_element_from(PathObject.new("/folder/answer_to_life.txt")).equals(terminal.system_tree.children[1]))

func test_copy_element() -> void:
	_set_permissions_of("/file.txt", "244")
	assert_bool(terminal.get_file_element_at(PathObject.new("file.txt")).equals(terminal.copy_element(terminal.get_file_element_at(PathObject.new("file.txt"))))).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new("folder")).equals(terminal.copy_element(terminal.get_file_element_at(PathObject.new("folder"))))).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new("file.txt")) == terminal.copy_element(terminal.get_file_element_at(PathObject.new("file.txt")))).is_false()
	assert_bool(terminal.get_file_element_at(PathObject.new("file.txt")).permissions == terminal.copy_element(terminal.get_file_element_at(PathObject.new("/file.txt"))).permissions).is_true()

func test_copy_children_of() -> void:
	assert_bool(terminal.copy_children_of(terminal.get_file_element_at(PathObject.new("folder")))[0] == terminal.get_file_element_at(PathObject.new("folder")).children[0]).is_false()
	assert_bool(terminal.copy_children_of(terminal.get_file_element_at(PathObject.new("folder")))[0].equals(terminal.get_file_element_at(PathObject.new("folder")).children[0])).is_true()

func test_merge() -> void:
	# 1. append a file to a folder
	assert_bool(terminal.merge(terminal.get_file_element_at(PathObject.new("file.txt")), terminal.get_file_element_at(PathObject.new("folder")))).is_true()
	assert_object(terminal.get_file_element_at(PathObject.new("folder/file.txt"))).is_not_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/folder/file.txt")).absolute_path.path).is_equal("/folder/file.txt")
	# 2. merge a file with a folder that already contains a file of the same name
	var previous_number_of_children = terminal.get_file_element_at(PathObject.new("folder")).children.size()
	terminal.get_file_element_at(PathObject.new("file.txt")).content = "new content"
	assert_bool(terminal.merge(terminal.get_file_element_at(PathObject.new("file.txt")), terminal.get_file_element_at(PathObject.new("folder")))).is_true()
	assert_int(terminal.get_file_element_at(PathObject.new("folder")).children.size()).is_equal(previous_number_of_children)
	assert_object(terminal.get_file_element_at(PathObject.new("folder/file.txt"))).is_not_null()
	assert_str(terminal.get_file_element_at(PathObject.new("folder/file.txt")).content).is_equal("new content")
	assert_str(terminal.get_file_element_at(PathObject.new("/folder/file.txt")).absolute_path.path).is_equal("/folder/file.txt")
	# 3. merge a folder with a few files that are the same, and others are not
	assert_str(_command("cp", "folder copiedfolder").error).is_null()
	assert_str(_command("rm", "folder/answer_to_life.txt").error).is_null()
	terminal.get_file_element_at(PathObject.new("copiedfolder/.secret")).content = "changed secret"
	assert_bool(terminal.merge(terminal.get_file_element_at(PathObject.new("copiedfolder")), terminal.get_file_element_at(PathObject.new("folder")))).is_true()
	assert_object(terminal.get_file_element_at(PathObject.new("folder/answer_to_life.txt"))).is_not_null()
	assert_str(terminal.get_file_element_at(PathObject.new("folder/.secret")).content).is_equal("changed secret")
	assert_str(terminal.get_file_element_at(PathObject.new("copiedfolder/.secret")).content).is_equal("changed secret")

func test_move() -> void:
	assert_bool(terminal.move(terminal.get_file_element_at(PathObject.new("file.txt")), PathObject.new(INVALID_PATH_EXAMPLE))).is_false()
	assert_bool(terminal.move(terminal.get_file_element_at(PathObject.new("file.txt")), PathObject.new("a/b/c/d"))).is_false()
	# testing mv file.txt /folder/
	# which should remove file.txt from PWD
	# in order to put it inside folder
	assert_bool(terminal.move(terminal.get_file_element_at(PathObject.new("file.txt")), PathObject.new("/folder/"))).is_true()
	assert_object(terminal.get_file_element_at(PathObject.new("file.txt"))).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("/folder/file.txt"))).is_not_null()
	# testing mv /folder/file.txt ../newname
	assert_bool(terminal.move(terminal.get_file_element_at(PathObject.new("/folder/file.txt")), PathObject.new("../newname"))).is_true()
	assert_object(terminal.get_file_element_at(PathObject.new("/folder/file.txt"))).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("/folder/newname"))).is_null()
	assert_bool(terminal.get_file_element_at(PathObject.new("/newname")).is_file()).is_true()

func test_man() -> void:
	assert_str(_command("man", "man").output).is_not_empty()
	assert_str(_command("man", "").error).is_not_null()
	assert_str(_command("man", "yo yo").error).is_not_null()
	for command in terminal.COMMANDS:
		assert_str(_command("man", command).error).is_null()

func test_help() -> void:
	assert_str(_command("help", "").output).is_not_empty()
	assert_str(_command("help", "yo").error).is_not_null()

func test_echo() -> void:
	assert_str(_command("echo", "a b c").output).is_equal("a b c\n")
	assert_str(_command("echo", "a   b c").output).is_equal("a b c\n")
	assert_str(_command("echo", "yoyo").output).is_equal("yoyo\n")
	assert_str(_command("echo", "-n").output).is_equal("")
	assert_str(_command("echo", "-nn").output).is_equal("")
	assert_str(_command("echo", "-y").output).is_equal("-y\n")

func test_grep() -> void:
	assert_str(_command("grep", "y", "yoyo").output).is_equal("[color=blue]y[/color]o[color=blue]y[/color]o\n")
	assert_str(_command("grep", "y", "toto").output).is_equal("")
	assert_str(_command("grep", "", "yoyo").error).is_not_null()
	assert_str(_command("grep", "").error).is_not_null()
	assert_str(_command("grep", "-c y", "yoyo").output).is_equal("2")
	assert_int(_command("grep", "y", "hey\nyo").output.count("\n") ).is_equal(2)

func test_tr() -> void:
	assert_str(_command("tr", "").error).is_not_null()
	assert_str(_command("tr", "yo").error).is_not_null()
	assert_str(_command("tr", "y t").error).is_not_null()
	assert_str(_command("tr", "y t", "yoyo").output).is_equal("toto")
	assert_str(_command("tr", "-d t", "toto").output).is_equal("oo")
	assert_str(_command("tr", "abcd yoy", "abcd").output).is_equal("yoyy")
	assert_str(_command("tr", "yoyo -d", "yoyo").output).is_equal("dddd")

func test_cat() -> void:
	assert_str(_command("cat", "").output).is_empty()
	assert_str(_command("cat", "yo yo").error).is_not_null()
	assert_str(_command("cat", INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("cat", "yyoyooyyoyo").error).is_not_null()
	assert_str(_command("cat", "folder/answer_to_life.txt").output).is_equal("42\n")
	assert_str(_command("cat", "file.txt").output).is_equal(terminal.get_file_element_at(PathObject.new("/file.txt")).content + "\n")
	terminal.system_tree.append(SystemElement.new(0, "empty_file.txt", "/"))
	assert_str(_command("cat", "./empty_file.txt").output).is_equal("Le fichier est vide.\n")
	# permissions check
	_set_permissions_of("empty_file.txt", "244") # -w-
	assert_bool(terminal.get_file_element_at(PathObject.new("empty_file.txt")).can_read()).is_false()
	assert_str(_command("cat", "empty_file.txt").error).is_not_null() # an error must be displayed

func test_ls() -> void:
	assert_str(_command("ls", "-b").error).is_not_null()
	assert_str(_command("ls", "-b folder").error).is_not_null()
	assert_str(_command("ls", INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("ls", "-a " + INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("ls", "yoyoyoyo").error).is_not_null()
	assert_str(_command("ls", "-a yoyoyoyoyo").error).is_not_null()
	assert_str(_command("ls", "-l file.txt").error).is_null()
	assert_str(_command("ls", "-a file.txt").output).is_equal("file.txt")
	assert_str(_command("ls", "-al .").error).is_null()
	assert_int(_command("ls", "").output.count("\n")).is_equal(terminal.system_tree.children.size())
	assert_int(_command("ls", "-l").output.count("\n")).is_equal(terminal.system_tree.children.size())
	assert_int(_command("ls", "folder").output.count("\n")).is_equal(terminal.system_tree.children[1].children.size() - 1)
	assert_int(_command("ls", "-a folder").output.count("\n")).is_equal(terminal.system_tree.children[1].children.size())
	var element := SystemElement.new(0, "some_file.txt", "/", "héllo", [], user_name, group_name)
	terminal.system_tree.append(element)
	assert_object(terminal.get_file_element_at(PathObject.new("/some_file.txt"))).is_not_null()
	assert_str(_command("ls", "-l some_file.txt").output).is_equal(
		element.build_permissions_string() \
		+ "vous " \
		+ "votre_groupe " \
		+ "6 " \
		+ element.get_formatted_creation_date() + " " \
		+ "some_file.txt\n"
	)
	# permissions check
	_set_permissions_of("folder", "655") # rw-
	assert_str(_command("ls", "folder").error).is_not_null()
	_set_permissions_of("folder", "355") # -wx
	assert_str(_command("ls", "folder").error).is_not_null()
	_set_permissions_of("folder", "755") # rwx
	terminal.PWD = PathObject.new("/folder")
	_set_permissions_of("/folder", "355") # -wx
	assert_str(_command("ls", "-a .").error).is_not_null()

func test_clear() -> void:
	assert_str(_command("clear", "").error).is_null()
	assert_str(_command("clear", "").output).is_empty()

func test_pwd() -> void:
	assert_str(_command("pwd", "yoyo").error).is_not_null()
	assert_str(_command("pwd", "").output).is_equal(terminal.PWD.path + "\n")

func test_cd() -> void:
	assert_str(_command("cd", "yo yo").error).is_not_null()
	assert_str(_command("cd", "-n").error).is_not_null()
	assert_str(_command("cd", INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("cd", "tyoyoyoyo").error).is_not_null()
	assert_str(_command("cd", "file.txt").error).is_not_null()
	assert_str(_command("cd", "folder").error).is_null()
	assert_str(terminal.PWD.path).is_equal("/folder")
	assert_str(_command("cd", "folder").error).is_not_null()
	assert_str(_command("cd", "..").error).is_null()
	assert_str(_command("cd", "").error).is_null()
	assert_str(terminal.PWD.path).is_equal("/")
	# permissions check
	_set_permissions_of("folder", "655") # rw-
	assert_str(_command("cd", "folder").error).is_not_null()

func test_touch() -> void:
	assert_str(_command("touch", "").error).is_not_null()
	assert_str(_command("touch", "yo yo yo").error).is_not_null()
	assert_str(_command("touch", "-d").error).is_not_null()
	assert_str(_command("touch", "file.txt").output).is_empty()
	assert_str(_command("touch", "file.txt").error).is_null()
	assert_str(_command("touch", "somefolder/").error).is_not_null()
	assert_str(_command("touch", INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("touch", "a/b/c/file.txt").error).is_not_null()
	assert_str(_command("touch", "a/file.txt").error).is_not_null()
	assert_str(_command("touch", "a.txt/f.txt").error).is_not_null()
	assert_str(_command("touch", "awesomefile.txt").error).is_null()
	assert_str(terminal.system_tree.children[-1].filename).is_equal("awesomefile.txt")
	assert_bool(terminal.system_tree.children[-1].is_file()).is_true()
	# permissions check
	_set_permissions_of("folder", "655") # rw-
	assert_str(_command("touch", "folder/newfile.txt").error).is_not_null()
	_set_permissions_of("folder", "555") # r-x
	assert_str(_command("touch", "folder/newfile.txt").error).is_not_null()

func test_mkdir() -> void:
	assert_str(_command("mkdir", "").error).is_not_null()
	assert_str(_command("mkdir", "yo yo yo").error).is_not_null()
	assert_str(_command("mkdir", "-d").error).is_not_null()
	assert_str(_command("mkdir", "folder").error).is_not_null()
	assert_str(_command("mkdir", INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("mkdir", "a/b/c/d").error).is_not_null()
	assert_str(_command("mkdir", "file.txt").error).is_not_null()
	assert_str(_command("mkdir", "file.txt/somefolder").error).is_not_null()
	assert_str(_command("mkdir", "newfolder").error).is_null()
	assert_array(terminal.system_tree.children[-1].children).is_not_null()
	assert_bool(terminal.system_tree.children[-1].children.empty()).is_true()
	assert_str(terminal.system_tree.children[-1].filename).is_equal("newfolder")
	assert_bool(terminal.system_tree.children[-1].is_folder()).is_true()
	assert_str(_command("mkdir", "newfolder/child").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("newfolder/child"))).is_not_null()
	assert_bool(terminal.get_file_element_at(PathObject.new("newfolder/child")).is_folder()).is_true()
	assert_str(terminal.get_file_element_at(PathObject.new("newfolder/child")).absolute_path.path).is_equal("/newfolder/child")
	# permissions check
	_set_permissions_of("folder", "655") # rw-
	assert_str(_command("mkdir", "folder/yoyofolder").error).is_not_null()
	_set_permissions_of("folder", "455") # r--
	assert_str(_command("mkdir", "folder/yoyofolder").error).is_not_null()

func test_rm() -> void:
	# permissions check
	_set_permissions_of("folder", "555") # r-x
	assert_str(_command("rm", "folder/answer_to_life.txt").error).is_not_null()
	assert_str(_command("rm", "-r folder").error).is_not_null()
	_set_permissions_of("folder", "655") # rw-
	assert_str(_command("rm", "-r folder").error).is_not_null()
	_set_permissions_of("folder", "755") # rwx
	_set_permissions_of("file.txt", "444") # r--
	assert_str(_command("rm", "file.txt").error).is_not_null()
	_set_permissions_of("file.txt", "644") # rw-
	# ---
	assert_str(_command("rm", "").error).is_not_null()
	assert_str(_command("rm", "yo yo").error).is_not_null()
	assert_str(_command("rm", "-z").error).is_not_null()
	assert_str(_command("rm", "-fr").error).is_not_null()
	assert_str(_command("rm", INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("rm", "yoyoyoyo").error).is_not_null()
	assert_str(_command("rm", "/").error).is_not_null()
	assert_str(_command("rm", "imaginaryfolder/file.txt").error).is_not_null()
	assert_str(_command("rm", "folder").error).is_not_null()
	assert_str(_command("rm", "-d folder").error).is_not_null() # because not empty
	assert_str(_command("rm", "-r yoyo/folder").error).is_not_null()
	assert_int(terminal.system_tree.children.size()).is_equal(2)
	assert_str(_command("rm", "file.txt").error).is_null()
	assert_int(terminal.system_tree.children.size()).is_equal(1)
	assert_str(_command("rm", "-r folder").error).is_null()
	assert_int(terminal.system_tree.children.size()).is_equal(0)
	assert_str(_command("rm", "-r " + terminal.PWD.path).error).is_not_null()

func test_cp() -> void:
	assert_str(_command("cp", "").error).is_not_null()
	assert_str(_command("cp", "yo").error).is_not_null()
	assert_str(_command("cp", "yo yo yo").error).is_not_null()
	assert_str(_command("cp", "-z -z").error).is_not_null()
	assert_str(_command("cp", INVALID_PATH_EXAMPLE + " yo").error).is_not_null()
	assert_str(_command("cp", "yo " + INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("cp", "yoyoyoyo truc").error).is_not_null()
	assert_str(_command("cp", "file.txt a/b/c/d").error).is_not_null()
	assert_str(_command("cp", "file.txt file.txt").error).is_not_null() # identical files
	assert_str(_command("cp", "folder file.txt").error).is_not_null() # folder to file not possible
	assert_str(_command("cp", "file.txt newfolder/").error).is_not_null() # copy a file to a folder that doesn't exist
	# permissions check
	_set_permissions_of("folder", "655") # rw-
	assert_str(_command("cp", "file.txt folder").error).is_not_null()
	_set_permissions_of("folder", "555") # r-x
	assert_str(_command("cp", "file.txt folder").error).is_not_null()
	_set_permissions_of("folder", "755") # rwx
	# combinations:
	# 1. copy a file to a new file with its permissions
	_set_permissions_of("file.txt", "444") # r--
	assert_str(_command("cp", "file.txt hello.txt").error).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/file.txt")).permissions).is_equal("444")
	assert_str(terminal.get_file_element_at(PathObject.new("/hello.txt")).filename).is_equal("hello.txt")
	assert_bool(terminal.get_file_element_at(PathObject.new("/hello.txt")).is_file()).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new("/hello.txt")).absolute_path.equals("/hello.txt")).is_true()
	assert_str(terminal.get_file_element_at(PathObject.new("/hello.txt")).permissions).is_equal("444") # the permissions too must be copied from one element to the other
	_set_permissions_of("file.txt", "644") # rw-
	# 2. copy a file to an existing file
	terminal.get_file_element_at(PathObject.new("/file.txt")).content = "new content"
	assert_str(terminal.get_file_element_at(PathObject.new("/file.txt")).content).is_equal("new content")
	assert_str(_command("cp", "file.txt hello.txt").error).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/hello.txt")).content).is_equal("new content")
	assert_bool(terminal.get_file_element_at(PathObject.new("/hello.txt")).absolute_path.equals("/hello.txt")).is_true()	
	# 4. copy a folder to a new folder with its permissions
	_set_permissions_of("folder", "655") # rw-
	assert_str(_command("cp", "folder newfolder").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("/newfolder"))).is_not_null()
	assert_bool(terminal.get_file_element_at(PathObject.new("/newfolder")).is_folder()).is_true()
	assert_int(terminal.get_file_element_at(PathObject.new("/folder")).children.size()).is_equal(terminal.get_file_element_at(PathObject.new("/newfolder")).children.size())
	assert_bool(terminal.get_file_element_at(PathObject.new("/folder")).children[0] == terminal.get_file_element_at(PathObject.new("/newfolder")).children[0]).is_false()
	assert_str(terminal.get_file_element_at(PathObject.new("/newfolder")).permissions).is_equal("655")
	_set_permissions_of("folder", "755") # rwx
	_set_permissions_of("newfolder", "755") # rwx
	# check permissions folder1 to folder2 with folder2 of permissions r-x
	_set_permissions_of("folder", "555") # r-x
	assert_str(_command("cp", "newfolder folder").error).is_not_null()
	_set_permissions_of("folder", "755") # rwx
	# 3. copy a file to an existing folder
	# 3.1 the folder has a similar file
	terminal.get_file_element_at(PathObject.new("/file.txt")).content = "file content"
	assert_str(_command("cp", "file.txt newfolder").error).is_null()
	assert_int(terminal.get_file_element_at(PathObject.new("/newfolder")).children.size()).is_equal(3) # .secret, answser_to_life.txt and file.txt
	assert_str(terminal.get_file_element_at(PathObject.new("/newfolder/file.txt")).content).is_equal("file content")
	assert_str(terminal.get_file_element_at(PathObject.new("/newfolder/file.txt")).absolute_path.path).is_equal("/newfolder/file.txt")
	# 3.2 the folder does not have a similar file
	assert_str(_command("cp", "file.txt folder").error).is_null()
	assert_int(terminal.get_file_element_at(PathObject.new("/folder")).children.size()).is_equal(3)
	assert_str(terminal.get_file_element_at(PathObject.new("/folder/file.txt")).content).is_equal("file content")
	assert_str(terminal.get_file_element_at(PathObject.new("/folder/file.txt")).absolute_path.path).is_equal("/folder/file.txt")
	# 5. copy a folder to an existing folder
	terminal.get_file_element_at(PathObject.new("/folder/answer_to_life.txt")).content = "43"
	var previous_size := terminal.get_file_element_at(PathObject.new("/newfolder")).children.size() as int
	assert_str(_command("cp", "folder newfolder").error).is_null()
	assert_int(terminal.get_file_element_at(PathObject.new("/newfolder")).children.size()).is_equal(previous_size)
	assert_str(terminal.get_file_element_at(PathObject.new("/newfolder/answer_to_life.txt")).content).is_equal("43")
	assert_str(terminal.get_file_element_at(PathObject.new("/newfolder/.secret")).content).is_equal("this is a secret")
	assert_bool(terminal.get_file_element_at(PathObject.new("/folder/answer_to_life.txt")).equals(terminal.get_file_element_at(PathObject.new("/newfolder/answer_to_life.txt")))).is_false()

func test_mv() -> void:
	assert_str(_command("mv", "").error).is_not_null()
	assert_str(_command("mv", "yo").error).is_not_null()
	assert_str(_command("mv", "yo yo yo").error).is_not_null()
	assert_str(_command("mv", "folder " + INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("mv", INVALID_PATH_EXAMPLE + " folder").error).is_not_null()
	assert_str(_command("mv", "yoyoyoyo file.txt").error).is_not_null()
	assert_str(_command("mv", "folder file.txt").error).is_not_null()
	# permissions check
	_set_permissions_of("folder", "655") # rw-
	assert_str(_command("mv", "file.txt folder").error).is_not_null()
	_set_permissions_of("folder", "555") # r-x
	assert_str(_command("mv", "file.txt folder").error).is_not_null() # cannot move a file to a folder without writing permissions
	_set_permissions_of("folder", "755") # rwx
	# 1. rename a file
	var previous_size := terminal.get_pwd_file_element().children.size()
	var file_content: String = terminal.get_file_element_at(PathObject.new("file.txt")).content
	assert_str(_command("mv", "file.txt file2.txt").error).is_null()
	assert_int(terminal.get_pwd_file_element().children.size()).is_equal(previous_size)
	assert_object(terminal.get_file_element_at(PathObject.new("file.txt"))).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("file2.txt"))).is_not_null()
	assert_object(terminal.get_file_element_at(PathObject.new("file.txt"))).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("file2.txt")).content).is_equal(file_content)
	# 2. move a file to an existing one
	assert_str(_command("touch", "newfile.txt").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("newfile.txt"))).is_not_null()
	terminal.get_file_element_at(PathObject.new("newfile.txt")).content = "new"
	assert_str(_command("mv", "newfile.txt file2.txt").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("newfile.txt"))).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("file2.txt")).content).is_equal("new")
	# 3. move a file to an existing folder
	previous_size = terminal.get_file_element_at(PathObject.new("folder")).children.size()
	assert_str(_command("mv", "file2.txt folder").error).is_null()
	assert_int(terminal.get_file_element_at(PathObject.new("folder")).children.size()).is_equal(previous_size + 1)
	assert_object(terminal.get_file_element_at(PathObject.new("folder/file2.txt"))).is_not_null()
	assert_object(terminal.get_file_element_at(PathObject.new("file2.txt"))).is_null()
	# 4. move a file to a destination that doesn't exist, but ressembles a folder
	assert_str(_command("mv", "folder/file2.txt folder/somefolder/").error).is_not_null()
	# 5. rename a folder
	assert_str(_command("mv", "folder movedfolder").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("movedfolder"))).is_not_null()
	assert_bool(terminal.get_file_element_at(PathObject.new("movedfolder")).is_folder()).is_true()
	assert_str(terminal.get_file_element_at(PathObject.new("movedfolder")).absolute_path.path).is_equal("/movedfolder")
	assert_object(terminal.get_file_element_at(PathObject.new("folder"))).is_null()
	_set_permissions_of("/movedfolder", "555") # r-x
	assert_str(_command("mv", "movedfolder unauthorized_folder").error).is_not_null()
	assert_object(terminal.get_file_element_at(PathObject.new("/movedfolder"))).is_not_null()
	assert_object(terminal.get_file_element_at(PathObject.new("/unauthorized_folder"))).is_null()
	_set_permissions_of("/movedfolder", "755")
	# 6. move a folder to an empty folder
	assert_str(_command("mkdir", "folder").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder"))).is_not_null()
	assert_str(_command("mv", "movedfolder folder").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("movedfolder"))).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder/movedfolder"))).is_not_null()
	assert_bool(terminal.get_file_element_at(PathObject.new("folder/movedfolder")).is_folder()).is_true()
	assert_str(terminal.get_file_element_at(PathObject.new("/folder/movedfolder")).absolute_path.path).is_equal("/folder/movedfolder")

func test_chmod() -> void:
	assert_str(_command("chmod", "").error).is_not_null()
	assert_str(_command("chmod", "yo").error).is_not_null()
	assert_str(_command("chmod", "u+x").error).is_not_null()
	assert_str(_command("chmod", "file.txt").error).is_not_null()
	assert_str(_command("chmod", "Z+x file.txt").error).is_not_null()
	assert_str(_command("chmod", "+x yoyo.txt").error).is_not_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/file.txt")).permissions).is_equal("644")
	assert_str(_command("chmod", "u+x file.txt").error).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/file.txt")).permissions).is_equal("744")
	assert_str(_command("chmod", "777 file.txt").error).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/file.txt")).permissions).is_equal("777")
	assert_str(_command("chmod", "000 folder").error).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/folder")).permissions).is_equal("000")
	assert_str(_command("chmod", "777 folder").error).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/folder")).permissions).is_equal("777")
