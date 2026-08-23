extends RefCounted
class_name Configs

# Register class in serializer upon type initialization
static func _static_init() -> void:
	ObjectSerializer.register_script("Configs", Configs)

var color: Color
var winPoints: int
const CONFIG_PATH = "res://minigame/config.json"

# Reads minigame configuration from a JSON file or returns default configuration
static func get_config() -> Configs:
	if FileAccess.file_exists(CONFIG_PATH):
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var config = DictionarySerializer.deserialize_json(json_string) as Configs
		if config:
			return config

	var default_config = Configs.new()
	default_config.color = Color.WHITE
	default_config.winPoints = 5
	return default_config
