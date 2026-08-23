extends IMinigame

# Room model containing current game session data
var _room: RoomModel
# Progress of each player in the minigame
var _player_progress: Array[float]
# Minigame configuration
var config: Configs

# Initializes the minigame with starting parameters
func init(_params: StartParams) -> void:
	_room = _params.room
	# Connect player input signal to process actions
	_room.player_input.connect(_on_player_input)
	# Initialize progress array for each player
	for i in _room.players.size():
		_player_progress.append(0)
	config = Configs.get_config()
	
func _ready() -> void:
	# Set background color from configuration
	$ColorRect.color = config.color
			
# Finish minigame and calculate results
func stop() -> EndParams:
	var end_params = EndParams.new()
	var win_pts = float(config.winPoints)
	
	# Calculate scores based on players' accumulated progress
	for i in _room.players.size():
		var player = _room.players[i]
		var progress = _player_progress[i]
		var score = 0
		
		# Determine score based on progress thresholds
		if progress >= win_pts:
			score = 5
		elif progress >= win_pts * 0.8:
			score = 3
		elif progress >= win_pts * 0.6:
			score = 2
		elif progress >= win_pts * 0.4:
			score = 1
			
		end_params.results[player.id] = score
	
	return end_params

# Pause minigame (not supported)
func pause() -> bool:
	return false

# Resume minigame after pause (not supported)
func resume() -> bool:
	return false

# Handle player input (joystick movement)
func _on_player_input(player_id: int,args: JoystickEventArgs) -> void:
	# Update player progress based on joystick direction and force
	_player_progress[player_id] += (args.direction.x - args.direction.y) * args.force * args.delta_time
	# Check victory condition
	if _player_progress[player_id] >=config.winPoints:
		emit_signal("finished",self)
	_update_ui()

# Update UI displaying player progress
func _update_ui()->void:
	var il : ItemList = $ItemList
	il.clear()
	for i in _player_progress.size():
		il.add_item(str(i)+" => "+ str(_player_progress[i]))
