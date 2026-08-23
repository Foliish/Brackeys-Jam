extends Control
class_name PlatformControl

# Control model containing configuration for this controller.
@export var model: ControlModel

# Signal emitted when player input is received (passes player ID and event arguments).
signal player_input(player_id: int,args: IEventArguments)

# Constructs control UI elements based on the provided model.
func constract(_model: ControlModel)-> void:
	pass

# Method to scale/resize control elements.
func resize(size: Vector2i) -> void:
	pass
