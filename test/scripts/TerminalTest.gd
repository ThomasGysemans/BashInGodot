# GdUnit generated TestSuite
#warning-ignore-all:unused_argument
#warning-ignore-all:return_value_discarded
class_name TerminalTest
extends GdUnitTestSuite

# TestSuite generated from
const __source = 'res://scripts/Terminal.gd'
const INVALID_PATH_EXAMPLE := "//yo.yo/+é''([å])/sc.js"

var terminal: Terminal

func before_test() -> void:
	terminal = Terminal.new()
	terminal.PWD = PathObject.new("/")
	terminal.system_tree = SystemElement.new(1, "/", "", "", [
		SystemElement.new(0, "file.txt", "/", "Ceci est le contenu du fichier."),
		SystemElement.new(1, "folder", "/", "", [
			SystemElement.new(0, "answer_to_life.txt", "/folder", "42"),
			SystemElement.new(0, ".secret", "/folder", "this is a secret")
		])
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

func test_bashtoken() -> void:
	assert_bool(BashToken.new(Tokens.FLAG, "n").is_flag()).is_true()
	assert_bool(BashToken.new(Tokens.FLAG, "n").is_flag_and_equals("n")).is_true()
	assert_bool(BashToken.new(Tokens.LONG_FLAG, "verbose").is_flag_and_equals("verbose")).is_true()
	assert_bool(BashToken.new(Tokens.STRING, "yoyo").is_word()).is_true()
	assert_bool(BashToken.new(Tokens.PLAIN, "yoyo").is_word()).is_true()
	assert_bool(BashToken.new(Tokens.PIPE, null).is_pipe()).is_true()
	assert_bool(BashToken.new(Tokens.EOF, null).is_eof()).is_true()

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
		]
	})
	assert_object(result[1]).is_equal({
		"name": "echo",
		"options": [
			BashToken.new(Tokens.PLAIN, "yoyo")
		]
	})

func test_get_file_element_at() -> void:
	assert_str(terminal.get_file_element_at(PathObject.new("/")).absolute_path.path).is_equal("/")
	assert_object(terminal.get_file_element_at(PathObject.new("file.txt"))).is_not_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder"))).is_not_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder/answer_to_life.txt"))).is_not_null()
	_move_pwd_to("/folder")
	assert_object(terminal.get_file_element_at(PathObject.new("file.txt"))).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder"))).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("answer_to_life.txt"))).is_not_null()
	assert_object(terminal.get_file_element_at(PathObject.new(INVALID_PATH_EXAMPLE))).is_null()
	assert_bool(terminal.get_file_element_at(PathObject.new("..")).equals(terminal.get_file_element_at(PathObject.new("/")))).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new(".")).equals(terminal.get_file_element_at(terminal.PWD))).is_true()
	assert_bool(terminal.get_file_element_at(terminal.PWD).is_folder()).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new("/file.txt")).is_file()).is_true()
	assert_bool(terminal.get_file_element_at(terminal.PWD).is_file()).is_false()
	assert_bool(terminal.get_file_element_at(PathObject.new("/file.txt")).is_folder()).is_false()

func test_get_pwd_file_element() -> void:
	assert_object(terminal.get_pwd_file_element()).is_not_null()
	assert_bool(terminal.get_pwd_file_element().equals(terminal.get_file_element_at(terminal.PWD))).is_true()

func test_get_parent_element_from() -> void:
	assert_bool(terminal.get_parent_element_from(PathObject.new("/")).equals(terminal.system_tree))
	assert_object(terminal.get_file_element_at(PathObject.new("/imaginaryfolder/yoyo"))).is_null()
	assert_object(terminal.get_parent_element_from(PathObject.new("/imaginaryfolder/yoyo"))).is_null()
	assert_bool(terminal.get_parent_element_from(PathObject.new("/folder/answer_to_life.txt")).equals(terminal.system_tree.children[1]))

func test_copy_element() -> void:
	assert_bool(terminal.get_file_element_at(PathObject.new("file.txt")).equals(terminal.copy_element(terminal.get_file_element_at(PathObject.new("file.txt"))))).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new("folder")).equals(terminal.copy_element(terminal.get_file_element_at(PathObject.new("folder"))))).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new("file.txt")) == terminal.copy_element(terminal.get_file_element_at(PathObject.new("file.txt")))).is_false()

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
		assert_str(_command("man", command.name).error).is_null()

func test_echo() -> void:
	assert_str(_command("echo", "a b c").output).is_equal("a b c\n")
	assert_str(_command("echo", "a   b c").output).is_equal("a b c\n")
	assert_str(_command("echo", "yoyo").output).is_equal("yoyo\n")
	assert_str(_command("echo", "-n").output).is_equal("")
	assert_str(_command("echo", "-nn").output).is_equal("")
	assert_str(_command("echo", "-y").output).is_equal("-y\n")

func test_grep() -> void:
	assert_str(_command("grep", "y", "yoyo").output).is_equal("[color=blue]y[/color]o[color=blue]y[/color]o")
	assert_str(_command("grep", "y", "toto").output).is_equal("")
	assert_str(_command("grep", "", "yoyo").error).is_not_null()
	assert_str(_command("grep", "").error).is_not_null()

func test_tr() -> void:
	assert_str(_command("tr", "").error).is_not_null()
	assert_str(_command("tr", "yo").error).is_not_null()
	assert_str(_command("tr", "y t").error).is_not_null()
	assert_str(_command("tr", "y t", "yoyo").output).is_equal("toto")
	assert_str(_command("tr", "-d t", "toto").output).is_equal("oo")
	assert_str(_command("tr", "abcd yoy", "abcd").output).is_equal("yoyy")
	assert_str(_command("tr", "yoyo -d", "yoyo").output).is_equal("dddd")

func test_cat() -> void:
	assert_str(_command("cat", "").error).is_not_null()
	assert_str(_command("cat", "yo yo").error).is_not_null()
	assert_str(_command("cat", INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("cat", "yyoyooyyoyo").error).is_not_null()
	assert_str(_command("cat", "folder/answer_to_life.txt").output).is_equal("42\n")
	terminal.system_tree.append(SystemElement.new(0, "empty_file.txt", "/"))
	assert_str(_command("cat", "./empty_file.txt").output).is_equal("Le fichier est vide.\n")

func test_ls() -> void:
	assert_str(_command("ls", "-b").error).is_not_null()
	assert_str(_command("ls", "-b folder").error).is_not_null()
	assert_str(_command("ls", "file.txt").error).is_not_null()
	assert_str(_command("ls", "-a file.txt").error).is_not_null()
	assert_str(_command("ls", INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("ls", "-a " + INVALID_PATH_EXAMPLE).error).is_not_null()
	assert_str(_command("ls", "yoyoyoyo").error).is_not_null()
	assert_str(_command("ls", "-a yoyoyoyoyo").error).is_not_null()
	assert_int(_command("ls", "").output.count("\n")).is_equal(terminal.system_tree.children.size())
	assert_int(_command("ls", "folder").output.count("\n")).is_equal(terminal.system_tree.children[1].children.size() - 1)
	assert_int(_command("ls", "-a folder").output.count("\n")).is_equal(terminal.system_tree.children[1].children.size())

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
	

func test_rm() -> void:
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
	# combinations:
	# 1. copy a file to a new file
	assert_str(_command("cp", "file.txt hello.txt").error).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/hello.txt")).filename).is_equal("hello.txt")
	assert_bool(terminal.get_file_element_at(PathObject.new("/hello.txt")).is_file()).is_true()
	assert_bool(terminal.get_file_element_at(PathObject.new("/hello.txt")).absolute_path.equals("/hello.txt")).is_true()
	# 2. copy a file to an existing file
	terminal.get_file_element_at(PathObject.new("/file.txt")).content = "new content"
	assert_str(terminal.get_file_element_at(PathObject.new("/file.txt")).content).is_equal("new content")
	assert_str(_command("cp", "file.txt hello.txt").error).is_null()
	assert_str(terminal.get_file_element_at(PathObject.new("/hello.txt")).content).is_equal("new content")
	assert_bool(terminal.get_file_element_at(PathObject.new("/hello.txt")).absolute_path.equals("/hello.txt")).is_true()	
	# 4. copy a folder to a new folder
	assert_str(_command("cp", "folder newfolder").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("/newfolder"))).is_not_null()
	assert_bool(terminal.get_file_element_at(PathObject.new("/newfolder")).is_folder()).is_true()
	assert_int(terminal.get_file_element_at(PathObject.new("/folder")).children.size()).is_equal(terminal.get_file_element_at(PathObject.new("/newfolder")).children.size())
	assert_bool(terminal.get_file_element_at(PathObject.new("/folder")).children[0] == terminal.get_file_element_at(PathObject.new("/newfolder")).children[0]).is_false()
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
	# 6. move a folder to an empty folder
	assert_str(_command("mkdir", "folder").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder"))).is_not_null()
	assert_str(_command("mv", "movedfolder folder").error).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("movedfolder"))).is_null()
	assert_object(terminal.get_file_element_at(PathObject.new("folder/movedfolder"))).is_not_null()
	assert_bool(terminal.get_file_element_at(PathObject.new("folder/movedfolder")).is_folder()).is_true()
	assert_str(terminal.get_file_element_at(PathObject.new("/folder/movedfolder")).absolute_path.path).is_equal("/folder/movedfolder")
