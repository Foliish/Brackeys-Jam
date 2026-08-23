extends RefCounted
class_name DeviceList

var colors: Array[Color] = [
	Color("ff2a2a"),       # Bright red
	Color("2980b9"),       # Classic blue
	Color("2ecc71"),       # Neon green
	Color("f1c40f"),       # Yellow
	Color("8e44ad"),       # Purple
	Color("e67e22"),       # Orange
	Color("1abc9c"),       # Turquoise
	Color("fd79a8"),       # Pink
	Color("2d3436"),       # Dark graphite
	Color("00cec9"),       # Bright cyan
	Color("6c5ce7"),       # Neon purple
	Color("badc58"),       # Light green
	Color("ff7675"),       # Coral
	Color("ffeaa7"),       # Beige
	Color("a29bfe"),       # Lavender
	Color("e84393"),       # Crimson
	Color("00b894"),       # Mint
	Color("0984e3"),       # Electric blue
	Color("d63031"),       # Burgundy
	Color("fdcb6e"),       # Mustard
	Color("6ab04c"),       # Grass green
	Color("e3e3e3"),       # Light gray
	Color("ff9f43"),       # Sunny orange
	Color("ffffff")        # White
]
var _devices: Array[Device] = []

var player_ids_to_peer_ids: Dictionary[int,int] = {}

# Static initialization to register class in serializer.
static func _static_init() -> void:
	ObjectSerializer.register_script("DeviceList", DeviceList)
