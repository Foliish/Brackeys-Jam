class_name CLinkChatAuthor
extends RefCounted

## Class representing author information for a stream chat message.
## Contains author profile details, badges, and platform role flags.

# Identification & Profile
var id: String = ""
var username: String = ""
var display_name: String = ""
var avatar_url: String = ""
var badges: Array[String] = []

# Roles & Permissions
var primary_role: String = "viewer" # "broadcaster", "owner", "moderator", "subscriber", "sponsor", "vip", "gift_sender", "viewer"
var is_broadcaster: bool = false
var is_mod: bool = false
var is_subscriber: bool = false
var is_vip: bool = false
var platform_role_names: Array[String] = []


func _init(p_username: String = "", p_display_name: String = "") -> void:
	username = p_username
	display_name = p_display_name if not p_display_name.is_empty() else p_username


## Creates and populates a CLinkChatAuthor instance from a Dictionary payload.
static func from_dict(dict: Dictionary) -> CLinkChatAuthor:
	var author := CLinkChatAuthor.new()
	if dict.is_empty():
		return author
	
	author.id = str(dict.get("id", ""))
	author.username = str(dict.get("username", ""))
	author.display_name = str(dict.get("display_name", author.username))
	author.avatar_url = str(dict.get("avatar_url", "")) if dict.get("avatar_url") != null else ""
	
	var raw_badges = dict.get("badges", [])
	if raw_badges is Array:
		author.badges.clear()
		for b in raw_badges:
			author.badges.append(str(b))
	
	# Parse Roles
	var roles_data: Dictionary = dict.get("roles", {}) if dict.get("roles") is Dictionary else {}
	if not roles_data.is_empty():
		author.is_broadcaster = bool(roles_data.get("is_broadcaster", false))
		author.is_mod = bool(roles_data.get("is_mod", false))
		author.is_subscriber = bool(roles_data.get("is_subscriber", false))
		author.is_vip = bool(roles_data.get("is_vip", false))
		author.primary_role = str(roles_data.get("primary_role", "viewer"))
		
		var p_roles = roles_data.get("platform_role_names", [])
		if p_roles is Array:
			author.platform_role_names.clear()
			for r in p_roles:
				author.platform_role_names.append(str(r))
	
	return author


## Converts the author object into a dictionary representation.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"username": username,
		"display_name": display_name,
		"avatar_url": avatar_url,
		"badges": badges,
		"roles": {
			"is_broadcaster": is_broadcaster,
			"is_mod": is_mod,
			"is_subscriber": is_subscriber,
			"is_vip": is_vip,
			"primary_role": primary_role,
			"platform_role_names": platform_role_names
		}
	}


## Returns the best display name for the author.
func get_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not username.is_empty():
		return username
	return "Anonymous"


## Returns true if the author has a specific role name.
func has_role(role_name: String) -> bool:
	var role_lower := role_name.to_lower()
	if primary_role.to_lower() == role_lower:
		return true
	if role_lower in ["broadcaster", "owner", "streamer"] and is_broadcaster:
		return true
	if role_lower in ["mod", "moderator"] and is_mod:
		return true
	if role_lower in ["sub", "subscriber"] and is_subscriber:
		return true
	if role_lower == "vip" and is_vip:
		return true
	for r in platform_role_names:
		if r.to_lower() == role_lower:
			return true
	return false
