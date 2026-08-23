@icon("res://link_sdk/assets/touch_screen_joystick/icon.png")
extends Control
class_name TouchScreenJoystick

# Whether to use antialiasing when drawing the joystick
@export var antialiased : bool = false : 
	set(b):
		antialiased = b
		queue_redraw()

# Deadzone size in pixels
@export_range(0, 9999, 0.1, "hide_slider")
var deadzone : float= 25.0 : 
	set(n):
		deadzone = n
		queue_redraw()

# Joystick base radius and maximum stick displacement
@export_range(0, 9999, 0.1, "hide_slider")
var base_radius : float = 120.0 :
	set(value):
		base_radius = value
		queue_redraw()

# Joystick knob radius
@export_range(0, 9999, 0.1, "hide_slider")
var knob_radius : float = 45.0 :
	set(value):
		knob_radius = value
		queue_redraw()

@export_group("Texture Joystick")
# Whether to use graphic textures instead of standard circles
@export var use_textures : bool = false :
	set(value):
		use_textures = value
		queue_redraw()

@export_subgroup("Base")
# Joystick base texture
@export var base_texture : Texture2D :
	set(value):
		base_texture = value
		queue_redraw()

# Base texture scale
@export var base_scale : Vector2 = Vector2.ONE :
	set(value):
		base_scale = value
		queue_redraw()

@export_subgroup("Knob")
# Joystick knob texture
@export var knob_texture : Texture2D :
	set(value):
		knob_texture = value
		queue_redraw()

# Knob texture scale
@export var knob_scale : Vector2 = Vector2.ONE :
	set(value):
		knob_scale = value
		queue_redraw()

@export_group("Style")
# Primary color for drawing flat circles
@export var color : Color = Color.WHITE :
	set(value):
		color = value
		queue_redraw()

# Base background color
@export var back_color : Color = Color(Color.BLACK, 0.5):
	set(value):
		back_color = value
		queue_redraw()

# Base outline thickness
@export_range(0, 999, 0.1, "hide_slider")
var thickness := 3.0 :
	set(value):
		thickness = value
		queue_redraw()

@export_group("Input Actions")
# Enable emulation of standard Godot Input Actions
@export var use_input_actions : bool
# Godot input action for left direction
@export var action_left : StringName = "ui_left"
# Godot input action for right direction
@export var action_right : StringName = "ui_right"
# Godot input action for up direction
@export var action_up : StringName = "ui_up"
# Godot input action for down direction
@export var action_down : StringName = "ui_down"

@export_group("Debug")
# Whether to draw debug boundaries for deadzone and base
@export var show_debug : bool :
	set(value):
		show_debug = value
		queue_redraw()

# Deadzone color in debug mode
@export var deadzone_debug_color : Color = Color.RED :
	set(value):
		deadzone_debug_color = value
		queue_redraw()

# Base color in debug mode
@export var base_debug_color : Color = Color.GREEN :
	set(value):
		base_debug_color = value
		queue_redraw()

signal on_press
signal on_release
signal on_drag(factor : float)

# Current draw coordinates for the knob
var knob_position : Vector2
# Whether the joystick is currently pressed
var is_pressing : bool
# Screen touch index for multitouch
var event_index : int = -1

func _draw() -> void:
	if not is_pressing : reset_knob()
	
	if not use_textures:
		draw_default_joystick()
	else:
		draw_texture_joystick()
	
	if show_debug : draw_debug()

# Draw default joystick geometry (without textures)
func draw_default_joystick() -> void:
	draw_circle(size / 2.0, base_radius, back_color)
	draw_circle(size / 2.0, base_radius, color, false, thickness, antialiased)
	draw_circle(knob_position, knob_radius, color, true, -1.0, antialiased)

# Draw joystick using assigned textures
func draw_texture_joystick() -> void:
	if base_texture:
		var base_size := base_texture.get_size() * base_scale
		draw_texture_rect(base_texture, Rect2(size / 2.0 - (base_size / 2.0), base_size), false)
		
	if knob_texture:
		var knob_size := knob_texture.get_size() * knob_scale
		draw_texture_rect(knob_texture, Rect2(knob_position - (knob_size / 2.0), knob_size), false)

# Draw debug outlines for deadzone and base radius
func draw_debug() -> void:
	draw_circle(size / 2.0, deadzone, deadzone_debug_color, false, 5.0)
	draw_circle(size / 2.0, base_radius, base_debug_color, false, 5.0)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		on_screen_touch(event)
	elif event is InputEventScreenDrag:
		on_screen_drag(event)

# Handler for screen touch press/release
func on_screen_touch(event : InputEventScreenTouch) -> void:
	var has_point := get_global_rect().has_point(event.position)
	
	if event.pressed and event_index == -1 and has_point:
		event_index = event.index
		touch_knob(event.position, event.index)
	else:
		release_knob(event.index)

# Moves knob to touch position and activates pressed state
func touch_knob(pos : Vector2, index : int) -> void:
	if index == event_index: 
		move_knob(pos)
		is_pressing = true
		on_press.emit()
		get_viewport().set_input_as_handled()

# Resets joystick state upon release
func release_knob(index : int) -> void:
	if index == event_index:
		reset_actions()
		reset_knob()
		event_index = -1
		is_pressing = false
		on_release.emit()
		get_viewport().set_input_as_handled()

# Handler for finger drag across the screen
func on_screen_drag(event : InputEventScreenDrag) -> void:
	if event.index == event_index and is_pressing:
		move_knob(event.position)
		get_viewport().set_input_as_handled()
		on_drag.emit(get_factor())

# Calculates new knob position relative to center and handles deadzone
func move_knob(event_pos : Vector2) -> void:
	var center := size / 2.0
	var touch_pos := (event_pos - global_position) / scale
	var distance := touch_pos.distance_to(center)
	var angle := center.angle_to_point(touch_pos)
	
	if distance < base_radius:
		knob_position = touch_pos
	else:
		knob_position.x = center.x + cos(angle) * base_radius
		knob_position.y = center.y + sin(angle) * base_radius
	
	if distance > deadzone:
		trigger_actions()
	else:
		reset_actions()
	
	queue_redraw()

# Emulates directional key presses in the Godot input system
func trigger_actions() -> void:
	if not use_input_actions: return
	
	var direction := get_direction().normalized()
	
	if direction.x < 0.0:
		Input.action_release(action_right)
		Input.action_press(action_left, -direction.x)
	elif direction.x > 0.0:
		Input.action_release(action_left)
		Input.action_press(action_right, direction.x)
	
	if direction.y < 0.0:
		Input.action_release(action_down)
		Input.action_press(action_up, -direction.y)
	elif direction.y > 0.0:
		Input.action_release(action_up)
		Input.action_press(action_down, direction.y)

# Resets the state of all emulated input actions
func reset_actions() -> void:
	Input.action_release(action_left)
	Input.action_release(action_right)
	Input.action_release(action_up)
	Input.action_release(action_down)

# Returns normalized direction vector from center to knob
func get_direction() -> Vector2:
	var center := size / 2.0
	var direction := center.direction_to(knob_position)
	return direction

# Returns distance from center to knob
func get_distance() -> float:
	var center := size / 2.0
	var distance := center.distance_to(knob_position)
	return distance

# Returns knob deflection angle in radians
func get_angle() -> float:
	var center := size / 2.0
	var angle := center.angle_to_point(knob_position)
	return angle

# Returns knob deflection factor from center (from 0.0 to 1.0)
func get_factor() -> float:
	var center := size / 2.0
	var distance := center.distance_to(knob_position)
	return distance / base_radius

# Checks if knob is inside the deadzone
func is_in_deadzone() -> bool:
	var center := size / 2.0
	var distance := center.distance_to(knob_position)
	return distance < deadzone

# Resets knob position back to center of base
func reset_knob() -> void:
	knob_position = size / 2.0
	queue_redraw()
