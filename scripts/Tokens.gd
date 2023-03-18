extends Object
class_name Tokens

const PLAIN = "P" # just something such as "hello", "[:UPPER:]", "file.txt". Something that does not contain white space.
const STRING = "S" # a string (so something between quotes, which are '"' or "'"). Everything inside will not get interpreted
const FLAG = "F" # an option which starts with "-" and has a name of length == 1
const LONG_FLAG = "LG" # an option which starts with "--" and has a name of length > 1
const PIPE = "PI" # a pipe (|) that separated two commands
const EOF = "EOF" # end of string
const DESCRIPTOR = "DES" # 1>file.txt, here 1 is a descriptor
const WRITING_REDIRECTION = ">"
const APPEND_WRITING_REDIRECTION = ">>"
const READING_REDIRECTION = "<"
const AND = "&" # &, useful when we have "(n)>&(m)"
