class_name ENetNetworkManager
extends NetworkAdapter

## Singleton network manager for ENet multiplayer connections and RPC messaging.
## Instance is created via start_server() or connect_to_server(), and destroyed via stop().

# Network state tracking signals
signal server_started(port: int)
signal server_stopped()

signal connecting()
signal connected_to_server()
signal connection_failed()
signal disconnected_from_server()

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

# Maximum player count and default port
const MAX_USERS := 5
const DEFAULT_PORT := 7631
const BASE36_CHARS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

static var _instance: ENetNetworkManager = null

var peer: ENetMultiplayerPeer
var _handlers := {} # Dictionary mapping message type to list of handler functions (Dictionary[String, Array[Callable]])


## Returns the current singleton instance or null if the server/client is not running.
static func get_instance() -> ENetNetworkManager:
	if is_instance_valid(_instance):
		return _instance
	return null


# Starts the server on the specified port (creates singleton instance)
static func start_server(port: int = DEFAULT_PORT) -> bool:
	if is_instance_valid(_instance):
		_instance._stop_internal()

	var inst := ENetNetworkManager.new()
	inst.name = "ENetNetworkManager"
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(inst)
	else:
		push_error("[ENetNetworkManager] Failed to access SceneTree root.")
		return false

	_instance = inst
	return inst._start_server_internal(port)


# Connects to the server using IP address and port (creates singleton instance)
static func connect_to_server(ip: String, port: int) -> bool:
	if is_instance_valid(_instance):
		_instance._stop_internal()

	var inst := ENetNetworkManager.new()
	inst.name = "ENetNetworkManager"
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.add_child(inst)
	else:
		push_error("[ENetNetworkManager] Failed to access SceneTree root.")
		return false

	_instance = inst
	return inst._connect_to_server_internal(ip, port)


# Stops the server or network connection and destroys instance
static func stop() -> void:
	if is_instance_valid(_instance):
		_instance._stop_internal()


func _start_server_internal(port: int) -> bool:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_USERS)

	if err != OK:
		push_error("Failed to start server")
		_stop_internal()
		return false

	multiplayer.multiplayer_peer = peer
	_register_multiplayer_signals()

	server_started.emit(port)
	print("[NET] Server started on port: ", port)
	return true


func _connect_to_server_internal(ip: String, port: int) -> bool:
	connecting.emit()

	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)

	if err != OK:
		push_error("Failed to connect to server")
		connection_failed.emit()
		_stop_internal()
		return false

	multiplayer.multiplayer_peer = peer
	_register_multiplayer_signals()
	return true


func _stop_internal() -> void:
	if multiplayer and multiplayer.multiplayer_peer:
		_unregister_multiplayer_signals()
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_handlers.clear()
	server_stopped.emit()

	if _instance == self:
		_instance = null

	queue_free()


# Finds the best local IP address for creating a connection
static func get_my_best_ip() -> String:
	var candidates := []

	for ip in IP.get_local_addresses():
		if ":" in ip:
			continue
		if ip.begins_with("127."):
			continue
		candidates.append(ip)

	for prefix in ["192.168.", "10.", "172."]:
		for ip in candidates:
			if ip.begins_with(prefix):
				return ip

	return candidates[0] if candidates.size() > 0 else "127.0.0.1"


# Encodes an IP address into a 7-character alphanumeric Base36 code
static func encode_ip_to_base36(ip_address: String) -> String:
	var parts = ip_address.split(".")
	if parts.size() != 4:
		push_error("Invalid IP address format")
		return ""
		
	# Pack four bytes of IP address into a single integer
	var ip_int : int = (int(parts[0]) << 24) | (int(parts[1]) << 16) | (int(parts[2]) << 8) | int(parts[3])
	
	if ip_int == 0:
		return "0000000"
		
	# Convert packed integer to Base36 string
	var base36 = ""
	while ip_int > 0:
		var remainder = ip_int % 36
		base36 = BASE36_CHARS[remainder] + base36
		ip_int = ip_int / 36
		
	# Left-pad string with zeros to reach length of 7 characters
	return base36.lpad(7, "0")


# Decodes a 7-character Base36 code back to an IP address string
static func decode_base36_to_ip(base36_code: String) -> String:
	var cleaned = base36_code.strip_edges().to_upper()
	
	# Left-pad with zeros for correct parsing if code is shorter than 7 characters
	cleaned = cleaned.lpad(7, "0")
	
	if cleaned.length() != 7:
		push_error("Invalid lobby code length")
		return ""
		
	var ip_int : int = 0
	
	for i in range(cleaned.length()):
		var current_char = cleaned[i]
		var value = BASE36_CHARS.find(current_char)
		
		if value == -1:
			push_error("Invalid character in lobby code: " + current_char)
			return ""
			
		ip_int = (ip_int * 36) + value
		
	# Extract individual bytes of IP address from integer
	var b0 = (ip_int >> 24) & 255
	var b1 = (ip_int >> 16) & 255
	var b2 = (ip_int >> 8) & 255
	var b3 = ip_int & 255
	
	return "%d.%d.%d.%d" % [b0, b1, b2, b3]


# Returns true if current instance is server
func is_server() -> bool:
	return multiplayer.is_server()


# Returns unique network peer ID
func my_peer_id() -> int:
	return multiplayer.get_unique_id()


# Sends a network message (reliable or unreliable) to a specified peer or all
func send_message(msg_type: String, data: Variant, target_peer: int = -1, reliable: bool = true) -> void:
	if reliable:
		_send_reliable(msg_type, data, target_peer)
	else:
		_send_unreliable(msg_type, data, target_peer)


# Send reliable message
func _send_reliable(msg_type: String, data: Variant, target_peer: int) -> void:
	if target_peer == -1:
		_receive_message_reliable.rpc(msg_type, data)
	else:
		_receive_message_reliable.rpc_id(target_peer, msg_type, data)


# Send unreliable message
func _send_unreliable(msg_type: String, data: Variant, target_peer: int) -> void:
	if target_peer == -1:
		_receive_message_unreliable.rpc(msg_type, data)
	else:
		_receive_message_unreliable.rpc_id(target_peer, msg_type, data)


# Register incoming message handler for a specific message type
func register_handler(msg_type: String, handler: Callable) -> void:
	if not _handlers.has(msg_type):
		_handlers[msg_type] = []
	_handlers[msg_type].append(handler)


# Remove incoming message handler for a specific message type
func unregister_handler(msg_type: String, handler: Callable) -> void:
	if _handlers.has(msg_type):
		_handlers[msg_type].erase(handler)


# Remote procedure call (RPC) to handle reliable message
@rpc("any_peer", "reliable")
func _receive_message_reliable(msg_type: String, data: Variant) -> void:
	_dispatch_message(multiplayer.get_remote_sender_id(), msg_type, data, true)


# Remote procedure call (RPC) to handle unreliable message
@rpc("any_peer", "unreliable")
func _receive_message_unreliable(msg_type: String, data: Variant) -> void:
	_dispatch_message(multiplayer.get_remote_sender_id(), msg_type, data, false)


# Dispatch incoming message to registered handlers
func _dispatch_message(sender_peer_id: int, msg_type: String, data: Variant, reliable: bool) -> void:
	if _handlers.has(msg_type):
		for handler: Callable in _handlers[msg_type]:
			handler.call(sender_peer_id, data)


# Connect to Godot multiplayer system signals
func _register_multiplayer_signals():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# Disconnect from Godot multiplayer system signals
func _unregister_multiplayer_signals():
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.disconnect(_on_connected)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)


# Called when a new peer connects
func _on_peer_connected(id: int):
	print("[NET] Peer connected with ID: ", id)
	peer_connected.emit(id)


# Called when a peer disconnects
func _on_peer_disconnected(id: int):
	print("[NET] Peer disconnected with ID: ", id)
	peer_disconnected.emit(id)


# Called on client when connection to server succeeds
func _on_connected():
	print("[NET] Connection to server successfully established")
	connected_to_server.emit()


# Called on client when connection to server fails
func _on_connection_failed():
	push_error("[NET] Failed to connect to server")
	connection_failed.emit()


# Called when disconnected from server
func _on_server_disconnected():
	print("[NET] Disconnected from server")
	disconnected_from_server.emit()
