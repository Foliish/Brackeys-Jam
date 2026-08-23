extends PlatformControl
class_name PlatformJoystick

# Joystick settings
@export_group("Settings")
# Reference to touch screen joystick object
var joystick: TouchScreenJoystick
# Input emission interval (0.0 — emit every frame)
@export var emit_interval: float = 0.0 

# Time accumulator to control emission interval
var _time_accumulator: float = 0.0
var _anchors: Control.LayoutPreset = Control.LayoutPreset.PRESET_BOTTOM_LEFT

# Initialize and create joystick based on control model
func constract(_model: ControlModel)-> void:
	model = _model
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _model:
		_anchors = _model.anchors
	joystick = TouchScreenJoystick.new()
	add_child(joystick)
	
	resize(model.maxRect)
	if joystick and model:
		# Set joystick color
		joystick.color = model.primary_color

# Resize and position joystick
func resize(_size: Vector2i) -> void:
	model.maxRect = _size
	size= _size
	# Calculate joystick radius based on container dimensions
	var r = min(size.x,size.y)/2-10
	if r < 40:
		r = 40
	if r > 150:
		r=150

	joystick.base_radius = r
	joystick.knob_radius = r/2.5
	joystick.size = Vector2i(2*r+10,2*r+10)
	
	var margin = r + 50
	var new_pos = Vector2.ZERO

	# Position according to anchor
	match _anchors:
		Control.PRESET_BOTTOM_LEFT:
			new_pos = Vector2(margin, size.y - margin)
		Control.PRESET_BOTTOM_RIGHT:
			new_pos = Vector2(size.x - margin, size.y - margin)
		Control.PRESET_TOP_LEFT:
			new_pos = Vector2(margin, margin)
		Control.PRESET_TOP_RIGHT:
			new_pos = Vector2(size.x - margin, margin)
		_:
			new_pos = Vector2(size) / 2

	joystick.position = new_pos - (Vector2(joystick.size) / 2.0)

# Handle GUI input for clicks outside the joystick knob
func _gui_input(event: InputEvent) -> void:
	var is_click := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true

	if is_click:
		if joystick:
			if joystick.is_pressing or joystick.get_rect().has_point(event.position):
				return
		_emit_click_event()

# Helper method to emit click event
func _emit_click_event() -> void:
	if not model:
		return
	var args := JoystickEventArgs.new()
	args.direction = Vector2.ZERO
	args.force = 0.0
	args.delta_time = 0.0
	args.click = true
	player_input.emit(model.player_id, args)

# Transform input direction according to orientation towards screen center
func _get_center_oriented_direction(dir: Vector2) -> Vector2:
	match _anchors:
		Control.PRESET_BOTTOM_LEFT:
			return dir
		Control.PRESET_TOP_RIGHT:
			return -dir
		Control.PRESET_TOP_LEFT:
			return dir.rotated(PI / 2.0)
		Control.PRESET_BOTTOM_RIGHT:
			return dir.rotated(-PI / 2.0)
		_:
			return dir

# Physics tick for processing and emitting joystick input
func _physics_process(delta: float) -> void:
	# If joystick is not pressed, reset time accumulator
	if not joystick or not joystick.is_pressing:
		_time_accumulator = 0.0
		return
		
	_time_accumulator += delta
	
	# Emit input event when interval is reached
	if emit_interval <= 0.0 or _time_accumulator >= emit_interval:
		var dir: Vector2 = joystick.get_direction()
		var force: float = joystick.get_factor()
		
		var args := JoystickEventArgs.new()
		args.direction = _get_center_oriented_direction(dir)
		args.force = force
		args.delta_time = _time_accumulator
		args.click = false
		# Emit input signal for specific player
		player_input.emit(model.player_id,args)		
		_time_accumulator = 0.0
