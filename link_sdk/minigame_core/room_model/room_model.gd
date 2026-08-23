extends Node
class_name RoomModel

# List of all player models in the room.
var players: Array[PlayerModel]
# Player IDs located on the local device.
## Host device data.
var my_device: Device # explicit network only
## List of all connected devices in the game session.
var device_list: DeviceList # explicit network only
# Signal emitted when player input is received.
signal player_input(player_id: int,args: IEventArguments)

# Static class initialization to register in object serializer.
static func _static_init() -> void:
	ObjectSerializer.register_script("RoomModel", RoomModel)
