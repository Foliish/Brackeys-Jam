extends RefCounted
class_name PlayerModel

# Player index/ID in session
var id: int
# Primary display color for player
var color: Color
# Current player score
var score: int
# Results of played minigames
var minigame_results: Array[int] = []

static func _static_init() -> void:
	ObjectSerializer.register_script("PlayerModel", PlayerModel)
