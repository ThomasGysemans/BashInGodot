# BashInGodot

A Bash Terminal in your Godot Game.

> **IMPORTANT** : the text is written in French.

A demo is available online : [https://learn-bash.sciencesky.fr/](https://learn-bash.sciencesky.fr/)

## Table of contents

- [Introduction](#introduction)
  - [Available Bash Features](#available-bash-features)
  - [Unavailable Bash Features](#unavailable-bash-features)
  - [Additional Features](#additional-features)
- [Class Names](#class-names)
- [How it works](#how-it-works)
  - [Lexer](#tokenization)
  - [Parser](#parsing)
  - [Interpreter](#interpretation)
- [Get Started](#get-started)
  - [Customise Your Terminal](#customise-your-terminal)
  - [Create Your File Structure](#create-your-file-structure)
  - [DNS](#dns)
  - [Using Multiple Consoles](#using-multiple-consoles)
  - [Helper Methods From Paths](#helper-methods-from-paths)
  - [Helper Methods From Terminal](#helper-methods-from-terminal)
- [Signals](#signals)
- [Allowing or Disabling Commands](#allowing-or-disabling-commands)
- [Additional Feature: M99](#additional-feature-m99)

## Introduction

A custom Bash parser was created to customise the behaviour of Bash and to make it easier to learn. A few differences remain between the real Bash and my implementation.

#### Available Bash Features

|Name|Description|
|----|-----------|
|File structure|Custom file structure.|
|man command|Each command has its own manual.|
|command1 \| command2|Several commands can be written on the same line and get the standard output of the previous one as its standard input.|
|command 2>error_redirection|Redirections are available. Use `0`, `1` or `2` with their symbols `>`, `<` or `>>`. Note that `<<` is not available.|
|echo $HELLO|Variables are available. Define one with the syntax `NAME=VALUE` and use it with the syntax `$NAME`.|
|echo "$FOO"|Strings are interpreted as one argument, and characters can be escaped, and double quotes act like they should.|
|`cat $(echo file.txt) 1>$(echo copy.txt) 2>&$(echo 1)`|Command substitutions.|
|./script|A script can be executed. The lines starting with `#` will be ignored.|
|Permissions|Each file can have its own permissions. Use `chmod` with the digital representation of the permissions, or use the shortcut for each kind of permission (`chmod g-x .` for example).| 
|History|The user can use previous commands and navigate through the history using the up and down arrow keys.|
|Autocompletion|Pressing the Tab key will autocomplete the path as much as possible relative to the written path.|

#### Unavailable Bash Features

|Name|Description|
|----|-----------|
|Processes|There is no process, no `pid`. However, there is the possibility to use `$$`.|
|Prompting|A command cannot ask an input to the user, nor a confirmation before execution.|
|Background tasks|The symbol `&` to run tasks in the background is unknown.|
|Home|The symbol `~` is unknown.|
|Multi-user|Even though you can set the creator's name of a file, there is no way to properly log in. Besides, the permissions verifications are only done on the user side, meaning that the permissions granted to the group and to the others actually don't matter and are ignored.|

And some other things that i didn't quote.

#### Additional Features

|Name|Description|
|----|-----------|
|[M99](#additional-feature-m99)|A basic language that resembles Assembler.|

### Class Names

- `BashContext`
- `BashParser`
- `BashToken`
- `DNS`
- `ErrorHandler`
- `M99`
- `PathObject`
- `System`
- `SystemElement`
- `Terminal`
- `Tokens`

## How it works

I will explain how my Bash works using an example. Let's consider the following command:

```bash
echo -n "This is text." | cat 1>result.txt
```

My algorithm goes through these 3 steps :

- Syntax analysis and tokenization using a "lexer"
- Parsing
- Intepretation

#### Tokenization

The loop goes through each character of the input and guesses what it is reading. It first starts by reading the word `echo` and stops as soon as it encounters a white space. It registers this entry in an array of `BashToken`s.

The `echo` is considered to be a `PLAIN` token. A `BashToken` instance is created with the token type and its value. Then, all white space is ignored until it detects the dash (`-`). My lexer considers that this is a flag.

There are two types of flags : normal flags (`Tokens.FLAG`), and long flags (`Tokens.LONG_FLAG`).

Writing `-la` will be interpreted as two separate flags : `-l` and `-a`. Meaning that the short flags with a name of several characters are not allowed.

Afterwards, the lexer reads a quote (`"`). It then reads the entire content of the string, ignoring the espace characters until it detects the end of the string. The `BashToken` instance will remember what type of quotes were used for the parsing process. It is important to remember this detail because the parser is responsible of intepreting the variables it may contain.

The pipe characer `|` is registered and will be very important in the parsing process.

The lexer will finally return the following array :

```
[
  BashToken(type:PLAIN, value:echo),
  BashToken(type:FLAG, value:n),
  BashToken(type:STRING, value:This is text., quote: "),
  BashToken(type:PIPE, value:'|'),
  BashToken(type:PLAIN, value:cat),
  BashToken(type:DESCRIPTOR, value:1),
  BashToken(type:WRITING_REDIRECTION, value:'>'),
  BashToken(type:PLAIN, value:result.txt)
]
```

The lexer step makes the interpretation of the command much easier.

#### Parsing

Basically, it takes as input the result of the lexer and returns an array of nodes. There are two types of nodes : `command` and `variable`. A variable affectation is very different from a command so it deserved its own node. A node is just a dictionary.

Our example will give the following result:

```
[
  {
    "type": "command",
    "name": "echo",
    "options": [
      BashToken(type:FLAG, value:n),
      BashToken(type:STRING, value:This is text.)
    ],
    "redirections": []
  },
  {
    "type": "command",
    "name": "cat",
    "options": [],
    "redirections": [
      {
        "port": 1,
        "type": Tokens.WRITING_REDIRECTION,
        "target": "result.txt",
        "copied": false # true when the redirection is `2>&1` for example
      }
    ]
  }
]
```

#### Interpretation

The interpretation process is very easy. It takes each node and calls the function named `execute`. Each Bash command has its own function. For example there is a function named "cat" somewhere in the code (`Terminal.gd`). It takes the `options` array from the node (**options != flags**) and the standard input. The `execute` function makes it so that the standard input of a command is the standard output of the previous one, when it is followed by a pipe.

From our example, the `cat` command receives the standard output of `echo` which is the string "This is text.". According to the normal behaviour of the `cat` command, the standard input, if given, becomes the standard output of the command, and, if it is the last command of the input, it is printed on the interface. However, because there is a redirection, the `execute` function redirects it and write to the file `result.txt`.

Our command will not print anything, but will create a file named `result.txt` which content is `This is text.`.

A lot more is going on underneath the surface. For example, we need to make sure that the user has the permissions to edit the current folder with a new file "result.txt" (`w`). If the file already exists, it needs to make sure that the file has the correct permissions too.

## Get Started

The plugin adds a new node named `Console`. This console creates a terminal with an interface (a `RichTextLabel`) and a prompt at the bottom (a `LineEdit`). It also adds an optional `WindowDialog` node for the `nano` command.

A `Console` implements the script called `ConsoleNode.gd` which is responsible of receiving the signal when the Enter key is pressed on the prompt in order to execute the given command. It also provides an autocompletion feature so that to autocomplete the file path the user is writing when pressing the Tab key (_the input map is called `autocompletion`_). The Console comes with a history of commands too in order to re-enter previous commands easily. Navigate through the previous commands using the up and down arrow keys.

On the `ConsoleNode` you can use the following methods: 

- `set_font_size(size:int) -> void`
- `set_system(system_reference: System) -> void`

### Customise Your Terminal

To customise a `Console` node, you can use its export variables :

- `User Name` (String)
- `Group Name` (String)
- `IP Address` (String)
- `System Reference Node` (NodePath), see [Create your file structure](#create-your-file-structure)
- `PID` (int, -1 for random one)
- `Max Paragraph Size` (int, -1 for default one, which is 50)
- `Default Font Size` (int, 14 by default)

**Notes**:

Note that `Max Paragraph Size` is the maximum number of characters for the description of a command in the manual. The words do not get broken, the next whitespace is used to break the line.

Because `$$` is valid in Bash and returns the current PID number, this can be customised. By default, the PID is random.

An IP address can be used to simulate the `ping` command. If you need this command, see the [DNS](#dns) section.

### Create Your File Structure

By default, there is no file, no folder. Just the root. Use the `Reference Node` export variable from the Console node to change that. This variable expects the path to a node. Create a nearby node and follow the example below :

```gdscript
extends Node2D

var system := System.new([
	SystemElement.new(0, "file.txt", "/", "", [], user_name, group_name),
	SystemElement.new(1, "folder", "/", "", [
		SystemElement.new(0, "answer_to_life.txt", "/folder", "42", [], user_name, group_name),
		SystemElement.new(0, ".secret", "/folder", "ratio", [], user_name, group_name),
	], user_name, group_name),
])
```

which leads to:

```
/
  - file.txt
  - folder/
    - answer_to_life.txt
    - .secret
```

`System` represents your file structure. Create a file, or a folder, which are both instances of `SystemElement`, using the following constructor :

```
SystemElement.new(
  type: int # 0 for a file, 1 for a folder
  name: String # the name of the element
  absolute_path_of_parent: String # the absolute path of the containing folder

  # optional

  content: String # the content of the file, empty string for folders
  children: Array # array of system elements
  user_name: String # the creator of the file
  group_name: String # the creator's group name
  permissions: String # custom permissions (three digits)
)
```

> **NOTE**: the file [demo-system.gd](./demo-system.gd) contains a full example with details and comments.

From SystemElement, you may want to use these methods:

|Name|Description|
|----|-----------|
|`append(element: SystemElement) -> void`|Adds an element.|
|`set_default_permissions() -> void`|`755` for folders, `644` for files.|
|`count_depth() -> int`|Counts how deep is an element.|
|`is_file() -> bool`|`true` if the element is a file (type == 0).|
|`is_folder() -> bool`|`true` if the element is a folder (type == 1).|
|`is_hidden() -> bool`|`true` if the name starts with an underscore.|
|`rename(name: String) -> void`|Renames the element.|
|`move_inside_of(abs_path: String or PathObject) -> self`|Moves the element elsewhere along with its children.|
|`equals(other: SystemElement) -> bool`|Returns `true` if the element equals the other. The condition is based on the type of each element and their absolute path.|
|`set_permissions(p: String) -> bool`|Returns `true` if the change of permissions went successfully. If the given permissions are not valid, it will return `false`.|
|`set_specific_permission(p: String) -> bool`|Sets a permission for the user, the group or the others. This method is called when setting the permissions using the simplified syntax (example: `g-w` removes `w` from the group).|
|`build_permissions_string() -> String`|Returns an easy-to-read representation of the permissions granted to the file. For example, the default permissions of a folder are `drwxr-xr-x` (755).|
|`calculate_size() -> int`|Returns the number of bytes contained in the `content` property of the file. It is recursive if the element is a folder.|
|`get_formatted_creation_date() -> String`|Returns a string which contains the creation date, including the hour.|
|`into_long_format() -> String`|Returns the result you get when using the command `ls -l`. It contains the permissions, the size, the name, the creator, the creation date etc. on a single line.|
|`can_read() -> bool`|Checks if the user has the permission to read the element. As said previously, permissions granted to the group and to the others don't matter and are ignored.|
|`can_write() -> bool`|Checks if the user has the permission to write to the element. If the element is a folder, the user cannot create new files inside it.|
|`can_execute_or_go_through() -> bool`|Checks if the element has the `x` permission.|

## DNS

You can simulate the `ping` command (optional). Note that, for now at least, this doesn't open a web socket. You have to create your own `DNS` (using the `DNS` hand-made class). Create your own IP and MAC addresses in the Reference Node as seen above.

The terminal must have an `IP address`. See [Customise Your Terminal](#customise-your-terminal).

```gdscript
# In the script attached to the referent node.
extends Node2D

var dns := DNS.new([
  # This dictionary is an "entry"
  {
    "ipv4": "196.168.10.1",
    "ipv6": "", # optional
    "name": "example.com",
    "mac": "00-B0-D0-63-C2-26"
  }
])
```

> **NOTE**: find a complete example in this file: [demo-system.gd](./demo-system.gd).

You may want to use the following methods from `DNS`:

|Name|Description|
|----|-----------|
|`static is_valid_entry(entry: Dictionary) -> bool`|Checks if the entry is correct. See an example of an entry in the code given above.|
|`static is_valid_ipv4(ip: String) -> bool`|Checks if the given IP is a valid IPv4 address. If you want to check if an IP is valid, without paying attention to its type, then use the built-in method [is_valid_ip_address](https://docs.godotengine.org/en/3.5/classes/class_string.html#class-string-method-is-valid-ip-address).|
|`static is_valid_ipv6(ip: String) -> bool`|Checks if the given IP is a valid IPv6 address. If you want to check if an IP is valid, without paying attention to its type, then use the built-in method [is_valid_ip_address](https://docs.godotengine.org/en/3.5/classes/class_string.html#class-string-method-is-valid-ip-address).|
|`static is_valid_domain(domain: String) -> bool`|Checks if a domain is valid.|
|`static is_valid_mac_address(address: String) -> bool`|Checks if the given MAC address is valid.|
|`add_entry(entry: Dictionary) -> void`|Adds an entry to the DNS instance.|
|`remove_entry(value: String, property: String)`|Removes an entry according to a precise property. For example, if you want to remove an entry based on an IPv4 address, then give the IP address to `value` and "ipv4" to `property`. Returns the deleted entry, or null if it doesn't exist.|
|`get_entry(value: String, property: String)`|This method works exactly like `remove_entry`.|

> **NOTE**: because it's hard to find a regular expression that matches all the different kinds of domains, I cannot guarantee that `is_valid_domain` will work on **all** domains.

## Using Multiple Consoles

As explained in the [Create your file structure](#create-your-file-structure), you need to create a nearby 2D node that contains the right variables and to assign this node to the `Reference Node` export variable of the `Console` node.

Because the instances of `DNS` and `System` are given by reference, a modification to the file structure from one terminal will also be applied to the others.

See the demo scene called [demo-multiple-consoles.tscn](./demo-multiple-consoles.tscn).

> **NOTE**: you cannot interact with one terminal from another one.

## Helper Methods From Paths

The paths are described as instances of `PathObject`. You may want to use them when trying to access a particular element in your structure for example.

```gdscript
# PathObject expects a single string,
# a path to a folder, or a file,
# which can be either absolute or relative.
# It must be based to a particular terminal,
# according to the `PWD` property of `Terminal`.
var path := PathObject.new(
  "./file.txt"
)
```

> **NOTE**: an instance of `PathObject` must be immutable. Do not try to change the value of a property, create a new instance instead.

From `PathObject`, here some useful properties:

- `path`: (String) the path as given in the constructor.
- `parent`: (String or null) the folder that the element is contained in according to the given path. It can be null if the path is relative.
- `file_name`: (String) the name of the latest segment of the path.
- `type`: (int) I assume that a path ending with a `/` is folder (1), otherwise it's a file (0).
- `segments`: (array of strings) each part of the path.
- `is_valid`: (bool) the path written by the user might be wrong.

Use the following methods:

|Name|Description|
|----|-----------|
|`static simplify_path(p: String) -> String`|Simplifies the given path. For example `./././././../` is the same as `../`.|
|`is_leading_to_file() -> bool`|`true` if the name doesn't end with a `/`.|
|`is_leading_to_folder() -> bool`|`true` if the name ends with a `/`.|
|`is_absolute() -> bool`|`true` if the given path is absolute.|
|`equals(other_path: PathObject or String) -> bool`|`true` if the current `path` equals the simplified version of the given path. It cannot check if the paths are leading to the same place as `PathObject` doesn't know what the structure is.|

## Helper Methods From Terminal

The `Terminal.gd` script is responsible of the interpretation step of the algorithm. It contains the code of each command.

It is a global class called `Terminal`. Each `Console` node has a property named `terminal` which is the instance that the console creates in order to execute the given commands.

If needed, create a new instance of `Terminal` like this:

```gdscript
var terminal := Terminal.new(
  pid: int,
  system: System,
  editor: WindowDialog # optional, used for the `nano` command
)
```

> **NOTE**: the commands are a dictionary called `COMMANDS`. It is not a constant because when we want to execute a function, we use a `funcref` on one of the methods inside of `Terminal`. The manual page is also described in this dictionary and later built with `build_manual_page_using()`.

Customise it with these methods:

|Name|Description|
|----|-----------|
|`static replace_bbcode(text: String, replacement: String) -> String`|Replaces the bbcode contained in the `text` with `replacement`.|
|`static cut_paragraph(paragraph: String, line_length: int) -> Array`|Cuts the paragraph in order to respect a precise limit of characters for each line. It does not break a word, but instead goes on above the limit until it reaches either the end of the input or a white space.|
|`static build_manual_page_using(manual: Dictionary, max_size: int) -> String`|This function builds a nice looking UI from the manual of a command.|
|`static build_help_page(text: String, commands: Dictionary) -> String`|Builds the help page based on the given text and commands. The help page will list all the available commands at the end.|
|`set_editor(editor: WindowDialog) -> void`|Defines what editor to use for the `nano` command.|
|`set_dns(d: DNS) -> void`|Defines what DNS configuration to use.|
|`use_interface(interface: RichTextLabel) -> void`|Even though the Terminal doesn't print anything to the interface, it's mandatory for the M99.|
|`set_custom_text_width(max_char: int) -> void`|Defines the maximum length for the description section of the manual page.|
|`set_ip_address(ip: String) -> bool`|In order to use the `ping` command, the Terminal needs to have an IP address. Returns `false` if the IP is not valid.|
|`set_allowed_commands(commands: Array) -> void`|Define what commands are allowed. See [Allowing or Disabling Commands](#allowing-or-disabling-commands) for more details.|
|`forbid_commands(commands: Array) -> void`|Forbid commands. See [Allowing or Disabling Commands](#allowing-or-disabling-commands) for more details.|
|`execute(input: String, interface: RichTextLabel = null) -> Dictionary`|Executes the given command. If the command is a script execution, then it executes it. If the command is a M99 command, it will execute it too (if it was started, obviously). Returns a dictionary with key `error` which contains an explanation of what went wrong, otherwise `error` is null and the return value is a dictionary with the following keys: `output` (what needs to be printed on the interface) and `interface_cleared` (a boolean that says `true` if the `clear` command was used).|
|`execute_file(file: SystemElement, options: Array, interpreted_redirections: Array, interface: RichTextLabel = null) -> Dictionary`|Executes a script. You should use the `execute` command for this unless you know exactly what you're doing.|
|`execute_m99_command(command_name: String, options: Array, interface: RichTextLabel = null) -> Dictionary`|Executes a M99 command. Same as `execute_file` you should use `execute` instead.|
|`get_file_element_at(path: PathObject)`|Gets a file element according to the given path. If an error occured, the `error_handler` property will have an error (`error_handler.has_error` set to `true`). If the destination doesn't exist or if an error occured, it will return `null`, otherwise an instance of `SystemElement`.|
|`get_pwd_file_element() -> SystemElement`|Same as `get_file_element_at` but this time the path is the `PWD` property of `Terminal`.|
|`get_parent_element_from(path: PathObject) -> SystemElement`|Gets the `SystemElement` instance of the folder containing the element of the given `path`. If the path doesn't have a parent, then it just returns the `SystemElement` instance of the `PWD`.|
|`copy_element(e: SystemElement) -> SystemElement`|Returns a deep copy of `e`.|
|`copy_children_of(e: SystemElement) -> Array`|Returns a recursive copy of the children of `e`.|
|`merge(origin: SystemElement, destination: SystemElement) -> bool`|Merges the `origin` with the `destination`. The elements of the same name are overwritten, and those who don't exist are created. Returns `false` if the destination doesn't exist or if it's not a folder.|
|`move(origin: SystemElement, destination: PathObject) -> bool`|Merges the `origin` with the `destination`. The `origin` gets destroyed.|
|`get_file_or_make_it(path: PathObject)`|Gets the `SystemElement` instance located at the given `path`. If it doesn't exist, it's created. Returns `null` if an error occured or if the path leads to a folder.|
|`interpret_redirections(redirections: Array) -> Array`|Because a command can redefine several times each kind of redirections, we want to make a simple array which looks like this: `[standard_input, standard_output, error_output]` which are either null or a dictionary describing how the redirection should behave: `{"type": String (Tokens.WRITING_REDIRECTION for example), "target": SystemElement}`.|

**Details**:

The `System` instance from `Terminal` is a property named `system` and the root is a property from `System` which is named `root`. As a consequence, if you want to get the instance of root from your Terminal, type `my_terminal.system.root`.

Finally, all the variables are stored within the `runtime` property, which is an array of `BashContext`s. You may want to look the file directly and read the comments for more details: [BashContext](./addons/bash_in_godot/scripts/BashContext.gd).

## Signals

The `Terminal` class emits a lot of signals. If you have multiple consoles on your scene, you may want to connect to the signals when creating the `Console` nodes.

- `command_executed (command, output)`

"command" is a dictionary (the result of the parsing step) and "output" is the content of standard output. The signal will be emitted only if the command didn't throw an error.

- `error_thrown (command, reason)`

Emitted when the `command` threw an error, which text is the `reason`.

- `permissions_changed (file)`

`file` is a SystemElement (file or **folder**).

- `file_created (file)`

`file` is a SystemElement (file or **folder**).

- `file_destroyed (file)`

`file` is a SystemElement (file or **folder**).

- `file_changed (file)`

Emitted when "nano" was used to edit the content of a file. It does not detect if the new content is different.

- `file_read (file)`

Emitted when the file is being read (via the cat command).

- `file_copied (origin, copy)`

Emitted when the `origin` is being copied. Note that `origin` != `copy` (not the same reference, and the absolute path of the copy, or its content, might be different from the origin's).

- `file_moved (origin, target)`

Emitted when the `origin` is being moved elsewhere. The origin is destroyed (but `file_destroyed` is not emitted) and `target` is the new instance of `SystemElement`.

- `directory_changed (target)`

Emitted when the `cd` command is used.

- `interface_changed (content)`

Emitted when something needs to be printed onto the screen. It is not emitted when the interface is cleared.

The signal `interface_changed` can be used to read the standard output of a successful command. It is different from `command_executed` because `command_executed` might be thrown several times in a row. Indeed, several commands can be on the same line separated by pipes.

Example:

```bash
$ echo toto | echo tata
```

`command_executed` will be emitted twice with `output` set to "toto" and then "tata".
`interface_changed` will be emitted once with `content` set to "tata" (**the last standard output of the execution**).

- `manual_asked (command_name, output)`

Emitted when the `man` command is used to open the manual page of a command.

- `variable_set (name, value, is_new)`

Emitted when a variable is created, "name" and "value" are strings, "is_new" is true if the variable was just created or false if it was modified.

- `script_executed (script, output)`

Emitted when a script was executed. `script` is the instance of SystemElement of the script, `output` is the complete output printed onto the interface.

- `help_asked`

Emitted when the custom `help` command was used.

- `interface_cleared`

Emitted when the `clear` command was used.

**NOTE**:

All the arguments passed to the signals are passed by **REFERENCE**. Therefore, any modification of the references will modify the terminal's system tree (unless the element is voluntarily removed by the algorithm which is the case for the `origin` argument of the `file_moved` signal).

If a copy needs to be done, then see the following functions:
- `copy_element()` (see [Helper Methods from Terminal](#helper-methods-from-terminal))
- `copy_children_of()` (see [Helper Methods from Terminal](#helper-methods-from-terminal))
- `move_inside_of()` (see [Create Your File Structure](#create-your-file-structure))

## Allowing or Disabling Commands

You can manually disable commands using the methods `set_allowed_commands` and `forbid_commands`. For example, if I want to only enable the commands `echo` and `cat` from the `Console` node:

```gdscript
# Let's consider the variable `console` the instance of `Console` node of your scene.
console.terminal.set_allowed_commands(["echo", "cat"])
```

This method disables all commands by default, except those given as argument. As a consequence, if you want to disable all commands, you can: 

```gdscript
# Disables all commands:
console.terminal.set_allowed_commands([])
```

Now, if you want to forbid just a few commands:

```gdscript
# This code disables the commands "startm99" and "ping".
console.terminal.forbid_commands(["startm99", "ping"])
```

When a command is disabled, it looks like it doesn't exist. Trying to execute it will throw an error: "this command doesn't exist". Same thing if we try to read its manual page. It will not show up in the `help` text.

When you have multiple consoles on the same scene, it's useful to create a nearby 2D node and give the node path as value for the `Reference Node` export variable from the `Console` node. For more details, see the demo: [demo-system.gd](./demo-system.gd).

## Additional Feature: M99

The M99 simulates an assembly language. It is useful for educational purposes. To start it, use the `startm99` custom command.

A few signals are available :

- `program_executed (starting_point, R, A, B, output)`

Emitted when the program was executed. It gives the starting point, the value of the R, A and B registries and the output.

- `program_failed (starting_point)`

Emitted when the execution failed. It gives the starting point of the executed program.

- `on_cell_set (position, value)`

Emitted when the user successfully sets a value for a cell at a specific position.

- `on_program_filled (position, program)`

Emitted when the user uses the `fill` command to fill in multiple commands at a specific position.

For more details, read the help page on the demo (in French).

## Licence

MIT License.