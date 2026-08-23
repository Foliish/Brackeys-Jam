extends IEventArguments
class_name JoystickEventArgs

# Joystick stick deflection direction
var direction: Vector2 
# Deflection/press force (from 0.0 to 1.0)
var force: float 
# Time delta from previous update frame
var delta_time: float
# True if screen click
var click: bool

static func _static_init() -> void:
	ObjectSerializer.register_script("JoystickEventArgs", JoystickEventArgs)
