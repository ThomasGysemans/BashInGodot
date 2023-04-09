#warning-ignore-all:return_value_discarded
extends Object
class_name Terminal

# The signal `interface_changed` can be used to read the standard output of a successful command.
# It is different from `command_executed` because `command_executed` might be thrown several times in a row.
# Indeed, several commands can be on the same line separated by pipes.
# Example:
# $ echo toto | echo tata
# `command_executed` will be emitted twice with `output` set to "toto" and then "tata"
# `interface_changed` will be emitted once with `content` set to "tata" (the last standard output of the row)

# NOTE: all the arguments passed to the signals are passed by REFERENCE.
# Therefore, any modification of the references will modify the terminal's system tree
# (unless the element is voluntarily removed by the algorithm which is the case for the `origin` argument of the `file_moved` signal).
# If a copy needs to be done, then see the following functions:
# - `copy_element()` (Terminal.gd)
# - `copy_children_of()` (Terminal.gd)
# - `move_inside_of()` (SystemElement.gd)

signal command_executed (command, output) # command is a dictionary and output is the content of standard output, the signal will be emitted only if the command didn't throw an error
signal error_thrown (command, reason) # emitted when the `command` thrown an error, which text is the `reason`
signal permissions_changed (file) # file is a SystemElement (file or FOLDER)
signal file_created (file) # file is a SystemElement (file or FOLDER)
signal file_destroyed (file) # file is a SystemElement (file or FOLDER)
signal file_changed (file) # emitted when "nano" was used to edit the content of a file. It does not detect if the new content is different.
signal file_read (file) # emitted when the file is being read (via the cat command).
signal file_copied (origin, copy) # emitted when the `origin` is being copied. Note that `origin` != `copy` (not the same reference, and the absolute path of the copy, or its content, might be different from the origin's).
signal file_moved (origin, target) # emitted when the `origin` is being moved elsewhere. The origin is destroyed (but `file_destroyed` is not emitted) and `target` is the new instance of SystemElement.
signal directory_changed (target) # emitted when the `cd` command is used (and didn't throw an error)
signal interface_changed (content) # emitted when something is printed onto the screen. It is not emitted when the interface is cleared.
signal manual_asked (command_name, output) # emitted when the `man` command is used to open the manual page of a command.
signal variable_set (name, value, is_new) # emitted when a variable is created, "name" and "value" are strings, is_new is true if the variable was just created or false if it was modified.
signal script_executed (script, output) # emitted when a script was executed. `script` is the instance of SystemElement of the script, `output` is the complete output printed in the interface/
signal help_asked # emitted when the custom `help` command is used.
signal interface_cleared

var interface_reference = null # RichTextLabel
var max_paragraph_width := 50
var nano_editor = null
var edited_file = null
var user_name := "vous" # the currently logged in user's name
var group_name := "votre_groupe" # the currently logged in user's group name
var error_handler := ErrorHandler.new() # this will be used in case specific erros happen deep into the logic
var system: System # we'll start the terminal with an empty root by default
var PWD := PathObject.new("/") # the absolute path we are currently on in the `system`
var pid: int # the number of the current process
var dns := DNS.new([])
var ip_address := ""
# The `runtime` variable holds all the execution contexts.
# Bash usually creates only global variables no matter where they've been initialised.
# We are not taking into account the "local" keyword.
# The first index of this array will be the global context.
# For now, we'll only have one context.
var runtime := [BashContext.new()]
var m99 := M99.new()

func _display_error_or(error: String):
	return error_handler.clear() if error_handler.has_error else error

var COMMANDS := {
	"man": {
		"reference": funcref(self, "man"),
		"manual": {
			"name": "man - affiche la page du manuel expliquant une commande précise.",
			"synopsis": ["[b]man[/b] [u]nom[/u]"],
			"description": "Cette commande fait référence au manuel qui contient une explication de toutes les commandes disponibles. Le 'nom' doit être le nom d'une commande valide, sinon une erreur sera renvoyée.",
			"options": [],
			"examples": []
		}
	},
	"echo": {
		"reference": funcref(self, "echo"),
		"manual": {
			"name": "echo - affiche un texte dans le terminal.",
			"synopsis": ["[b]echo[/b] [-n] [[u]contenu[/u] [u]...[/u]]"],
			"description": "Affiche tout le contenu séparé par un espace blanc entre le nom de la commande et la fin de la commande, sauf s'il y a l'option -n qui permet de ne pas continuer le résultat par un '\\n'.",
			"options": [
				{
					"name": "-n",
					"description": "N'ajoute pas un retour à la ligne à la fin du contenu."
				}
			],
			"examples": [
				"echo -n hello, world",
				"echo \"hello world\""
			]
		}
	},
	"grep": {
		"reference": funcref(self, "grep"),
		"manual": {
			"name": "grep - cherche un pattern dans l'entrée standard.",
			"synopsis": ["[b]grep[/b] [[b]-c[/b] [u]nombre[/u]] [u]pattern[/u]"],
			"description": "Cherche dans l'entrée standard les lignes qui correspondent au pattern donné. Si le pattern n'y est pas trouvé, la ligne est ignorée. S'il est trouvé, elle est affichée et ce qui correspond au pattern est mis en évidence.",
			"options": [],
			"examples": [
				"cat fichier.txt | grep hello"
			]
		}
	},
	"tr": {
		"reference": funcref(self, "tr_"),
		"manual": {
			"name": "tr - remplace, ou supprime, un pattern précis depuis l'entrée standard pour l'afficher dans la sortie standard.",
			"synopsis": [
				"[b]tr[/b] [u]pattern[/u] [u]remplacement[/u]",
				"[b]tr[/b] [b]-d[/b] [u]pattern[/u]"
			],
			"description": "Remplace le pattern par la chaine de remplacement donné. Si l'option -d est précisée, toutes les occurrences du pattern seront supprimées. Le résultat est affiché dans la sortie standard.",
			"options": [
				{
					"name": "-d",
					"description": "supprime les occurrences du pattern plutôt que de les remplacer."
				}
			],
			"examples": [
				"echo buste | tr u a",
				"echo truc | tr -d u"
			]
		}
	},
	"cat": {
		"reference": funcref(self, "cat"),
		"manual": {
			"name": "cat - affiche le contenu d'un fichier en sortie standard.",
			"synopsis": ["[b]cat[/b] [u]fichier[/u]"],
			"description": "Renvoie le contenu du fichier donné, s'il existe, dans la sortie standard. Cette action ne peut pas être réalisée sur un dossier.",
			"options": [],
			"examples": [
				"cat fichier.txt"
			]
		}
	},
	"ls": {
		"reference": funcref(self, "ls"),
		"manual": {
			"name": "ls - liste le contenu d'un dossier.",
			"synopsis": ["[b]ls[/b] [[b]-a[/b]] [[u]dossier[/u]]"],
			"description": "La commande va lister le contenu des dossiers, en colorant en vert les dossiers, et en blanc les fichiers. Par défaut, les fichiers et dossiers cachés (c'est-à-dire ceux préfixés par un point) ne serront pas affichés. Pour les afficher, utilisez l'option -a.",
			"options": [
				{
					"name": "-a",
					"description": "Affiche les fichiers cachés (ceux préfixés d'un point)"
				}
			],
			"examples": [
				"ls folder",
				"ls -a folder"
			]
		}
	},
	"clear": {
		"reference": funcref(self, "clear"),
		"manual": {
			"name": "clear - vide le terminal de son contenu textuel.",
			"synopsis": ["[b]clear[/b]"],
			"description": "Le contenu du terminal est supprimé pour reprendre sur un écran vide.",
			"options": [],
			"examples": []
		}
	},
	"pwd": {
		"reference": funcref(self, "pwd"),
		"manual": {
			"name": "pwd - retourne le chemin absolu du dossier courant.",
			"synopsis": ["[b]pwd[/b]"],
			"description": "La commande pwd écrit dans la sortie standard le chemin absolu du dossier courant. Naviguez dans les dossiers en utilisant la commande \"cd\".",
			"options": [],
			"examples": []
		}
	},
	"cd": {
		"reference": funcref(self, "cd"),
		"manual": {
			"name": "cd - définis le chemin courant comme étant la cible.",
			"synopsis": ["[b]cd[/b] [[u]chemin[/u]]"],
			"description": "Définis la variable $PWD comme étant le chemin absolu de la destination ciblée par le chemin donné. Ne pas donner de chemin revient à écrire la racine, \"/\".",
			"options": [],
			"examples": [
				"cd folder",
				"cd"
			]
		}
	},
	"touch": {
		"reference": funcref(self, "touch"),
		"manual": {
			"name": "touch - crée un nouveau fichier selon la destination donnée.",
			"synopsis": ["[b]touch[/b] [u]chemin[/u]"],
			"description": "La commande crée un nouveau fichier avec le nom donné dans le chemin. La cible doit nécessairement être un fichier. Pour créer un dossier, il vous faut utiliser la commande \"mkdir\".",
			"options": [],
			"examples": [
				"touch folder/file.txt"
			]
		}
	},
	"mkdir": {
		"reference": funcref(self, "mkdir"),
		"manual": {
			"name": "mkdir - crée un nouveau dossier selon la destination donnée.",
			"synopsis": ["[b]mkdir[/b] [u]chemin[/u]"],
			"description": "La commande crée un nouveau dossier avec le nom donné dans le chemin. Pour créer un fichier, vous devriez utiliser la commande \"touch\".",
			"options": [],
			"examples": [
				"mkdir folder/newfolder"
			]
		}
	},
	"rm": {
		"reference": funcref(self, "rm"),
		"manual": {
			"name": "rm - supprime de manière définitive un élément.",
			"synopsis": ["[b]rm[/b] [[b]-rd[/b]] [u]file[/u]"],
			"description": "Cette commande permet de supprimer un fichier, ou un dossier si spécifiée avec l'option -d. Par défaut, un dossier qui n'est pas vide ne peut être supprimé, sauf si l'option -r (pour \"récursif\") est mentionnée.",
			"options": [
				{
					"name": "d",
					"description": "Permet de supprimer un dossier. Inutile si -r est mentionnée."
				},
				{
					"name": "r",
					"description": "Permet de supprimer un dossier et son contenu avec."
				}
			],
			"examples": [
				"rm file.txt",
				"rm -d emptyfolder",
				"rm -r folder"
			]
		}
	},
	"cp": {
		"reference": funcref(self, "cp"),
		"manual": {
			"name": "cp - copie un élément vers une aute destination.",
			"synopsis": ["[b]cp[/b] [u]origine[/u] [u]destination[/u]"],
			"options": [],
			"description": "Réalise la copie de l'élément d'origine vers la nouvelle destination. La copie devient indépendante de l'originale. Si une copie d'un dossier vers un autre dossier est réalisée, et que cet autre dossier contient des fichiers de même nom que le premier, alors ces fichiers seront remplacés, leur contenu ainsi perdu.",
			"examples": [
				"cp file.txt copiedfile.txt",
				"cp file.txt folder/file.txt",
				"cp folder copiedfolder"
			]
		}
	},
	"mv": {
		"reference": funcref(self, "mv"),
		"manual": {
			"name": "mv - déplace un élément vers une nouvelle destination.",
			"synopsis": ["[b]mv[/b] [u]origine[/u] [u]destination[/u]"],
			"description": "Déplace un élément d'origine vers une nouvelle destination. Ceci permet de renommer un élément. Si un déplacement a lieu d'un élément vers un autre qui existe déjà, alors, si la cible est un fichier, il est remplacé et l'élément d'origine est supprimé, ou s'il s'agit d'un dossier alors il est placé comme enfant de la cible.",
			"options": [],
			"examples": [
				"mv file.txt renamedfile.txt",
				"mv file.txt folder",
				"mv folder otherfolder"
			]
		}
	},
	"help": {
		"reference": funcref(self, "help"),
		"manual": {
			"name": "help - commande si vous avez besoin d'aide quant à Bash.",
			"synopsis": ["[b]help[/b]"],
			"description": "Utilisez cette commande si vous avez besoin de rappel quant au fonctionnement primaire de Bash. La commande vous propose également une liste de toutes les commandes disponibles, avec une rapide description de chacune.",
			"options": [],
			"examples": []
		}
	},
	"tree": {
		"reference": funcref(self, "tree"),
		"manual": {
			"name": "tree - affiche une reconstitution de l'arborescence du dossier courant.",
			"synopsis": ["[b]tree[/b]"],
			"description": "Cette commande est utile pour afficher le contenu du dossier courant, ainsi que le contenu des sous-dossiers, de façon à avoir une vue globale de l'environnement de travail. En revanche, elle ne permet pas de visualiser les fichiers cachés.",
			"options": [],
			"examples": []
		}
	},
	"chmod": {
		"reference": funcref(self, "chmod"),
		"manual": {
			"name": "chmod - définis les permissions accordées à un élément.",
			"synopsis": ["[b]chmod[/b] [u]mode[/u] [u]fichier[/u]"],
			"description": "Il y a trois catégories (utilisateur, groupe, autres) qui ont chacune trois type d'autorisations : lecture (r), écriture (w), exécution/franchissement (x). Les permissions s'écrivent \"-rwx--xr--\" où le premier caractère est soit \"d\" pour un dossier, ou \"-\" pour un fichier et où l'utilisateur a les droits combinés \"rwx\" (lecture, écriture et exécution) et où le groupe a les droits d'exécution seulement et les autres le droit de lecture uniquement. En règle générale, les permissions sont données sous la forme de trois chiffres en octal dont la somme est une combinaison unique : 4 pour la lecture, 2 pour l'écriture et 1 pour l'exécution. Par défaut un fichier, à sa création, a les droits 644. Accordez ou retirez un droit spécifique avec \"chmod u+x file.txt\" (raccourcie en \"chmod +x file.txt\" quand il s'agit de l'utilisateur, ([b]u[/b] pour utilisateur, [b]g[/b] pour groupe, [b]o[/b] pour autres)), ou détaillez la règle en octal à appliquer sur les trois catégories (\"chmod 657 file.txt\").",
			"options": [],
			"examples": [
				"chmod u+x file.txt",
				"chmod g-x folder/",
				"chmod o-r folder/",
				"chmod 007 file.txt"
			]
		}
	},
	"nano": {
		"reference": funcref(self, "nano"),
		"manual": {
			"name": "nano - ouvre un éditeur pour éditer un fichier dans le terminal.",
			"synopsis": ["[b]nano[/b] [u]fichier[/u]"],
			"description": "Nano est l'éditeur par défaut de Bash. Utilisez cette commande pour éditer un fichier déjà existant. Si le fichier cible n'existe pas il sera créé. La version de Nano proposée ici est modifiée pour convenir à une utilisation à la souris.",
			"options": [],
			"examples": [
				"nano file.txt"
			]
		}
	},
	"seq": {
		"reference": funcref(self, "seq"),
		"manual": {
			"name": "seq - affiche une séquence de nombre.",
			"synopsis": ["[b]seq[/b] [[b]-s[/b] [u]string[/u]] [[b]-t[/b] [u]string[/u]] [[u]début[/u] [[u]saut[/u]]] [u]fin[/u]"],
			"description": "Affiche une séquence de nombres, avec un nombre par ligne. La séquence commence à 1 par défaut et s'incrémente de 1 par défaut (le \"saut\" est de 1). Si la fin est inférieure au début, le saut sera par défaut de -1. Si le saut donné n'est pas négatif, une erreur sera renvoyée. Le séparateur entre chaque nombre peut être défini avec l'option -s, et la fin de la séquence peut être personnalisée avec l'option -t.",
			"options": [
				{
					"name": "s",
					"description": "Permet de définir le séparateur entre chaque nombre de la séquence."
				},
				{
					"name": "t",
					"description": "Permet d'afficher une chaine de caractères précise à la fin de la séquence."
				}
			],
			"examples": [
				"seq 10 0",
				"seq 10 5 50",
				"seq -s ',' 10 20",
				"seq -t 'LANCEMENT' 10 0"
			]
		}
	},
	"ping": {
		"reference": funcref(self, "ping"),
		"manual": {
			"name": "ping - établis une connexion simple à une autre adresse.",
			"synopsis": ["[b]ping[/b] [u]adresse[/u]"],
			"description": "Des paquets très simples sont envoyés à l'adresse cible. La cible peut être une adresse IP ou l'URL directement. Si une URL est précisée, alors la commande ira chercher dans le serveur DNS le plus proche l'adresse IP de la destination.",
			"options": [],
			"examples": [
				"ping example.com",
				"ping 192.168.10.1"
			]
		}
	},
	"head": {
		"reference": funcref(self, "head"),
		"manual": {
			"name": "head - affiche les premières lignes d'un fichier.",
			"synopsis": ["[b]head[/b] [[b]-n[/b] [u]nombre[/u]] [[u]fichier[/u]]"],
			"description": "Par défaut, les 10 premières lignes du fichier sont affichées. Précisez le nombre de lignes désirées avec l'option -n.",
			"options": [
				{
					"name": "n",
					"description": "Précise le nombre de lignes voulues."
				}
			],
			"examples": [
				"head file.txt",
				"head -n 1 file.txt",
				"cat file.txt | head"
			]
		}
	},
	"tail": {
		"reference": funcref(self, "tail"),
		"manual": {
			"name": "tail - affiche les dernières lignes d'un fichier.",
			"synopsis": ["[b]tail[/b] [[b]-n[/b] [u]nombre[/u]] [[u]fichier[/u]]"],
			"description": "Par défaut, les 10 dernières lignes du fichier sont affichées. Précisez le nombre de lignes désirées avec l'option -n.",
			"options": [
				{
					"name": "n",
					"description": "Précise le nombre de lignes voulues."
				}
			],
			"examples": [
				"tail file.txt",
				"tail -n 1 file.txt",
				"cat file.txt | tail"
			]
		}
	},
	"startm99": {
		"reference": funcref(self, "startm99"),
		"manual": {
			"name": "startm99 - commande custom pour démarrer un simulateur de langage Assembler appelé M99.",
			"synopsis": ["[b]startm99[/b]"],
			"description": "Démarre un simulateur pédadogique pour apprendre les bases d'un langage Assembler.",
			"options": [],
			"examples": []
		}
	}
}

static func replace_bbcode(text: String, replacement: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[\\/?(?:b|i|u|s|left|center|right|quote|code|list|img|spoil|color).*?\\]")
	var search := regex.search_all(text)
	var result := text
	for r in search:
		result = result.replace(r.get_string(), replacement)
	return result

static func cut_paragraph(paragraph: String, line_length: int) -> Array:
	if paragraph.length() <= line_length:
		return [paragraph]
	var lines := []
	var i := 0
	var pos := 0
	while i < (paragraph.length() / line_length):
		var e := 0
		while (pos+line_length+e) < paragraph.length() and paragraph[pos+line_length+e] != " ":
			e += 1
		lines.append(paragraph.substr(pos, line_length + e).strip_edges())
		pos += line_length + e
		i += 1
	lines.append(paragraph.substr(pos).strip_edges())
	return lines

static func build_manual_page_using(manual: Dictionary, max_size: int) -> String:
	var output := ""
	output += "[b]NOM[/b]\n\t" + manual.name + "\n\n"
	output += "[b]SYNOPSIS[/b]\n"
	for synopsis in manual.synopsis:
		output += "\t" + synopsis
	output += "\n\n[b]DESCRIPTION[/b]\n"
	var description_lines := cut_paragraph(manual.description, max_size)
	for line in description_lines:
		output += "\t" + line + "\n"
	if not manual.options.empty():
		output += "[b]OPTIONS[/b]\n"
		for option in manual.options:
			output += "\t[b]" + option.name + "[/b]\n"
			output += "\t\t" + option.description + "\n"
	if not manual.examples.empty():
		output += "\n[b]EXEMPLES[/b]\n"
		for example in manual.examples:
			output += "\t" + example + "\n"
	return output

static func build_help_page(text: String, commands: Dictionary) -> String:
	var output := text + "\n\n"
	var max_synopsis_size := 40
	var max_description_size := 60
	for command in commands:
		var synopsis = replace_bbcode(commands[command].manual.synopsis[0], "")
		var description = replace_bbcode(commands[command].manual.name, "")
		var space = max_synopsis_size - synopsis.length()
		description = description.right(description.find("-"))
		output += synopsis.left(max_synopsis_size) + (" ".repeat(space + 3) if synopsis.length() < max_synopsis_size else "") + ("..." if synopsis.length() > max_synopsis_size else "") + " " + description.left(max_description_size) + ("..." if description.length() > max_description_size else "") + "\n"
	return output

# Define a terminal with its unique PID.
# Set what System the terminal has to be using.
# `editor` is the scene to use for file editing (it must be an instance of WindowPopup)
# however `editor` is optional (null by default).
func _init(p: int, sys: System, editor = null):
	pid = p
	system = sys
	if editor != null and editor is WindowDialog:
		set_editor(editor)

func set_editor(editor: WindowDialog) -> void:
	if nano_editor != null:
		# If the editor is being changed,
		# then we want to make sure that the old editor
		# doesn't receive the signals anymore.
		(nano_editor.get_node("Button") as Button).disconnect("pressed", self, "_on_nano_saved")
	var save_button: Button = (editor as WindowDialog).get_node("Button")
	save_button.connect("pressed", self, "_on_nano_saved")
	nano_editor = editor

func set_dns(d: DNS) -> void:
	dns = d

func use_interface(interface: RichTextLabel) -> void:
	interface_reference = interface

func set_custom_text_width(max_char: int) -> void:
	max_paragraph_width = max_char

# Configures the IP address of the terminal.
# It will be used when using the `ping` command.
# Returns false if the given ip is not valid.
func set_ip_address(ip: String) -> bool:
	if ip.is_valid_ip_address():
		ip_address = ip
		return true
	return false

func _write_to_redirection(redirection: Dictionary, output: String) -> void:
	if redirection.type == Tokens.WRITING_REDIRECTION:
		redirection.target.content = output
	elif redirection.type == Tokens.APPEND_WRITING_REDIRECTION:
		redirection.target.content += output

func _save_interface(interface: RichTextLabel):
	if interface == null:
		interface = interface_reference # if no interface is given to this function, then use the previous one
	else:
		interface_reference = interface # if an interface is given, then save it, it's useful for the M99
	return interface

func execute(input: String, interface: RichTextLabel = null) -> Dictionary:
	interface = _save_interface(interface)
	var parser := BashParser.new(input, pid)
	if not parser.error.empty():
		return {
			"error": parser.error
		}
	var parsing := parser.parse(runtime[0])
	if not parser.error.empty():
		return {
			"error": parser.error
		}
	var standard_input := ""
	var cleared := false
	for command in parsing:
		if command.type == "command":
			if m99.started:
				if not command.redirections.empty():
					return {
						"error": "m99 n'accepte aucune redirection."
					}
				return execute_m99_command(command.name, command.options, interface)
			var function = COMMANDS[command.name] if command.name in COMMANDS else null
			if function == null and command.name.find('/') != -1:
				var path_to_executable := PathObject.new(command.name)
				if path_to_executable.is_valid:
					var executable = get_file_element_at(path_to_executable)
					if executable == null:
						return {
							"error": _display_error_or("Le fichier n'existe pas")
						}
					if not executable.is_file():
						return {
							"error": "L'élément n'est pas un fichier !"
						}
					if not executable.can_execute_or_go_through():
						return {
							"error": "Permission refusée"
						}
					return execute_file(executable, command.options, interpret_redirections(command.redirections), interface)
			# if the function doesn't exist,
			# function.reference.is_valid() will be false.
			if function == null or not function.reference.is_valid():
				return {
					"error": "Cette commande n'existe pas."
				}
			else:
				var command_redirections = interpret_redirections(command.redirections)
				if error_handler.has_error:
					return {
						"error": "Commande '" + command.name + "' : " + error_handler.clear()
					}
				for i in range(0, command_redirections.size()):
					if command_redirections[i] != null and command_redirections[i].target == null:
						return {
							"error": "Impossible de localiser, ni de créer, la destination du descripteur " + str(i) + "."
						}
				var result = function.reference.call_func(command.options, command_redirections[0].target.content if command_redirections[0] != null and command_redirections[0].type == Tokens.READING_REDIRECTION else standard_input)
				if command_redirections[2] != null:
					if result.error == null:
						if command_redirections[2].type == Tokens.WRITING_REDIRECTION:
							command_redirections[2].target.content = ""
					else:
						emit_signal("error_thrown", command, result.error)
						if command_redirections[2].type == Tokens.WRITING_REDIRECTION:
							command_redirections[2].target.content = "Commande '" + command.name + "' : " + result.error
						elif command_redirections[2].type == Tokens.APPEND_WRITING_REDIRECTION:
							command_redirections[2].target.content += "Commande '" + command.name + "' : " + result.error
						return {
							"output": "",
							"interface_cleard": false,
							"error": null
						} # if there is an error, we have to stop the program anyway
				if result.error != null:
					emit_signal("error_thrown", command, result.error)
					return {
						"error": "Commande '" + command.name + "' : " + result.error
					}
				else:
					emit_signal("command_executed", command, result.output)
					if m99.started:
						if interface != null:
							interface.text = ""
						cleared = true
						standard_input = result.output
						break
					if command_redirections[0] != null:
						# Even though it doesn't make any sense to try to write something
						# to the standard input, Bash overwrites the content of the target anyway.
						# We have to reproduce the same behaviour, no matter how weird it sounds.
						# The output to apply on the standard input would always be an empty string.
						# If the standard input doesn't have a writing redirection (> or >>),
						# then this function won't do anything.
						_write_to_redirection(command_redirections[0], "")
					if command_redirections[1] != null:
						_write_to_redirection(command_redirections[1], result.output)
					else:
						standard_input = result.output
					if command.name == "clear":
						cleared = true
						if interface != null:
							emit_signal("interface_cleared")
		else: # the line is a variable affectation
			var is_new = runtime[0].set_variable(command.name, command.value) # command.value is a BashToken
			emit_signal("variable_set", command.name, command.value.value, is_new)
	if interface != null and not standard_input.empty():
		emit_signal("interface_changed", standard_input)
	return {
		"output": standard_input,
		"interface_cleared": cleared,
		"error": null
	}

# Executes a script.
# We assume that the given file is executable.
# Note that the standard input is ignored.
# Also, because there is no functions in our Bash,
# we don't interpret the arguments (`options`) given to the command.
func execute_file(file: SystemElement, options: Array, redirections: Array, interface: RichTextLabel = null) -> Dictionary:
	_save_interface(interface)
	var lines = file.content.split("\n")
	var output := "" # the output will be the list of the output of each line
	var cleared := false
	for line in lines:
		if line.begins_with("#"): # ignore comments (line starting with '#')
			continue
		else:
			var result := execute(line, null)
			if redirections[2] != null:
				if result.error == null:
					if redirections[2].type == Tokens.WRITING_REDIRECTION:
						redirections[2].target.content = ""
				else:
					if redirections[2].type == Tokens.WRITING_REDIRECTION:
						redirections[2].target.content = result.error
					elif redirections[2].type == Tokens.APPEND_WRITING_REDIRECTION:
						redirections[2].target.content += result.error
					return {
						"output": "",
						"interface_cleared": false,
						"error": null
					}
			if result.error != null:
				return {
					"error": result.error
				}
			else:
				output += result.output
				if result.interface_cleared:
					cleared = true
					output = "" # reset the output
	# The redirections must be treated after the end of the script,
	# except for the port number 2 because it has to stop the execution
	if redirections[0] != null:
		_write_to_redirection(redirections[0], "") # the weird behaviour described above, in `execute()`
	if redirections[1] != null:
		# If a standard output is used in the command,
		# then it will receive the content of the combined outputs
		_write_to_redirection(redirections[1], output)
		emit_signal("script_executed", file, output)
		output = "" # the command (the execution of the script itself) won't output anything
	elif interface != null and not output.empty():
		emit_signal("script_executed", file, output)
	return {
		"output": output,
		"interface_cleared": cleared,
		"error": null
	}

# Custom commands when using M99.
# Exemple is : set 090 401
# meaning set cell at pos 090 with value 401
func execute_m99_command(command_name: String, options: Array, interface: RichTextLabel = null) -> Dictionary:
	_save_interface(interface)
	if command_name == "man":
		var manual = man(options, "")
		if manual.error != null:
			return manual
		else:
			return {
				"output": "Le manuel a été ouvert.\nTapez la commande \"show\" pour en sortir.\n\n" + manual.output,
				"error": null,
				"interface_cleared": true
			}
	elif command_name == "help":
		return {
			"output": build_help_page(m99.help_text, m99.COMMANDS),
			"interface_cleared": true,
			"error": null,
		}
	var function = m99.COMMANDS[command_name] if command_name in m99.COMMANDS else null
	if function == null or not function.reference.is_valid():
		return {
			"error": "Cette commande n'existe pas."
		}
	else:
		var result = function.reference.call_func(options)
		var cleared := false
		var output := ""
		if result.error != null:
			return result
		if command_name == "exit":
			output = "M99 a été arrêté."
			cleared = true
		else:
			if result.modified_program:
				cleared = true
				output = m99.buildm99()
			output += result.output
		output += "\n"
		return {
			"output": output,
			"interface_cleared": cleared,
			"error": null,
		}

# Returns the SystemElement instance located at the given path.
# Returns null if the element doesn't exist.
# Might throw an error using the ErrorHandler,
# such as denial of permission (x).
func get_file_element_at(path: PathObject):
	var result = system.get_file_element_at(path, PWD) # might be SystemElement, null or String
	if result is String: # if we got a String, it means it was a specific error
		return error_handler.throw_error(result)
	return result

# Pretty much the same thing as `get_file_element_at`
# but because we know we want to get the element located at PWD,
# we use this to gain a little bit of performance.
# We don't want to end up using `system.get_file_element_at(PWD, PWD)`.
func get_pwd_file_element() -> SystemElement:
	var result = system.get_element_with_absolute_path(PWD)
	if result is String:
		return error_handler.throw_error(result)
	return result

func get_parent_element_from(path: PathObject) -> SystemElement:
	return get_file_element_at(PathObject.new(path.parent) if path.parent != null else PWD)

func copy_element(e: SystemElement) -> SystemElement:
	var ref := SystemElement.new(e.type, e.filename, e.base_dir, e.content, copy_children_of(e), user_name, group_name)
	ref.permissions = e.permissions # important to have the same permissions on the copy
	return ref

func copy_children_of(e: SystemElement) -> Array:
	var list := []
	for child in e.children:
		list.append(copy_element(child))
	return list

# Merges two file elements.
# The origin can be a file or a folder,
# but the destination must be a folder.
# If the origin is a file and destination contains the same file,
# then the file inside the destination will receive the origin's content.
# If the origin is a folder, then the files with the same name will get replaced,
# and the new files will be appened to the destination.
# Returns true for success, false for failure
func merge(origin: SystemElement, destination: SystemElement) -> bool:
	if destination == null or not destination.is_folder():
		return false
	var found_same_filename_inside_folder := false
	if origin.is_file():
		for child in destination.children:
			if child.filename == origin.filename:
				child.content = origin.content
				found_same_filename_inside_folder = true
				return true
		if not found_same_filename_inside_folder:
			destination.append(copy_element(origin).move_inside_of(destination.absolute_path))
	else:
		for child1 in origin.children:
			for child2 in destination.children:
				if child2.filename == child1.filename:
					child2.content = child1.content
					found_same_filename_inside_folder = true
					break
			if not found_same_filename_inside_folder:
				destination.append(copy_element(child1).move_inside_of(destination.absolute_path))
			else:
				found_same_filename_inside_folder = false
	return true

# Moves an element to a new destination.
# This function deletes the origin.
func move(origin: SystemElement, destination: PathObject) -> bool:
	if not destination.is_valid or origin == null:
		return false
	var new_name: String = origin.filename if destination.is_leading_to_folder() else destination.file_name
	var origin_parent: SystemElement = get_parent_element_from(origin.absolute_path)
	var destination_dir: SystemElement = get_file_element_at(destination) if destination.is_leading_to_folder() else get_parent_element_from(destination)
	if destination_dir == null:
		return false
	if not destination_dir.can_execute_or_go_through() or not destination_dir.can_write() or not origin.can_write():
		return error_handler.throw_permission_error(false)
	var copy = copy_element(origin)
	copy.rename(new_name)
	copy.move_inside_of(destination_dir.absolute_path)
	destination_dir.append(copy)
	origin_parent.children.erase(origin)
	emit_signal("file_moved", origin, copy)
	return true

# Example:
# When we have redirections,
# if the file doesn't exist on the standard output,
# then we must create it.
func get_file_or_make_it(path: PathObject):
	if path.is_leading_to_folder():
		return null
	var element: SystemElement = get_file_element_at(path)
	if error_handler.has_error:
		return null
	if not element == null:
		return element
	var parent_element = get_parent_element_from(path)
	if parent_element == null or not parent_element.is_folder():
		return null
	var new_file := SystemElement.new(0, path.file_name, parent_element.absolute_path.path, "", [], user_name, group_name)
	emit_signal("file_created", new_file)
	parent_element.append(new_file)
	return new_file

# Read the redirections of a command
# in order to make the following model:
# [standard_input, standard_output, error_output]
# where all three are either null or an object:
# { "type": String (Tokens.WRITING_REDIRECTION for example), "target": SystemElement }
func interpret_redirections(redirections: Array) -> Array:
	var result := [null, null, null]
	for i in range(0, redirections.size()):
		if redirections[i].copied:
			result[redirections[i].port] = result[redirections[i].target]
		else:
			result[redirections[i].port] = redirections[i]
	if result[0] != null:
		var target: SystemElement = get_file_element_at(PathObject.new(result[0].target))
		if error_handler.has_error:
			target = null
		elif target == null:
			error_handler.throw_error("Le fichier n'existe pas.")
		elif target.is_folder():
			error_handler.throw_error("La cible de l'entrée standard est un dossier.")
		elif not target.can_read():
			error_handler.throw_permission_error()
		result[0] = {
			"type": result[0].type,
			"target": target
		}
	for i in range(1, result.size()):
		if result[i] != null:
			var path := PathObject.new(result[i].target)
			var target = null
			if not path.is_valid:
				error_handler.throw_error("Le chemin de la redirection " + str(i) + " n'est pas valide.")
			else:
				target = get_file_or_make_it(path)
				if error_handler.has_error:
					target = null
				elif target == null:
					error_handler.throw_error("Redirection " + str(i) + " invalide.")
				elif target.is_folder():
					error_handler.throw_error("La cible de la redirection " + str(i) +" est un dossier.")
				elif not target.can_write():
					error_handler.throw_permission_error()
			result[i] = {
				"type": result[i].type,
				"target": target
			}
	return result

func man(options: Array, _standard_input: String) -> Dictionary:
	var commands_list: Dictionary
	if m99.started:
		commands_list = m99.COMMANDS
	else:
		commands_list = self.COMMANDS
	if options.size() == 0:
		return {
			"error": "quelle page du manuel désirez-vous ?"
		}
	if options.size() > 1 or not options[0].is_word():
		return {
			"error": "uniquement le nom d'une commande est attendue."
		}
	var page := ""
	if options[0].value == "man":
		page = build_manual_page_using(self.COMMANDS["man"].manual, max_paragraph_width)
	else:
		if not options[0].value in commands_list:
			return {
				"error": "'" + options[0].value + "' est une commande inconnue"
			}
		page = build_manual_page_using(commands_list[options[0].value].manual, max_paragraph_width)
	emit_signal("manual_asked", options[0].value, page)
	return {
		"output": page,
		"error": null
	}

func help(options: Array, _standard_input: String) -> Dictionary:
	if options.size() > 0:
		return {
			"error": "aucun argument n'est attendu"
		}
	var output := "Ce terminal vous permet d'écrire des commandes Bash simplifiées.\nLe but est pédagogique. Vous pouvez apprendre des commandes et vous entrainer.\nLes commandes ont été reproduites le plus fidèlement possible, mais quelques différences peuvent apparaître.\n\nRappels sur comment écrire une commande :\nUne commande vous permet de manipuler les fichiers et dossiers de votre environnement de travail.\nEn règle générale, la syntaxe pour une commande ressemble à ça : [b]nom_de_la_commande[/b] [...[b]options[/b]] [...[b]arguments[/b]].\n\nUtilisez des redirections pour modifier le comportement d'une commande. Une redirection est un numéro : \n- 0 : entrée standard\n- 1 : sortie standard\n- 2 : sortie d'erreur\nExemple : head file.txt 1>resultat.txt (réécris, ou crée, le fichier \"resultat.txt\" avec le résultat écrit de la commande).\nUtilisez les symboles :\n- > : réécris le fichier\n- < : lis le fichier\n- >> : ajoute au fichier\n\nEnchainez des commandes sur la même ligne en les séparant par un \"|\" (\"pipe\" en anglais).\nL'entrée standard de la commande suivante sera le résultat écrit de la commande précédente.\nExemple : echo yoyo | cat"
	emit_signal("help_asked")
	return {
		"output": build_help_page(output, COMMANDS),
		"error": null
	}

func echo(options: Array, _standard_input: String) -> Dictionary:
	var to_display := ""
	var line_break := true
	for option in options:
		if option.is_eof():
			break
		if option.is_flag():
			if option.value == "n":
				if line_break:
					line_break = false
			else:
				to_display += "-" + option.value
		else:
			to_display += " " + option.value
	return {
		"output": to_display.strip_edges() + ("\n" if line_break else ""),
		"error": null
	}

func grep(options: Array, standard_input: String) -> Dictionary:
	if standard_input.empty():
		return {
			"error": "Une entrée standard doit être spécifiée"
		}
	var pattern = null
	var show_count := false
	for option in options:
		if pattern != null:
			return {
				"error": "erreur de syntaxe, censé être : " + COMMANDS.grep.manual.synopsis
			}
		if option.is_word():
			pattern = option.value
		elif option.is_flag():
			if option.value == "c":
				show_count = true
			else:
				return {
					"error": "l'option '" + option.value + "' est inconnue."
				}
		else:
			return {
				"error": "token inattendu"
			}
	if pattern == null:
		return {
			"error": "un pattern doit être spécifié."
		}
	var regex := RegEx.new()
	regex.compile(pattern)
	var lines := standard_input.split("\n", false)
	var output := ""
	if show_count:
		var total := 0
		for line in lines:
			var search := regex.search_all(line)
			total += search.size()
		output = str(total)
	else:
		for line in lines:
			var search := regex.search(line)
			if search != null:
				output += line.replace(search.get_string(), "[color=blue]" + search.get_string() + "[/color]") + "\n"
	return {
		"output": output,
		"error": null
	}

# `tr` already exists and cannot be redefined to match the required signature,
# hence the "_" at the end of the functions' name.
# Such exception must be handled manually.
func tr_(options: Array, standard_input: String) -> Dictionary:
	if standard_input.empty() or options.size() != 2:
		return {
			"error": "deux pattern doivent être spécifiés"
		}
	var del := false
	if options[0].is_flag():
		if options[0].value == "d":
			del = true
		else:
			return {
				"error": "l'option '" + options[0].value + "' est inconnue."
			}
	var to_replace := RegEx.new()
	to_replace.compile(options[1].value if del else options[0].value)
	var search := to_replace.search(standard_input)
	var output := standard_input
	if search != null:
		if del:
			output = standard_input.replace(search.get_string(), "")
		else:
			var wanted_string := search.get_string()
			var wanted_length := wanted_string.length()
			var replacement := options[1].value.repeat(wanted_length/options[1].value.length() + 1).left(wanted_length) as String
			output = standard_input.replace(wanted_string, replacement)
	return {
		"output": output,
		"error": null
	}

func cat(options: Array, standard_input: String) -> Dictionary:
	if options.size() > 1:
		return { "error": "trop d'arguments" }
	if options.size() == 0:
		# something weird about the "cat" command...
		# if no file is given as argument,
		# but a file is given in the standard input,
		# then the standard input becomes the output
		return {
			"output": standard_input,
			"error": null
		}
	if not options[0].is_word():
		return {
			"error": "un chemin est attendu"
		}
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return {
			"error": "le chemin n'est pas valide"
		}
	var element = get_file_element_at(path)
	if element == null:
		return {
			"error": _display_error_or("la destination n'existe pas")
		}
	if not element.is_file():
		return {
			"error": "la destination doit être un fichier !"
		}
	if not element.can_read():
		return {
			"error": "Permission refusée"
		}
	var output = (element.content if not element.content.empty() else "Le fichier est vide.") + "\n"
	emit_signal("file_read", element)
	return {
		"output": output,
		"error": null
	}

func ls(options: Array, _standard_input: String) -> Dictionary:
	var target = null
	var hide_secret_elements = true
	var show_stats = false
	for option in options:
		if option.is_word():
			var path := PathObject.new(option.value)
			if not path.is_valid:
				return {
					"error": "chemin invalide."
				}
			target = get_file_element_at(path)
			if target == null:
				return {
					"error": _display_error_or("la destination n'existe pas")
				}
			if target.is_folder() and (not target.can_execute_or_go_through() or not target.can_read()):
				return {
					"error": "Permission refusée"
				}
			break
		elif option.is_flag():
			if option.value == "a":
				hide_secret_elements = false
			elif option.value == "l":
				show_stats = true
			else:
				return {
					"error": "l'option \"" + option.value + "\" est inconnue."
				}
		else:
			return {
				"error": "une option ou un chemin est attendu"
			}
	if target == null:
		target = get_pwd_file_element()
	var output := ""
	if show_stats:
		if target.is_folder():
			for child in target.children:
				if hide_secret_elements and child.is_hidden():
					continue
				else:
					output += child.info_long_format()
		else:
			output += target.info_long_format()
	else:
		if target.is_file():
			return {
				"output": target.filename,
				"error": null
			}
		for child in target.children:
			if hide_secret_elements and child.is_hidden():
				continue
			else:
				if child.is_folder():
					output += "[color=green]" + child.filename + "[/color]\n"
				else:
					output += child.filename + "\n"
	return {
		"output": output,
		"error": null
	}

func clear(_options: Array, _standard_input: String) -> Dictionary:
	return {
		"output": "",
		"error": null
	}

func tree(_options: Array, _standard_input: String) -> Dictionary:
	return {
		"output": get_pwd_file_element().to_string(), # this is using the default _to_string methods recursively on the children of the root
		"error": null
	}

func pwd(options: Array, _standard_input: String) -> Dictionary:
	if options.size() != 0:
		return {
			"error": "aucun argument n'est attendu."
		}
	return {
		"output": PWD.path + "\n",
		"error": null
	}

func cd(options: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0:
		PWD = PathObject.new("/")
		return { "output": "", "error": null }
	elif options.size() > 1:
		return {
			"error": "un seul chemin est attendu."
		}
	if not options[0].is_word():
		return {
			"error": "l'argument '" + options[0].value + "' doit être un chemin."
		}
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return {
			"error": "le chemin donné n'est pas valide."
		}
	var element = get_file_element_at(path)
	if element == null:
		return {
			"error": _display_error_or("la destination n'existe pas.")
		}
	if element.is_file():
		return {
			"error": "la destination doit être un dossier."
		}
	if not element.can_execute_or_go_through():
		return {
			"error": "Permission refusée"
		}
	PWD = element.absolute_path
	emit_signal("directory_changed", PWD)
	return {
		"output": "",
		"error": null
	}

func touch(options: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0 or not options[0].is_word():
		return {
			"error": "un chemin est attendu en argument"
		}
	if options.size() > 1:
		return {
			"error": "un seul chemin est attendu en argument"
		}
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return {
			"error": "le chemin n'est pas valide"
		}
	var element = get_file_element_at(path)
	if error_handler.has_error:
		return {
			"error": error_handler.clear()
		}
	if element != null: # if the file already exists, we ignore
		return {
			"output": "",
			"error": null
		}
	if path.is_leading_to_folder():
		return {
			"error": "la cible n'est pas un fichier"
		}
	var parent = get_parent_element_from(path)
	if parent == null or not parent.is_folder():
		return {
			"error": "le dossier du fichier à créer n'existe pas"
		}
	if not parent.can_write():
		return {
			"error": "permission refusée"
		}
	var file := SystemElement.new(0, path.file_name, parent.absolute_path.path, "", [], user_name, group_name)
	emit_signal("file_created", file)
	parent.append(file)
	return {
		"output": "",
		"error": null
	}

func mkdir(options: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0 or not options[0].is_word():
		return {
			"error": "un chemin valide est attendu"
		}
	if options.size() > 1:
		return {
			"error": "un seul et unique chemin est attendu"
		}
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return {
			"error": "le chemin n'est pas valide"
		}
	var element = get_file_element_at(path)
	if error_handler.has_error:
		return {
			"error": error_handler.clear()
		}
	if element != null:
		return {
			"error": "la destination existe déjà"
		}
	var parent = get_parent_element_from(path)
	if parent == null or not parent.is_folder():
		return {
			"error": "Le dossier parent de la destination n'existe pas"
		}
	if not parent.can_write():
		return {
			"error": "permission refusée"
		}
	var folder := SystemElement.new(1, path.segments[-1], parent.absolute_path.path, "", [], user_name, group_name)
	emit_signal("file_created", folder)
	parent.append(folder)
	return {
		"output": "",
		"error": null
	}

func rm(options: Array, _standard_input: String) -> Dictionary:
	if options.size() == 0:
		return {
			"error": "une destination est attendue"
		}
	var directory = false
	var recursive = false
	var i = 0
	while i < options.size() and options[i].is_flag():
		if options[i].value == "d":
			directory = true
		elif options[i].value == "r":
			recursive = true
		else:
			return {
				"error": "l'option '" + options[i].value + "' est inconnue."
			}
		i += 1
	if recursive:
		directory = true
	if not options[i].is_word():
		return {
			"error": "un chemin est attendu"
		}
	var path = PathObject.new(options[i].value)
	if not path.is_valid:
		return {
			"error": "le chemin n'est pas valide"
		}
	var element: SystemElement = get_file_element_at(path)
	if element == null:
		return {
			"error": _display_error_or("la destination n'existe pas")
		}
	if element.absolute_path.equals("/"):
		return {
			"error": "tu ne peux pas supprimer la racine, p'tit malin"
		}
	if element.absolute_path.equals(PWD):
		return {
			"error": "tu ne peux pas supprimer le dossier dans lequel tu te situes"
		}
	var parent = get_parent_element_from(path)
	if parent == null:
		return {
			"error": "le dossier parent de la cible n'existe pas"
		}
	if not parent.can_write() or not element.can_write():
		return {
			"error": "permission refusée"
		}
	if element.is_file():
		parent.children.erase(element)
	else:
		if not directory:
			return {
				"error": "la cible est un dossier"
			}
		elif element.children.size() > 0 and not recursive:
			return {
				"error": "la cible n'est pas vide"
			}
		else:
			if not element.can_execute_or_go_through():
				return {
					"error": "permission refusée"
				}
			parent.children.erase(element)
	emit_signal("file_destroyed", element)
	return {
		"output": "",
		"error": null
	}

func cp(options: Array, _standard_input: String) -> Dictionary:
	var copy_directory := false
	var cp1_path = null
	var cp2_path = null
	for option in options:
		if option.is_flag():
			if option.value == "R":
				copy_directory = true
			else:
				return {
					"error": "l'option '" + option.value + "' est inconnue"
				}
		else:
			if cp1_path == null:
				cp1_path = PathObject.new(option.value)
			elif cp2_path == null:
				cp2_path = PathObject.new(option.value)
			else:
				return {
					"error": "trop d'arguments"
				}
	if cp1_path == null or not cp1_path.is_valid:
		return {
			"error": "le premier chemin est invalide."
		}
	if cp2_path == null or not cp2_path.is_valid:
		return {
			"error": "le second chemin est invalide."
		}
	var cp1: SystemElement = get_file_element_at(cp1_path)
	var cp2: SystemElement = get_file_element_at(cp2_path)
	if error_handler.has_error:
		return {
			"error": error_handler.clear()
		}
	if cp1 == null:
		return {
			"error": "le fichier d'origine doit exister"
		}
	if cp2 != null and cp1.equals(cp2):
		return {
			"error": "les éléments sont identiques"
		}
	# possible combinations:
	# if cp1 a file:
	# 	if cp2 exists:
	#   		if cp2 is file:
	#			copy the content of cp1 to cp2
	#		else:
	#			cp2 is a folder, if found file with the same name as cp1 then copy the content of cp1 to this file
	#			otherwise create the file which is a copy of cp1
	#	else:
	#		cp2 doesn't exist, we have to create it
	#		if the path of cp2 ressembles one of a folder, then create the folder of name cp2 and set cp1 as a child
	#		otherwise create the file cp2 which is basically a copy of cp1 but with the path of cp2
	# else:
	#	if cp2 exists:
	#		if cp2 is not a folder, then throw an error
	#		if -R is not used, then throw an error
	#		if the folder ends with a "/", then merge the content of the two files
	#		otherwise copy the folder as a child of the target.
	#	else:
	#		create a folder and copy cp1's children
	if cp1.is_file():
		if cp2 != null:
			if cp2.is_file():
				cp2.content = cp1.content
				emit_signal("file_copied", cp1, cp2)
			else:
				if not cp2.can_execute_or_go_through() or not cp2.can_write():
					return {
						"error": "Permission refusée"
					}
				merge(cp1, cp2)
				emit_signal("file_copied", cp1, cp2)
		else:
			if cp2_path.is_leading_to_folder():
				return {
					"error": "destination inconnue"
				}
			var parent_element := get_parent_element_from(cp2_path)
			if parent_element == null:
				return {
					"error": "le chemin du dossier parent de la cible n'existe pas"
				}
			var new_file := SystemElement.new(
				0,
				cp2_path.file_name,
				parent_element.absolute_path.path,
				cp1.content,
				[],
				user_name,
				group_name
			)
			new_file.permissions = cp1.permissions
			parent_element.append(new_file)
			emit_signal("file_copied", cp1, new_file)
	else:
		if cp2 != null:
			if not cp2.is_folder():
				return {
					"error": "si l'origine est un dossier alors la cible doit être un dossier aussi"
				}
			if not copy_directory:
				return {
					"error": cp1.filename + " est un dossier (rien n'a été copié)"
				}
			if not cp2.can_execute_or_go_through() or not cp2.can_write():
				return {
					"error": "Permission refusée"
				}
			# when the option -R is given,
			# if the path is ending with a "/"
			# then the entire content is copied,
			# otherwise the folder is copied (moved but not deleted)
			if cp1_path.is_leading_to_folder():
				merge(cp1, cp2)
				emit_signal("file_copied", cp1, cp2)
			else:
				var copy := copy_element(cp1)
				copy.move_inside_of(cp2.absolute_path)
				cp2.append(copy)
				emit_signal("file_copied", cp1, cp2)
		else:
			# the destination doesn't exist,
			# create a folder and copy the entire content as its children
			var parent_element := get_parent_element_from(cp2_path)
			var children := copy_children_of(cp1)
			for child in children:
				child.move_inside_of(parent_element.absolute_path.path + "/" + cp2_path.file_name)
			var target_element := SystemElement.new(1, cp2_path.file_name, parent_element.absolute_path.path, "", children, user_name, group_name)
			target_element.permissions = cp1.permissions
			parent_element.append(target_element)
			emit_signal("file_copied", cp1, target_element)
	return {
		"output": "",
		"error": null
	}

func mv(options: Array, _standard_input: String) -> Dictionary:
	if options.size() != 2 or not options[0].is_word() or not options[1].is_word():
		return {
			"error": "deux chemins valides sont attendus"
		}
	var mv1_path := PathObject.new(options[0].value)
	var mv2_path := PathObject.new(options[1].value)
	if not mv1_path.is_valid:
		return {
			"error": "le premier chemin n'est pas valide"
		}
	if not mv2_path.is_valid:
		return {
			"error": "le second chemin n'est pas valide"
		}
	var mv1: SystemElement = get_file_element_at(mv1_path)
	var mv2: SystemElement = get_file_element_at(mv2_path)
	if error_handler.has_error:
		return {
			"error": error_handler.clear()
		}
	if mv1 == null:
		return {
			"error": "l'origine n'existe pas"
		}
	# if the origin is a file,
	# 	if the destination exists
	#		if the destination is a file,
	# 			override content of destination file with the origin's content
	#		else:
	#			move the origin inside the destination
#			delete mv1
	# 	else:
	#		move mv1 to mv2
	# else:
	#	if the destination exists:
	#		if the destination is a folder
	#			move the origine inside the destination
	#			delete mv1
	#		else:
	#			error (cannot move a folder to a file)
	#	else:
	#		move mv1 to mv2
	if mv1.is_file():
		if mv2 != null:
			var parent_mv1: SystemElement = get_parent_element_from(mv1_path)
			if mv2.is_file():
				if not mv2.can_write():
					return {
						"error": "permission refusée"
					}
				mv2.content = mv1.content
			else:
				if not mv2.can_execute_or_go_through() or not mv2.can_write():
					return {
						"error": "permission refusée"
					}
				merge(mv1, mv2)
			parent_mv1.children.erase(mv1)
			emit_signal("file_moved", mv1, mv2)
		else:
			if move(mv1, mv2_path) == false:
				return {
					"error": _display_error_or("la destination n'existe pas")
				}
	else:
		if mv2 != null:
			if mv2.is_folder():
				if not mv2.can_execute_or_go_through() or not mv2.can_write():
					return {
						"error": "permission refusée"
					}
				var parent_mv1: SystemElement = get_parent_element_from(mv1_path)
				mv2.append(copy_element(mv1).move_inside_of(mv2.absolute_path))
				parent_mv1.children.erase(mv1)
				emit_signal("file_moved", mv1, mv2)
			else:
				return {
					"error": "la destination doit être un dossier"
				}
		else:
			if move(mv1, mv2_path) == false:
				return {
					"error": _display_error_or("la destination n'existe pas")
				}
	return {
		"output": "",
		"error": null
	}

func chmod(options: Array, _standard_input: String) -> Dictionary:
	if options.size() != 2 or not options[1].is_word():
		return {
			"error": "les nouvelles permissions ainsi que la destination sont attendues, rien d'autre."
		}
	var permissions: String = ("-" + options[0].value) if options[0].is_flag() else options[0].value
	var path := PathObject.new(options[1].value)
	if not path.is_valid:
		return {
			"error": "la destination n'est pas un chemin valide"
		}
	var target: SystemElement = get_file_element_at(path)
	if target == null:
		return {
			"error": _display_error_or("la destination n'existe pas")
		}
	if target.absolute_path.equals("/"):
		return {
			"error": "évite de changer les droits de la racine frérot !"
		}
	# If the permissions are not valid for the octal format,
	# then maybe it is a valid format for a specific permission (u+x for example)
	# which is something that the method `set_specific_permission` checks for us.
	if not SystemElement.are_permissions_valid(permissions):
		if not target.set_specific_permission(permissions):
			return {
				"error": "permissions invalides"
			}
	else:
		if not target.set_permissions(permissions):
			return {
				"error": "permissions invalides"
			}
	emit_signal("permissions_changed", target)
	return {
		"output": "",
		"error": null
	}

func nano(options: Array, _standard_input: String) -> Dictionary:
	if nano_editor == null:
		return {
			"error": "ce terminal n'a pas été configuré avec un éditeur !"
		}
	if options.size() != 1 or not options[0].is_word():
		return {
			"error": "le nom du fichier est attendu (uniquement)"
		}
	var path := PathObject.new(options[0].value)
	if not path.is_valid:
		return {
			"error": "le chemin n'est pas valide"
		}
	var element = get_file_or_make_it(path) # nano can also create a file
	if error_handler.has_error:
		return {
			"error": error_handler.clear()
		}
	if element.is_folder():
		return {
			"error": "ne peut ouvrir que des fichiers"
		}
	if not element.can_read() or not element.can_write():
		return {
			"error": "permission refusée"
		}
	edited_file = element
	nano_editor.popup()
	return {
		"output": "",
		"error": null
	}

func _on_nano_saved() -> void:
	var textarea: TextEdit = (nano_editor as WindowDialog).get_node("TextEdit")
	edited_file.content = textarea.text
	emit_signal("file_changed", edited_file)
	(nano_editor as WindowDialog).hide()
	edited_file = null

func seq(options: Array, _standard_input: String) -> Dictionary:
	var start = null
	var step = null
	var end = null
	var separator := "\n"
	var ending := ""
	var numbers := []
	var i := 0
	while i < options.size():
		if options[i].is_plain() or options[i].is_negative_digit():
			if not (options[i].value as String).is_valid_integer():
				return {
					"error": "un nombre est attendu"
				}
			if options[i].is_negative_digit():
				numbers.append(int("-" + options[i].value))
			else:
				numbers.append(int(options[i].value))
		elif options[i].is_flag():
			if options[i].value == "t" or options[i].value == "s":
				var flag: String = options[i].value
				i += 1
				if i >= options.size() or not options[i].is_word():
					return {
						"error": "une valeur est attendue après l'option '-" + flag + "'."
					}
				if flag == "t":
					ending = options[i].value
				else:
					separator = options[i].value
			else:
				return {
					"error": "l'option '" + options[i].value + "' est inconnue."
				}
		else:
			return {
				"error": "l'argument '" + str(options[i].value) + "' était inattendu."
			}
		i += 1
	if numbers.size() == 3:
		start = numbers[0]
		step = numbers[1]
		end = numbers[2]
		if start > end and step > 0:
			return {
				"error": "la valeur du saut doit être négative."
			}
	elif numbers.size() == 2:
		start = numbers[0]
		end = numbers[1]
	elif numbers.size() == 1:
		start = 1
		end = numbers[0]
	else:
		return {
			"error": "un nombre indiquant la fin de la séquence est attendu."
		}
	step = 1 if start < end else -1
	var output := ""
	for c in range(start, end + (1 if step > 0 else -1), step): # we want to include "end"
		output += str(c) + separator
	output += ending
	return {
		"output": output,
		"error": null
	}

func ping(options: Array, _standard_input: String) -> Dictionary:
	if self.ip_address.empty():
		return {
			"error": "une adresse IP n'a pas été configurée."
		}
	if dns.config.empty():
		return {
			"error": "la configuration DNS est vide."
		}
	if options.size() != 1:
		return {
			"error": "argument inattendu."
		}
	var property = null
	if DNS.is_valid_domain(options[0].value): property = "name"
	if DNS.is_valid_mac_address(options[0].value): property = "mac"
	if DNS.is_valid_ipv4(options[0].value): property = "ipv4"
	if DNS.is_valid_ipv6(options[0].value): property = "ipv6"
	if property == null:
		return {
			"error": "cible invalide"
		}
	var entry = dns.get_entry(options[0].value, property)
	if entry == null:
		return {
			"error": "la destination n'existe pas, ou n'a pas été trouvée"
		}
	var destination_ip = entry.ipv6 if property == "ipv6" else entry.ipv4
	var output = "PING " + entry.name + " (" + destination_ip + "): 56 octets de données\n"
	var rng := RandomNumberGenerator.new()
	var times := []
	for i in range(0, 5):
		rng.randomize()
		var time = rng.randf_range(20.0, 30.0)
		times.append(time)
		output += "64 octets depuis " + destination_ip + ": icmp_seq=0 ttl=55 temps=" + ("%.3f" % time) + " ms\n"
	output += "--- " + entry.name + " statistiques du ping ---\n"
	output += "5 paquets transmis, 5 paquets reçus, 0.0% de perte\n"
	output += "round-trip min/avg/max/stddev = " + ("%.3f" % times.min()) + "/" + ("%.3f" % _avg(times)) + "/" + ("%.3f" % times.max()) + "/0.000 ms"
	return {
		"output": output,
		"error": null
	}

func _avg(array: Array) -> float:
	var s := 0.0
	for value in array:
		s += value
	return s / array.size()

func _handle_head_or_tail_command(command_name: String, options: Array, standard_input) -> Dictionary:
	var text = null
	var n := 10
	var i := 0
	var tail_shift = null
	var option: BashToken
	while i < options.size():
		option = options[i]
		if option.is_flag():
			if tail_shift != null:
				return {
					"error": "chemin '" + option.value + "' invalide."
				}
			if options[i].value == "n":
				i += 1
				if i >= options.size() or not options[i].is_plain():
					return {
						"error": "l'option -n attend une valeur."
					}
				if not options[i].value.is_valid_integer():
					return {
						"error": "la valeur de l'option -n n'est pas valide."
					}
				n = int(options[i].value)
				if n <= 0:
					return {
						"error": "la valeur de -n doit être strictement positive."
					}
			else:
				return {
					"error": "l'option '-" + option.value + "' est inconnue."
				}
		elif option.is_word():
			if option.value.begins_with("+"):
				if command_name == "head":
					return {
						"error": "chemin '" + option.value + "' invalide."
					}
				var value = option.value.right(1)
				if value.is_valid_integer():
					tail_shift = int(value)
					if tail_shift < 0:
						return {
							"error": "valeur invalide pour indice de début : '" + option.value + "'."
						}
				else:
					return {
						"error": "valeur de début invalide."
					}
			else:
				var path := PathObject.new(option.value)
				if not path.is_valid:
					return {
						"error": "le chemin n'est pas valide."
					}
				var element = get_file_element_at(path)
				if element == null:
					return {
						"error": _display_error_or("le fichier n'existe pas.")
					}
				if not element.can_read():
					return {
						"error": "permission refusée."
					}
				if not element.is_file():
					return {
						"error": "la cible n'est pas un fichier."
					}
				text = element.content
		else:
			return {
				"error": "syntaxe invalide."
			}
		i += 1
	if text == null:
		text = standard_input
	return {
		"n": n,
		"text": text,
		"tail_shift": tail_shift,
		"error": null
	}

func head(options: Array, standard_input: String) -> Dictionary:
	var check := _handle_head_or_tail_command("head", options, standard_input)
	if check.error != null:
		return {
			"error": check.error
		}
	var output := ""
	var lines = check.text.split("\n")
	for e in range(0, min(check.n, lines.size())):
		output += lines[e] + "\n"
	return {
		"output": output,
		"error": null
	}

func tail(options: Array, standard_input: String) -> Dictionary:
	var check := _handle_head_or_tail_command("tail", options, standard_input)
	if check.error != null:
		return {
			"error": check.error
		}
	var output := ""
	var lines = check.text.split("\n")
	var begin = max(lines.size() - check.n, 0) if check.tail_shift == null else max(check.tail_shift - 1, 0)
	for e in range(begin, lines.size()):
		output += lines[e] + "\n"
	return {
		"output": output,
		"error": null
	}

func startm99(options: Array, _standard_input: String) -> Dictionary:
	if options.size() != 0:
		return {
			"error": "aucune option n'est attendue."
		}
	if interface_reference == null:
		return {
			"error": "une interface doit être définie."
		}
	if m99.PROGRAM == null:
		m99.init_blank_M99()
	m99.started = true
	return {
		"output": m99.buildm99(),
		"error": null
	}
