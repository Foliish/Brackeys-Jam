extends IMinigame

# Модель комнаты, содержащая данные о текущей игровой сессии
var _room: RoomModel
# Прогресс каждого игрока в мини-игре
var _player_progress: Array[float]
# Конфигурация мини-игры
var config: Configs

# Инициализация мини-игры с начальными параметрами
func init(_params: StartParams) -> void:
	_room = _params.room
	# Подключение сигнала ввода игрока для обработки действий
	_room.player_input.connect(_on_player_input)
	# Инициализация массива прогресса для каждого игрока
	for i in _room.players.size():
		_player_progress.append(0)
	config = Configs.get_config()
	
func _ready() -> void:
	# Установка цвета фона из конфигурации
	$ColorRect.color = config.color
			
# Завершение мини-игры и расчет результатов
func stop() -> EndParams:
	var end_params = EndParams.new()
	var win_pts = float(config.winPoints)
	
	# Расчет очков на основе набранного прогресса игроков
	for i in _room.players.size():
		var player = _room.players[i]
		var progress = _player_progress[i]
		var score = 0
		
		# Определение очков по порогам прогресса
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

# Приостановка мини-игры (не поддерживается)
func pause() -> bool:
	return false

# Возобновление мини-игры после паузы (не поддерживается)
func resume() -> bool:
	return false

# Обработка ввода от игрока (движение джойстика)
func _on_player_input(player_id: int,args: JoystickEventArgs) -> void:
	# Изменение прогресса игрока на основе направления и силы отклонения джойстика
	_player_progress[player_id] += (args.direction.x - args.direction.y) * args.force * args.delta_time
	# Проверка условия победы
	if _player_progress[player_id] >=config.winPoints:
		emit_signal("finished",self)
	_update_ui()

# Обновление пользовательского интерфейса с отображением прогресса игроков
func _update_ui()->void:
	var il : ItemList = $ItemList
	il.clear()
	for i in _player_progress.size():
		il.add_item(str(i)+" => "+ str(_player_progress[i]))
