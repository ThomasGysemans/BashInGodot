extends Object
class_name Tokens

const PLAIN = "PLAIN" # just something such as "hello", "[:UPPER:]", "file.txt". Something that does not contain white space.
const STRING = "STRING" # a string (so something between quotes, which are '"' or "'"). Everything inside will not get interpreted
const FLAG = "FLAG" # an option which starts with "-" and has a name of length == 1
const LONG_FLAG = "LONG_FLAG" # an option which starts with "--" and has a name of length > 1
const PIPE = "PIPE" # a pipe (|) that separated two commands
const EOF = "EOF" # end of string
