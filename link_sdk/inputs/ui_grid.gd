extends Control
class_name DemoUiGrid

var grid: GridContainer
var cells: Dictionary = {}
const anchors_map: Dictionary[int, Control.LayoutPreset] = {
	0 : Control.LayoutPreset.PRESET_BOTTOM_LEFT,
	1 : Control.LayoutPreset.PRESET_TOP_RIGHT,
	2 : Control.LayoutPreset.PRESET_TOP_LEFT,
	3 : Control.LayoutPreset.PRESET_BOTTOM_RIGHT
}

# Signal to forward player input
signal player_input(player_id: int, args: IEventArguments)

# Subscribe to viewport size changes
func _ready() -> void:
	if is_inside_tree():
		get_viewport().size_changed.connect(_on_resized)
	_on_resized()

# Initialize grid and stretch across full screen
func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_custom_grid()

# Create 2-column GridContainer and add 4 cells (slots) in specific order
func _build_custom_grid() -> void:
	grid = GridContainer.new()
	grid.columns = 2
	grid.set_anchors_preset(PRESET_FULL_RECT)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)

	_create_slot(2)
	_create_slot(1)
	_create_slot(0)
	_create_slot(3)

# Create MarginContainer for a specific cell
func _create_slot(cell_id: int) -> void:
	var slot: MarginContainer = MarginContainer.new()

	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_child(slot)
	cells[cell_id] = slot

# Add a platform control to the specified grid cell
func add_platform_control_scene(control_scene: PackedScene, model: ControlModel, cell_id: int) -> PlatformControl:
	if not cells.has(cell_id):
		push_error("Error: Cell number %d does not exist!" % cell_id)
		return null

	if not control_scene:
		push_error("Error: Provided scene (PackedScene) is null!")
		return null

	var instance: Node = control_scene.instantiate()

	if not instance is PlatformControl:
		push_error("Error: Root node of scene does not inherit PlatformControl!")
		instance.queue_free() 
		return null

	var target_slot: MarginContainer = cells[cell_id]	
	var platform_control: PlatformControl = instance as PlatformControl

	# Forward input signal upwards
	platform_control.player_input.connect(player_input.emit)

	# Configure control model (max rect and anchors)
	model.maxRect = target_slot.size
	model.anchors = anchors_map[cell_id]
	platform_control.constract(model)

	target_slot.add_child(platform_control)

	return platform_control

# Completely clears the specified cell
func clear_cell(cell_id: int) -> void:
	if cells.has(cell_id):
		var target_slot: MarginContainer = cells[cell_id]
		for child: Node in target_slot.get_children():
			target_slot.remove_child(child)
			child.queue_free()

# Resize handler waiting for layout update
func _on_resized() -> void:
	if not grid:
		return

	# Wait for frame rendering to obtain valid cell sizes
	if is_inside_tree():
		var attempts := 0
		while attempts < 10:
			await get_tree().process_frame
			var has_size := true
			for cid in cells:
				if cells[cid].size.x <= 0 or cells[cid].size.y <= 0:
					has_size = false
					break
			if has_size:
				break
			attempts += 1

	# Call resize for child controls in cells
	for cell_id: int in cells:
		var slot: MarginContainer = cells[cell_id]
		var new_size: Vector2i = Vector2i(slot.size)

		if new_size.x <= 0 or new_size.y <= 0:
			continue

		for child: Node in slot.get_children():
			if child.has_method("resize"):
				child.resize(new_size)
