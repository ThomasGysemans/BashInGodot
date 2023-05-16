#warning-ignore-all:return_value_discarded
extends Object
class_name Terminal

const HELP_TEXT := "Ce terminal vous permet d'écrire des commandes Bash simplifiées.\n" \
	+ "Le but est pédagogique. Vous pouvez apprendre des commandes et vous entrainer.\n" \
	+ "Les commandes ont été reproduites le plus fidèlement possible, mais quelques différences peuvent apparaître.\n\n" \
	+ "Rappels sur comment écrire une commande :\n" \
	+ "Une commande vous permet de manipuler les fichiers et dossiers de votre environnement de travail.\n" \
	+ "En règle générale, la syntaxe pour une commande ressemble à ça : [b]nom_de_la_commande[/b] [...[b]options[/b]] [...[b]arguments[/b]].\n\n" \
	+ "Utilisez des redirections pour modifier le comportement d'une commande. Une redirection est un numéro : \n" \
	+ "- 0 : entrée standard\n" \
	+ "- 1 : sortie standard\n" \
	+ "- 2 : sortie d'erreur\n" \
	+ "Exemple : head file.txt 1>resultat.txt (réécris, ou crée, le fichier \"resultat.txt\" avec le résultat écrit de la commande).\n" \
	+ "Utilisez les symboles :\n" \
	+ "- > : réécrit le fichier\n" \
	+ "- < : lit le fichier\n" \
	+ "- >> : ajoute au fichier\n\n" \
	+ "Enchainez des commandes sur la même ligne en les séparant par un \"|\" (\"pipe\" en anglais).\n" \
	+ "L'entrée standard de la commande suivante sera le résultat écrit de la commande précédente.\n" \
	+ "Exemple : echo yoyo | cat"

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
signal error_thrown (command, reason) # emitted when the `command` threw an error, which text is the `reason`
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
signal script_executed (script, output) # emitted when a script was executed. `script` is the instance of SystemElement of the script, `output` is the output printed to the interface. It does not contain what's been redirected.
signal help_asked # emitted when the custom `help` command is used.
signal interface_cleared

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
		"allowed": true, # if false, an error "the command does not exist" will be thrown instead
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
		"allowed": true,
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
		"allowed": true,
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
		"allowed": true,
		"reference": funcref(self, "tr_"),
		"manual": {
			"name": "tr - remplace, ou supprime, un pattern précis depuis l'entrée standard pour l'afficher dans la sortie standard.",
			"synopsis": [
				"[b]tr[/b] [u]pattern[/u] [u]remplacement[/u]",
				"[b]tr[/b] [b]-d[/b] [u]pattern[/u]"
			],
			"description": "Remplace le pattern par la chaine de remplacement donnée. Si l'option -d est précisée, toutes les occurrences du pattern seront supprimées. Le résultat est affiché dans la sortie standard.",
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
		"allowed": true,
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
		"allowed": true,
		"reference": funcref(self, "ls"),
		"manual": {
			"name": "ls - liste le contenu d'un dossier.",
			"synopsis": ["[b]ls[/b] [[b]-a[/b]] [[b]-l[/b]] [[u]dossier[/u]]"],
			"description": "La commande va lister le contenu des dossiers, en colorant en vert les dossiers, et en blanc les fichiers. Par défaut, les fichiers et dossiers cachés (c'est-à-dire ceux préfixés par un point) ne seront pas affichés. Pour les afficher, utilisez l'option -a.",
			"options": [
				{
					"name": "-a",
					"description": "Affiche les fichiers cachés (ceux préfixés d'un point)"
				},
				{
					"name": "-l",
					"description": "Affiche les fichiers et dossiers contenus dans la cible avec des données supplémentaires."
				}
			],
			"examples": [
				"ls folder",
				"ls -a folder",
				"ls -l ."
			]
		}
	},
	"clear": {
		"allowed": true,
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
		"allowed": true,
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
		"allowed": true,
		"reference": funcref(self, "cd"),
		"manual": {
			"name": "cd - définit le chemin courant comme étant la cible.",
			"synopsis": ["[b]cd[/b] [[u]chemin[/u]]"],
			"description": "Définit la variable $PWD comme étant le chemin absolu de la destination ciblée par le chemin donné. Ne pas donner de chemin revient à écrire la racine, \"/\".",
			"options": [],
			"examples": [
				"cd folder",
				"cd"
			]
		}
	},
	"touch": {
		"allowed": true,
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
		"allowed": true,
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
		"allowed": true,
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
		"allowed": true,
		"reference": funcref(self, "cp"),
		"manual": {
			"name": "cp - copie un élément vers une autre destination.",
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
		"allowed": true,
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
		"allowed": true,
		"reference": funcref(self, "help"),
		"manual": {
			"name": "help - commande si vous avez besoin d'aide quant à Bash.",
			"synopsis": ["[b]help[/b]"],
			"description": "Utilisez cette commande si vous avez besoin de rappels quant au fonctionnement primaire de Bash. La commande vous propose également une liste de toutes les commandes disponibles, avec une rapide description de chacune.",
			"options": [],
			"examples": []
		}
	},
	"tree": {
		"allowed": true,
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
		"allowed": true,
		"reference": funcref(self, "chmod"),
		"manual": {
			"name": "chmod - définit les permissions accordées à un élément.",
			"synopsis": ["[b]chmod[/b] [u]mode[/u] [u]fichier[/u]"],
			"description": "Il y a trois catégories (utilisateur, groupe, autres) qui ont chacune trois types d'autorisations : lecture (r), écriture (w), exécution/franchissement (x). Les permissions s'écrivent \"-rwx--xr--\" où le premier caractère est soit \"d\" pour un dossier, ou \"-\" pour un fichier et où l'utilisateur a les droits combinés \"rwx\" (lecture, écriture et exécution) et où le groupe a les droits d'exécution seulement et les autres le droit de lecture uniquement. En règle générale, les permissions sont données sous la forme de trois chiffres en octal dont la somme est une combinaison unique : 4 pour la lecture, 2 pour l'écriture et 1 pour l'exécution. Par défaut un fichier, à sa création, a les droits 644. Accordez ou retirez un droit spécifique avec \"chmod u+x file.txt\" (raccourcie en \"chmod +x file.txt\" quand il s'agit de l'utilisateur, ([b]u[/b] pour utilisateur, [b]g[/b] pour groupe, [b]o[/b] pour autres)), ou détaillez la règle en octal à appliquer sur les trois catégories (\"chmod 657 file.txt\").",
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
		"allowed": true,
		"reference": funcref(self, "nano"),
		"manual": {
			"name": "nano - ouvre un éditeur pour éditer un fichier dans le terminal.",
			"synopsis": ["[b]nano[/b] [u]fichier[/u]"],
			"description": "Nano est l'éditeur par défaut de Bash. Utilisez cette commande pour éditer un fichier déjà existant. Si le fichier cible n'existe pas, il sera créé. La version de Nano proposée ici est modifiée pour convenir à une utilisation à la souris.",
			"options": [],
			"examples": [
				"nano file.txt"
			]
		}
	},
	"seq": {
		"allowed": true,
		"reference": funcref(self, "seq"),
		"manual": {
			"name": "seq - affiche une séquence de nombres.",
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
		"allowed": true,
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
		"allowed": true,
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
		"allowed": true,
		"reference": funcref(self, "tail"),
		"manual": {
			"name": "tail - affiche les dernières lignes d'un fichier.",
			"synopsis": ["[b]tail[/b] [[b]-n[/b] [u]nombre[/u]] [[u]fichier[/u]]"],
			"description": "Par défaut, les 10 dernières lignes du fichier sont affichées. Précisez le nombre de lignes désirées avec l'option -n. Vous pouvez partir du début du fichier en donnant plutôt un nombre qui commence par '+'. Ainsi, pour afficher un contenu sans la première ligne, ce serait 'tail +2'.",
			"options": [
				{
					"name": "n",
					"description": "Précise le nombre de lignes voulues."
				}
			],
			"examples": [
				"tail file.txt",
				"tail -n 1 file.txt",
				"cat file.txt | tail",
				"cat file.csv | tail +2"
			]
		}
	},
	"cut": {
		"allowed": true,
		"reference": funcref(self, "cut"),
		"manual": {
			"name": "cut - sélectionne une portion précise de chaque ligne d'un fichier.",
			"synopsis": [
				"[b]cut[/b] [b]-c[/b] [u]liste[/u] [[u]fichier[/u]]",
				"[b]cut[/b] [b]-f[/b] [u]liste[/u] [b]-d[/b] [u]délimiteur[/u] [[u]fichier[/u]]"
			],
			"description": "La commande va couper chaque ligne de manière à afficher une portion précise. Sélectionnez un groupe de caractères avec l'option '-c', ou des champs particuliers via le délimiteur donné par l'option '-d' (qui est par défaut TAB : '\\t'). Spécifiez quels champs sélectionner avec '-f'. Sélectionnez une liste de champs (les champs 2 et 5 par exemple) en écrivant une virgule : '2,5'. Sélectionnez un intervalle de x à y en écrivant : x-y.",
			"options": [
				{
					"name": "c",
					"description": "Sélectionne des caractères."
				},
				{
					"name": "f",
					"description": "Sélectionne un champ par un délimiteur particulier donné par l'option '-d'."
				},
				{
					"name": "d",
					"description": "Définit un délimiteur particulier avec lequel désigner des champs à sélectionner."
				}
			],
			"examples": [
				"cat fichier.csv | cut -c 5 # sélectionne le 5e caractère",
				"cat fichier.csv | cut -c 5,10 # sélectionne le 5e et le 10e caractère",
				"cat fichier.csv | cut -c 5-10 # sélectionne les caractères de la position 5 à 10",
				"cat fichier.csv | cut -f 2 -d ',' # sélectionne le 2e champ séparé par une virgule",
				"cat fichier.csv | cut -f 2,3,5-8 -d ',' # sélectionne le 2e et 3e champs, puis du 5e au 8e."
			]
		}
	},
	"startm99": {
		"allowed": true,
		"reference": funcref(self, "startm99"),
		"manual": {
			"name": "startm99 - commande custom pour démarrer un simulateur de langage tel que Assembler appelé M99.",
			"synopsis": ["[b]startm99[/b]"],
			"description": "Démarre un simulateur pédagogique pour apprendre les bases de l'Assembler.",
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

static func remove_bbcode(text: String) -> String:
	return replace_bbcode(text, "")

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
		output += "\t" + synopsis + "\n"
	output += "\n[b]DESCRIPTION[/b]\n"
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
		if "allowed" in commands[command] and not commands[command].allowed:
			continue
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
		(nano_editor as WindowDialog).get_close_button().disconnect("pressed", self, "_on_nano_saved")
	(editor as WindowDialog).get_node("Button").connect("pressed", self, "_on_nano_saved")
	editor.get_close_button().connect("pressed", self, "_on_nano_saved")
	nano_editor = editor

func set_dns(d: DNS) -> void:
	dns = d

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

# Sets all commands to "allowed: false",
# except those given in `commands`.
func set_allowed_commands(commands: Array) -> void:
	for c in COMMANDS:
		if c == "help":
			continue
		COMMANDS[c].allowed = false
	var keys := COMMANDS.keys()
	for c in commands:
		if c in keys:
			COMMANDS[c].allowed = true

# Set "allowed: false" for all commands given in `commands`.
func forbid_commands(commands: Array) -> void:
	var keys := COMMANDS.keys()
	for c in commands:
		if c in keys:
			COMMANDS[c].allowed = false

func _write_to_redirection(redirection: Dictionary, output: String) -> void:
	if redirection.type == Tokens.WRITING_REDIRECTION:
		redirection.target.content = output
	elif redirection.type == Tokens.APPEND_WRITING_REDIRECTION:
		redirection.target.content += output

# Give as input the parsing result of a command.
# Let's take for example `cat $(echo file.txt)`
# This will read the substitution tokens
# and replace them with a PLAIN token
# with value the standard output of the sub-command.
# If the standard output of the sub-command is empty, it will be ignored.
# If the `clear` command is executed inside the sub-command, it is ignored.
# This function will return a dictionary.
# {"error": String or null, "tokens": Array or undefined }
func interpret_substitutions(options: Array) -> Dictionary:
	var tokens := []
	for option in options:
		if option.is_command_substitution():
			var interpretation = interpret_one_substitution(option)
			if interpretation.error != null:
				return interpretation
			else:
				if interpretation.tokens != null:
					tokens.append_array(interpretation.tokens)
		else:
			tokens.append(option)
	return {
		"error": null,
		"tokens": tokens
	}

# Interprets a single substitution.
# Usually, we'll only want to use `interpret_substitutions`.
# However, it's useful for the substitutions that may be in the redirections.
# Returns a dictionary { "error": String or null, "tokens": array of PLAIN BashTokens, or just null if there is not output } 
func interpret_one_substitution(token: BashToken) -> Dictionary:
	var execution := execute(token.value, null, false)
	# Because the execution possibly have multiple independant commands
	# we have to make only one token out of everything.
	var one_line_output := ""
	for output in execution.outputs:
		if output.error != null:
			one_line_output += output.error
		else:
			one_line_output += output.text.strip_edges() + " "
	one_line_output = one_line_output.strip_edges()
	var splitted_token := _split_variable_value(one_line_output)
	if not one_line_output.empty():
		return {
			"error": null,
			"tokens": splitted_token
		}
	return {
		"error": null,
		"tokens": null
	}

# Executes the input of the user.
# The command substitutions will be recursively executed using `interpret_substitutions` on the input.
# If the commands fails, then this function will return { "error": String }.
# Otherwise, it will return { "error": null, "output": String, "interface_cleard": bool } 
func execute(input: String, interface: RichTextLabel = null, can_change_interface := true) -> Dictionary:
	var lexer := BashLexer.new(input)
	if not lexer.error.empty():
		return {
			"outputs": [{
				"error": lexer.error
			}]
		}
	return _execute_tokens(lexer.tokens_list, interface, can_change_interface)

func _execute_tokens(tokens: Array, interface: RichTextLabel = null, can_change_interface := true) -> Dictionary:
	var parser := BashParser.new(runtime[0], pid)
	var parsing := parser.parse(tokens)
	if not parser.error.empty():
		return {
			"outputs": [{
				"error": parser.error
			}]
		}
	if m99.started and parsing.size() > 1:
		return {
			"outputs": [{
				"error": "Impossible d'enchainer plusieurs commandes à la suite de la sorte dans le M99."
			}]
		}
	var outputs := [] # the array that will contain all outputs which are dictionaries : {"error": String or null, "text": String, "interface_cleared": bool }
	var standard_input := "" # the last standard output
	var cleared := false
	for node in parsing:
		for z in range(0, node.size()):
			var command = node[z]
			if command.type == "command":
				if m99.started:
					if not command.redirections.empty():
						return {
							"outputs": [{
								"error": "M99 n'accepte aucune redirection."
							}]
						}
					return execute_m99_command(command.name, command.options)
				
				# The interpretation of the variables must be done here.
				# It could have been done during the parsing process but the for loops would not work properly.
				command.options = interpret_variables(command.options)
				for i in range(0, command.redirections.size()):
					var interpretation := interpret_variables([command.redirections[i].target])
					if interpretation.size() > 1:
						return {
							"outputs": [{
								"error": "Symbole inattendu après redirection du port " + str(command.redirections[i].port) + "." 
							}]
						}
					else:
						command.redirections[i].target = interpretation[0]
				
				var function = COMMANDS[command.name] if command.name in COMMANDS else null
				if function == null and command.name.find('/') != -1:
					var path_to_executable := PathObject.new(command.name)
					if path_to_executable.is_valid:
						# for now, an error in the file will stop the entire input
						# even if there are other commands waiting, separated by semicolons
						var executable = get_file_element_at(path_to_executable)
						if executable == null:
							outputs.append({
								"error": _display_error_or("Le fichier n'existe pas")
							})
							break
						if not executable.is_file():
							outputs.append({
								"error": "L'élément n'est pas un fichier !"
							})
							break
						if not executable.can_execute_or_go_through():
							outputs.append({
								"error": "Permission refusée"
							})
							break
						var file_execution = execute_file(executable, command.options, interpret_redirections(command.redirections), interface)
						for o in file_execution.outputs:
							outputs.append(o)
						continue
				# if the function doesn't exist,
				# function.reference.is_valid() will be false.
				if function == null or not function.reference.is_valid() or not function.allowed:
					outputs.append({
						"error": "La commande '" + command.name + "' n'existe pas."
					})
					break
				else:
					var substitutions_interpretation = interpret_substitutions(command.options)
					if substitutions_interpretation.error != null:
						outputs.append(substitutions_interpretation)
						break
					else:
						command.options = substitutions_interpretation.tokens
					var command_redirections = interpret_redirections(command.redirections)
					if error_handler.has_error:
						outputs.append({
							"error": "Commande '" + command.name + "' : " + error_handler.clear()
						})
						break
					command.redirections = command_redirections
					for i in range(0, command_redirections.size()):
						if command_redirections[i] != null and command_redirections[i].target == null:
							outputs.append({
								"error": "Impossible de localiser, ni de créer, la destination du descripteur " + str(i) + "."
							})
							break
					var result = function.reference.call_func(command.options, command_redirections[0].target.content if command_redirections[0] != null and command_redirections[0].type == Tokens.READING_REDIRECTION else remove_bbcode(standard_input))
					if command_redirections[2] != null:
						if result.error == null:
							if command_redirections[2].type == Tokens.WRITING_REDIRECTION:
								command_redirections[2].target.content = ""
						else:
							if command_redirections[2].type == Tokens.WRITING_REDIRECTION:
								command_redirections[2].target.content = "Commande '" + command.name + "' : " + result.error
							elif command_redirections[2].type == Tokens.APPEND_WRITING_REDIRECTION:
								command_redirections[2].target.content += "Commande '" + command.name + "' : " + result.error
							emit_signal("error_thrown", command, result.error)
							standard_input = ""
							break # if there is an error, we have to stop the command anyway
					if result.error != null:
						emit_signal("error_thrown", command, result.error)
						outputs.append({
							"error": "Commande '" + command.name + "' : " + result.error
						})
						standard_input = ""
						break
					else:
						var output_without_bbcode = remove_bbcode(result.output)
						emit_signal("command_executed", command, output_without_bbcode)
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
							_write_to_redirection(command_redirections[1], output_without_bbcode)
							standard_input = ""
						else:
							standard_input = result.output
						if command.name == "clear":
							cleared = true
							if interface != null:
								emit_signal("interface_cleared")
			elif command.type == "for":
				outputs.append_array(_execute_for_loop(command).outputs)
			else: # the line is a variable affectation
				var variable_value = command.value # command.value is a BashToken
				if variable_value.type == Tokens.SUBSTITUTION:
					var interpretation = interpret_one_substitution(variable_value)
					if interpretation.error != null:
						outputs.append(interpretation)
					var string_value := ""
					for token in interpretation.tokens:
						string_value += token.value.strip_edges() + " "
					variable_value = BashToken.new(Tokens.PLAIN, string_value)
				elif variable_value.type == Tokens.VARIABLE:
					var interpretation := interpret_variables([variable_value])
					var string_value := ""
					for token in interpretation:
						string_value += token.value.strip_edges() + " "
					variable_value = BashToken.new(Tokens.PLAIN, string_value)
				var is_new = runtime[0].set_variable(command.name, variable_value)
				emit_signal("variable_set", command.name, variable_value.value, is_new)
			# If it's not the last command (if it's the second one in "command1 | command2 | command3" for example),
			# then we don't want to keep the bbcode in the standard input of the next command.
			if (z + 1) < node.size():
				standard_input = remove_bbcode(standard_input)
		if cleared or not standard_input.empty():
			if can_change_interface:
				emit_signal("interface_changed", standard_input)
			outputs.append({
				"error": null,
				"text": standard_input,
				"interface_cleared": cleared
			})
		cleared = false
		standard_input = ""
	return {
		"outputs": outputs,
	}

# Interprets a token of type VAR.
# Those tokens are variables.
# Sometimes in the parsing process,
# we'll want to interpret them right away
# in order to use their value directly.
# However, in some cases we don't want them to be interpreted.
# This is the case for the for-loop.
# Also, because some variables might be interpreted as multiple tokens,
# we have to return an array, even though most of the time it will contain only one element.
func interpret_variables(tokens: Array) -> Array:
	var list := []
	var token: BashToken
	for i in range(0, tokens.size()):
		token = tokens[i]
		if token.is_variable():
			# If multiple variables are chained like this: "$$$yoyo"
			# then we want a single token representing the concatenation of their value.
			# To do that, if we detect that the previous token that we interpreted was also a variable,
			# then we add to the value of the previous interpreted token the interpreted value of the current token.
			var value: String = str(pid) if token.value == "$" else runtime[0].get_variable_value(token.value)
			if i > 0 and tokens[i-1].is_variable():
				list[i-1].value += value
			else:
				# If the value has multiple words separated by white space, then it must be interpreted as multiple PLAIN tokens.
				# You can observe this behaviour by creating a variable with multiple words, like this: HELLO="HEL LO"
				# Create a script that loops over $@ and does an echo of each value.
				# You'll observe multiple lines getting printed, even if you just typed ./script $HELLO
				# It does not happen if the variable is in a string.
				# It's called "word-splitting"
				var tokens_from_value := _split_variable_value(value)
				for t in tokens_from_value:
					list.append(t)
		elif token.is_string():
			if token.metadata.quote == "'":
				list.append(token)
			else:
				list.append(_interpret_string(token))
		elif token.is_plain() and token.value == "$$":
			list.append(BashToken.new(Tokens.PLAIN, str(pid)))
		else:
			list.append(token)
	return list

# This method interprets the value of a variable in order to make several PLAIN tokens out of it.
# Indeed, if the value holds multiple words, then each of them are different tokens.
# See the comments in `interpret_variables()` above.
# The tokens are returned in an array.
# We consider that no errors can happen during this process.
func _split_variable_value(value: String) -> Array:
	var r = RegEx.new()
	r.compile("\\S+") # any non-whitespace character (so none of these: " ", "\n", "\t")
	var words: Array = []
	for m in r.search_all(value):
		words.append(m.get_string())
	var tokens: Array = []
	for word in words:
		tokens.append(BashToken.new(Tokens.PLAIN, word))
	return tokens

# Replaces the variables with their value.
# Call this method only if the string was created using double quotes.
func _interpret_string(token: BashToken) -> BashToken:
	var identifier := ""
	var identifier_pos := 0
	var i := 0
	var new_token := BashToken.new(Tokens.STRING, "", { "quote": '"' })
	var value_to_add := ""
	while i < token.value.length():
		if token.value[i] == "$":
			identifier_pos = i
			i += 1
			if i >= token.value.length():
				new_token.value += "$"
				break
			if token.value[i] == "$":
				identifier = "$$"
				i += 1
			elif token.value[i] == " ":
				new_token.value += "$"
				continue
			else:
				while i < token.value.length() and token.value[i] != " ":
					if not (identifier + token.value[i]).is_valid_identifier():
						break
					identifier += token.value[i]
					i += 1
			if identifier == "$$":
				value_to_add = str(pid)
			else:
				value_to_add = runtime[0].get_variable_value(identifier)
			new_token.value += value_to_add
			identifier = ""
		else:
			new_token.value += token.value[i]
			i += 1
	return new_token

# todo: allow comments

# Executes a script.
# We assume that the given file is executable.
# Also, for now, the options are not interpreted as variables $1 etc.
# Here, because of the for loops, some nodes might be on multipe lines.
# We can't just get every line of the file and execute them one by one.
# We parse the whole file at once and go through each node.
# After the parsing, we execute everything and exit as soon as there is an error.
func execute_file(file: SystemElement, options: Array, redirections: Array, interface: RichTextLabel = null) -> Dictionary:
	var result = execute(file.content, interface)
	var cleared := false
	var outputs := [] # we store all the outputs of the commands here
	# ./script
	# == prints everything on the screen
	# ./script 1>result.txt
	# == sends all the successfull outputs in result.txt, but prints all the errors on the screen
	# ./script 1>result.txt 2>errors.txt
	# == sends all the successfull outputs in result.txt, and all the errors in error.txt
	for o in result.outputs:
		if o.error == null and o.interface_cleared:
			cleared = true
			outputs = []
		else:
			outputs.append(o)
	if redirections[2] != null:
		var all_errors := ""
		var indexes_to_remove := [] # we'll remove all errors from the outputs array
		for i in range(0, outputs.size()):
			if outputs[i].error != null:
				all_errors += outputs[i].error + "\n"
				indexes_to_remove.append(i)
		for i in range(indexes_to_remove.size() - 1, -1, -1):
			outputs.remove(indexes_to_remove[i])
		all_errors = all_errors.strip_edges()
		if redirections[2].type == Tokens.WRITING_REDIRECTION:
			redirections[2].target.content = all_errors
		elif redirections[2].type == Tokens.APPEND_WRITING_REDIRECTION:
			redirections[2].target.content += all_errors
	if redirections[0] != null:
		_write_to_redirection(redirections[0], "") # the weird behaviour described above, in `execute()`
	if redirections[1] != null:
		# If a standard output is used in the command,
		# then it will receive the content of the combined outputs
		# without the errors
		var output := ""
		var indexes_to_remove := []
		for i in range(0, outputs.size()):
			if outputs[i].error == null:
				output += outputs[i].text
				indexes_to_remove.append(i)
		for i in range(indexes_to_remove.size() - 1, -1, -1):
			outputs.remove(indexes_to_remove[i])
		_write_to_redirection(redirections[1], output)
	emit_signal("script_executed", file, outputs)
	return {
		"outputs": outputs
	}

# Executes a for-loop node.
# As a reminder, it looks something like this:
# {
#   "type": "for",
#   "variable_name": String,
#   "sequences": array of interpreted tokens (the variables got their value)
#   "body": array of uninterpreted tokens
# }
func _execute_for_loop(command: Dictionary) -> Dictionary:
	var outputs := []
	var sequences := interpret_substitutions(interpret_variables(command.sequences))
	if sequences.error != null:
		return {
			"outputs": [sequences]
		}
	for sequence in sequences.tokens:
		runtime[0].set_variable(command.variable_name, sequence)
		outputs.append_array(_execute_tokens(command.body, null, false).outputs)
	var oneline_output = ""
	var has_error := false
	for output in outputs:
		if output.error != null:
			has_error = true
			break
		else:
			oneline_output += output.text
	if not has_error:
		emit_signal("interface_changed", oneline_output)
	return {
		"outputs": outputs
	}

# Custom commands when using M99.
# Exemple is : set 90 401
# meaning set cell at pos 90 with value 401
func execute_m99_command(command_name: String, options: Array) -> Dictionary:
	if command_name == "man":
		var manual = man(options, "")
		if manual.error != null:
			return {
				"outputs": [manual]
			}
		else:
			return {
				"outputs": [{
					"error": null,
					"interface_cleared": true,
					"text": "Le manuel a été ouvert.\nTapez la commande \"show\" pour en sortir.\n\n" + manual.output
				}]
			}
	elif command_name == "help":
		return {
			"outputs": [{
				"error": null,
				"interface_cleared": true,
				"text": build_help_page(m99.help_text, m99.COMMANDS),
			}]
		}
	var function = m99.COMMANDS[command_name] if command_name in m99.COMMANDS else null
	if function == null or not function.reference.is_valid():
		return {
			"outputs": [{
				"error": "Cette commande n'existe pas."
			}]
		}
	else:
		var result = function.reference.call_func(options)
		var cleared := false
		var output := ""
		if result.error != null:
			return {
				"outputs": [result]
			}
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
			"outputs": [{
				"error": null,
				"interface_cleared": cleared,
				"text": output,
			}]
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
	return get_file_element_at(PathObject.new(path.base_dir) if path.base_dir != null else PWD)

func copy_element(e: SystemElement) -> SystemElement:
	return SystemElement.new(e.type, e.filename, e.base_dir, e.content, copy_children_of(e), user_name, group_name, e.permissions)

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
		# It might be command substitutions.
		# They could be everywhere and needs to be interpreted.
		# It is possible to have a substitution even with a copied redirection.
		# Example: 2>&$(echo 1)
		var target: BashToken = redirections[i].target
		if target.is_command_substitution():
			var interpretation = interpret_one_substitution(target)
			if interpretation.error != null:
				error_handler.throw_error(interpretation.error)
			else:
				if interpretation.tokens == null:
					error_handler.throw_error("La redirection est ambiguë.")
				else:
					if interpretation.tokens.size() > 1:
						error_handler.throw_error("Trop de symboles donnés à la redirection.")
					else:
						target = interpretation.tokens[0]
		if redirections[i].copied:
			# If we have recursive substitution commands,
			# we might have a situation where the descriptor is a PLAIN token.
			var index: int
			if target.is_descriptor():
				index = target.value
			elif target.is_plain() and target.value.is_valid_integer() and target.value in ["0", "1", "2"]:
				index = int(target.value)
			else:
				error_handler.throw_error("Descripteur invalide pour une des redirections. Il faut que ce soit un nombre : 0, 1 ou 2.")
			if index > 2:
				error_handler.throw_error("Le descripteur '" + str(index) + "' est trop grand.")
			else:
				result[redirections[i].port] = result[index]
				target = result[index].target
		else:
			result[redirections[i].port] = redirections[i]
		result[redirections[i].port].target = target
	if result[0] != null:
		var target: SystemElement = get_file_element_at(PathObject.new(result[0].target.value))
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
			var path := PathObject.new(result[i].target.value)
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
	var command_name = options[0].value
	if command_name == "man":
		page = build_manual_page_using(self.COMMANDS["man"].manual, max_paragraph_width)
	else:
		if (not command_name in commands_list) or (not m99.started and not commands_list[command_name].allowed):
			return {
				"error": "'" + command_name + "' est une commande inconnue"
			}
		page = build_manual_page_using(commands_list[command_name].manual, max_paragraph_width)
	emit_signal("manual_asked", command_name, page)
	return {
		"output": page,
		"error": null
	}

func help(options: Array, _standard_input: String) -> Dictionary:
	if options.size() > 0:
		return {
			"error": "aucun argument n'est attendu"
		}
	emit_signal("help_asked")
	return {
		"output": build_help_page(HELP_TEXT, COMMANDS),
		"error": null
	}

func echo(options: Array, _standard_input: String) -> Dictionary:
	var to_display := ""
	var line_break := true
	for option in options:
		if option.is_eoi():
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
		return { "error": "trop d'arguments." }
	if options.size() == 0:
		# something weird about the "cat" command...
		# if no file is given as argument,
		# but something is given in the standard input,
		# then the standard input becomes the output
		return {
			"output": standard_input,
			"error": null
		}
	if not options[0].is_word():
		return {
			"error": "un chemin est attendu."
		}
	var path = PathObject.new(options[0].value)
	if not path.is_valid:
		return {
			"error": "le chemin n'est pas valide."
		}
	var element = get_file_element_at(path)
	if element == null:
		return {
			"error": _display_error_or("la destination n'existe pas.")
		}
	if not element.is_file():
		return {
			"error": "la destination doit être un fichier !"
		}
	if not element.can_read():
		return {
			"error": "Permission refusée."
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
	(nano_editor as WindowDialog).get_node("TextEdit").text = edited_file.content
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

# Takes as input "2-4" and returns [2, 5].
# If the end is not specified, then it returns [beginning, null].
# The beginning cannot be null.
func _read_interval(option: String) -> Dictionary:
	var dash: int = option.find('-')
	var begin: String = option.left(dash) # cannot be empty
	var end: String = option.right(dash + 1)
	var begin_integer: int
	var ending_integer: int
	if end.empty():
		if not begin.is_valid_integer():
			return {
				"error": "l'intervalle '" + option + "' n'est pas valide."
			}
		begin_integer = int(begin) - 1
		if begin_integer < 0:
			return {
				"error": "un intervalle ne peut inclure 0."
			}
	else:
		if not begin.is_valid_integer() or not end.is_valid_integer():
			return {
				"error": "l'intervalle '" + option + "' n'est pas valide."
			}
		begin_integer = int(begin) - 1
		ending_integer = int(end) - 1
		if begin_integer < 0 or ending_integer < 0:
			return {
				"error": "un intervalle ne peut inclure 0."
			}
	return {
		"error": null,
		"interval": [begin_integer, null if end.empty() else ending_integer]
	}

func _get_duplicates(a: Array) -> Array:
	if a.size() < 2:
		return []
	var seen = {}
	seen[a[0]] = true
	var duplicate_indexes = []
	for i in range(1, a.size()):
		var v = a[i]
		if seen.has(v):
			# Duplicate!
			duplicate_indexes.append(i)
		else:
			seen[v] = true
	return duplicate_indexes

# Reads the input "2,3,5-10"
# which means "select element 2 and 3, then from 5 to 10".
# This function returns a dictionary:
# {
#   "list": [1, 2, 4, 5, 6, 7, 8, 9],
#   "error": String or null
# }
# The duplicates are removed, and the array is sorted.
func _read_cut_range(option: String, max_value: int) -> Dictionary:
	var elements := option.split(',')
	var list := []
	var integer: int
	for element in elements:
		if element.find('-') != -1:
			var check := _read_interval(element)
			if check.error != null:
				return check
			for j in range(check.interval[0], max_value if check.interval[1] == null else (check.interval[1] + 1)):
				list.append(j)
		else:
			if not element.is_valid_integer():
				return {
					"error": "liste invalide."
				}
			integer = int(element) - 1
			if integer < 0:
				return {
					"error": "une liste ne peut inclure 0."
				}
			list.append(integer)
	var duplicate_indexes := _get_duplicates(list)
	for i in range(duplicate_indexes.size() - 1, -1, -1):
		list.remove(duplicate_indexes[i])
	list.sort()
	return {
		"list": list,
		"error": null
	}

func cut(options: Array, standard_input: String) -> Dictionary:
	var output := ""
	var selection = null
	var is_c := false
	var is_f := false
	var d := "" # if -d is used, the 'd' variable will store the delimiter
	var input := standard_input
	var number_of_options := options.size()
	var i := 0
	while i < number_of_options:
		if options[i].is_flag():
			match options[i].value:
				"c":
					if is_f:
						return {
							"error": "impossible d'utiliser les options '-f' et '-c' en même temps."
						}
					if not d.empty():
						return {
							"error": "impossible d'utiliser les options '-d' et '-c' en même temps."
						}
					i += 1
					if i >= number_of_options:
						return {
							"error": "une valeur est attendue après l'option '-c'."
						}
					if not options[i].is_word():
						return {
							"error": "une valeur numérique ou un intervalle sont attendus après l'option '-c'."
						}
					selection = options[i].value
					is_c = true
				"f":
					if is_c:
						return {
							"error": "impossible d'utiliser les options '-c' et '-f' en même temps."
						}
					i += 1
					if i >= number_of_options:
						return {
							"error": "une valeur est attendue après l'option '-f'."
						}
					if not options[i].is_word():
						return {
							"error": "une valeur numérique ou un intervalle sont attendus après l'option '-f'."
						}
					selection = options[i].value
					is_f = true
				"d":
					if is_c:
						return {
							"error": "impossible d'utiliser les options '-c' et '-d' en même temps."
						}
					i += 1
					if i >= number_of_options:
						return {
							"error": "une valeur est attendue après l'option '-d'."
						}
					if not options[i].is_word():
						return {
							"error": "un pattern est attendu après l'option '-d'."
						}
					d = options[i].value
				_:
					return {
						"error": "l'option '-" + options[i].value + "' est inconnue."
					}
		else:
			if not options[i].is_word():
				return {
					"error": "option inattendue : '" + str(options[i].value) + "'."
				}
			var path := PathObject.new(options[i].value)
			if not path.is_valid:
				return {
					"error": "le chemin vers le fichier n'est pas valide."
				}
			var element = get_file_element_at(path)
			if element == null:
				return {
					"error": _display_error_or("la destination n'existe pas.")
				}
			if not element.is_file():
				return {
					"error": "impossible de lire un dossier."
				}
			if not element.can_read():
				return {
					"error": "permission refusée."
				}
			if (i + 1) < number_of_options:
				return {
					"error": "le fichier devrait être la dernière option donnée à la commande."
				}
			input = element.content
			break
		i += 1
	if not is_c and not is_f:
		return {
			"error": "aucune option donnée !"
		}
	if selection == null:
		return {
			"error": "aucune sélection donnée !"
		}
	if is_f and d.empty():
		d = "\t"
	var lines := input.split("\n", false)
	if is_c:
		# Before reading the selection
		# we have to know what's the maximum,
		# in case the user writes "5-" for example.
		# However if the input is empty, we can't do that.
		# If the selection has an error, we have to return the error in priority.
		# Setting the max to a pointless constant allows the `_read_cut_range` to be executed.
		var max_line_length: int
		if lines.empty():
			max_line_length = 1
		else:
			max_line_length = lines[0].length()
			for j in range(1, lines.size()):
				if lines[j].length() > max_line_length:
					max_line_length = lines[i].length()
		var selections := _read_cut_range(selection, max_line_length)
		if selections.error != null:
			return selections
		for line in lines:
			for index in selections.list:
				if index >= line.length():
					break
				else:
					output += line[index]
			output += "\n"
	else:
		# Same as above, we have to execute _read_cut_range() even if the input is empty.
		# Sounds weird, but if the selection has an error, it must be told to the user in priority.
		# Executing this function is the only way to know that.
		var max_count: int
		var splits: Array
		if lines.empty():
			max_count = 1
		else:
			splits = [lines[0].split(d, true)]
			max_count = splits[0].size()
			for j in range(1, lines.size()):
				splits.append(lines[j].split(d, true))
				if splits[j].length() > max_count:
					max_count = splits[j].value
		var selections := _read_cut_range(selection, max_count)
		if selections.error != null:
			return selections
		for line_groups in splits:
			if line_groups.size() == 1: # if there is only one element, it means there is not delimiter. The only element is therefore the line itself
				output += line_groups[0] + "\n"
			else:
				for index in selections.list:
					if index >= line_groups.size():
						break
					else:
						output += line_groups[index]
				output += "\n"
	return {
		"output": output,
		"error": null
	}

func startm99(options: Array, _standard_input: String) -> Dictionary:
	if options.size() != 0:
		return {
			"error": "aucune option n'est attendue."
		}
	if m99.PROGRAM == null:
		m99.init_blank_M99()
	m99.started = true
	return {
		"output": m99.buildm99(),
		"error": null
	}
