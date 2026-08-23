class_name CLinkChatMessage
extends RefCounted

## Class representing a unified chat message received from a stream chat service.
## Contains author info, message content, platform metadata, and role flags.

# Message Identification & Metadata
var id: String = ""
var platform: String = "" # "twitch", "youtube", "tiktok", "kick", etc.
var channel_id: String = ""
var timestamp: String = ""

# Author Information
var author: CLinkChatAuthor = CLinkChatAuthor.new()

# Message Content
var raw_text: String = ""
var is_command: bool = false
var command: String = ""
var command_args: Array[String] = []
var emotes: Array = []

# Raw JSON data payload
var raw_data: Dictionary = {}


func _init(p_raw_text: String = "", p_author_name: String = "", p_platform: String = "") -> void:
	raw_text = p_raw_text
	author = CLinkChatAuthor.new(p_author_name, p_author_name)
	platform = p_platform
	if not raw_text.is_empty():
		_parse_command_from_text()


## Creates and populates a CLinkChatMessage instance from a UnifiedChatMessage JSON dictionary.
static func from_dict(dict: Dictionary) -> CLinkChatMessage:
	var msg := CLinkChatMessage.new()
	msg.raw_data = dict
	
	msg.id = str(dict.get("id", ""))
	msg.platform = str(dict.get("platform", ""))
	msg.channel_id = str(dict.get("channel_id", ""))
	msg.timestamp = str(dict.get("timestamp", ""))
	
	# Parse Author
	var author_data: Dictionary = dict.get("author", {}) if dict.get("author") is Dictionary else {}
	msg.author = CLinkChatAuthor.from_dict(author_data)
	
	# Parse Content
	var content_data: Dictionary = dict.get("content", {}) if dict.get("content") is Dictionary else {}
	if not content_data.is_empty():
		msg.raw_text = str(content_data.get("raw_text", ""))
		var raw_emotes = content_data.get("emotes", [])
		if raw_emotes is Array:
			msg.emotes = raw_emotes
	else:
		# Fallback if raw_text is directly at top level
		msg.raw_text = str(dict.get("raw_text", dict.get("text", "")))
	
	msg._parse_command_from_text()
	return msg


## Creates a CLinkChatMessage instance directly from a JSON string.
static func from_json(json_string: String) -> CLinkChatMessage:
	var json := JSON.new()
	var error := json.parse(json_string)
	if error == OK and json.data is Dictionary:
		return CLinkChatMessage.from_dict(json.data)
	return CLinkChatMessage.new()


## Converts the message object back into a dictionary representation.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"platform": platform,
		"channel_id": channel_id,
		"timestamp": timestamp,
		"author": author.to_dict() if author else {},
		"content": {
			"raw_text": raw_text,
			"emotes": emotes
		}
	}


## Converts the message object into a JSON string.
func to_json() -> String:
	return JSON.stringify(to_dict())


## Returns the best display name for the message author.
func get_author_name() -> String:
	return author.get_name() if author else "Anonymous"


## Returns true if the message author has a specific role name.
func has_role(role_name: String) -> bool:
	return author.has_role(role_name) if author else false


## Internal method: Parses command name and arguments from raw_text if it starts with cmd_prefix.
func _parse_command_from_text(cmd_prefix: String = "!") -> void:
	var text := raw_text.strip_edges()
	if text.begins_with(cmd_prefix):
		is_command = true
		var parts := text.substr(cmd_prefix.length()).split(" ", false)
		if parts.size() > 0:
			command = parts[0]
			command_args.clear()
			for i in range(1, parts.size()):
				command_args.append(parts[i])
	else:
		is_command = false
		command = ""
		command_args.clear()
