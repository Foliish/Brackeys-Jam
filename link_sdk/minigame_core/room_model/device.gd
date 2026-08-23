extends RefCounted
class_name Device

# Enumeration of possible connected device types
enum DeviceType { PHONE, TABLET, LAPTOP, PC }

var peer_id: int = 0
var name: String = ""
var type: DeviceType = DeviceType.PHONE
var player_count: int = 1

var players: Array[PlayerModel] = []

static func _static_init() -> void:
	ObjectSerializer.register_script("Device", Device)
