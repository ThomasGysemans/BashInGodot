extends Object
class_name DNS

const domain_regex: String = "^(?=.{1,253}\\.?$)(?:(?!-|[^.]+_)[A-Za-z0-9-_]{1,63}(?<!-)(?:\\.|$)){2,}$"
const ipv4_regex: String = "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$"
const mac_regex: String = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"

# The `config` variable holds all the DNS configurations.
# It's an array of dictionaries, with each dictionary a unique DNS entry.
# {
#   "ipv4": String,
#   "ipv6": String, # can be empty
#   "name": String,
#   "mac": String
# }
# It is useful if you want to configure network features using Bash commands.
var config := []

static func is_valid_entry(entry: Dictionary) -> bool:
	if not "ipv4" in entry or not "ipv6" in entry or not "name" in entry or not "mac" in entry: return false
	if not is_valid_ipv4(entry.ipv4): return false
	if not entry.ipv6.empty() and not is_valid_ipv6(entry.ipv6): return false
	if not is_valid_domain(entry.name): return false
	if not is_valid_mac_address(entry.mac): return false
	return true

static func is_valid_ipv4(address: String) -> bool:
	var regex := RegEx.new()
	regex.compile(ipv4_regex)
	return regex.search(address) != null 

static func is_valid_ipv6(address: String) -> bool:
	return not is_valid_ipv4(address) and address.is_valid_ip_address()

static func is_valid_domain(domain: String) -> bool:
	var regex := RegEx.new()
	regex.compile(domain_regex)
	return regex.search(domain) != null

static func is_valid_mac_address(address: String) -> bool:
	var regex := RegEx.new()
	regex.compile(mac_regex)
	return regex.search(address) != null

func _init(c: Array = []):
	config = c

func add_entry(entry: Dictionary) -> void:
	config.append(entry)

func remove_entry(value: String, property: String):
	var entry = null
	for i in range(0, config.size()):
		if config[i][property] == value:
			entry = config[i]
			config.remove(i)
			break
	return entry

func get_entry(value: String, property: String):
	for entry in config:
		if entry[property] == value:
			return entry
	return null

func _to_string():
	return str(config)
