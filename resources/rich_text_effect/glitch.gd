tool
extends RichTextEffect


# Syntax: [heart scale=1.0 freq=8.0][/heart]
var bbcode = "glitch"

const TO_CHANGE = [ord("0"), ord("1")]

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var scale:float = char_fx.env.get("scale", 16.0)
	var freq:float = char_fx.env.get("freq", 2.0)

	var x =  char_fx.absolute_index / scale - char_fx.elapsed_time * freq
	var t = abs(cos(x)) * max(0.0, smoothstep(0.712, 0.99, sin(x))) * 2.5;
	char_fx.offset.y -= t * 4.0
	
	char_fx.character = TO_CHANGE[0]
	var c = char_fx.character
	if randi() % 2 == 0:
		char_fx.character = TO_CHANGE[randi() % 2]
	
	return true
