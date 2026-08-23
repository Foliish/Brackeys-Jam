extends Node
class_name ControlModel

# Player ID to which this control model is bound.
var player_id: int = 0
# Primary color of player control elements.
var primary_color: Color = Color.AQUA
# Maximum size (resolution) of control area.
var maxRect: Vector2i = Vector2i(450,450)
# UI layout preset on screen (anchors).
var anchors: Control.LayoutPreset = Control.LayoutPreset.PRESET_BOTTOM_LEFT
