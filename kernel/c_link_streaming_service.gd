class_name CLinkStreamingService
extends Node

## Singleton service module for connecting and communicating with streaming_service WebSocket server.
## Aggregates chat messages from Twitch, YouTube, Kick, and TikTok by stream links and manages subscriptions.
## Works as a self-contained singleton without needing Autoload configuration in project.godot.

# 1. Signals
## Emitted when WebSocket connection to streaming_service is established.
signal connected()

## Emitted when WebSocket connection is closed or disconnected.
signal disconnected()

## Emitted when connection attempt fails or network error occurs.
signal connection_failed(reason: String)

## Emitted when a new unified chat message is received and parsed.
signal message_received(message: CLinkChatMessage)

## Emitted when a stream subscription is confirmed by the server.
signal subscribed(platform: String, channel: String, active_listeners: int)

## Emitted when a stream subscription is confirmed by the server, including matched stream URL.
signal stream_subscribed(stream_url: String, platform: String, channel: String, active_listeners: int)

## Emitted when a stream unsubscription is confirmed by the server.
signal unsubscribed(platform: String, channel: String, remaining_listeners: int)

## Emitted when a stream unsubscription is confirmed by the server, including matched stream URL.
signal stream_unsubscribed(stream_url: String, platform: String, channel: String, remaining_listeners: int)

## Emitted when server responds to a ping with pong.
signal pong_received()

## Emitted when any raw JSON payload is received from the server.
signal raw_json_received(data: Dictionary)

## Emitted when the connection state changes.
signal state_changed(new_state: ConnectionState)


# 2. Enums and Constants
enum ConnectionState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	RECONNECTING
}

const DEFAULT_SERVER_URL: String = "ws://localhost:8000/ws"
const DEFAULT_HEARTBEAT_INTERVAL: float = 25.0
const DEFAULT_RECONNECT_DELAY: float = 3.0


# 3. Exported variables (@export)
@export var server_url: String = DEFAULT_SERVER_URL
@export var auto_reconnect: bool = true
@export var reconnect_delay: float = DEFAULT_RECONNECT_DELAY
@export var auto_resubscribe: bool = true
@export var heartbeat_enabled: bool = true
@export var heartbeat_interval: float = DEFAULT_HEARTBEAT_INTERVAL


# 4. Public variables
var current_state: ConnectionState = ConnectionState.DISCONNECTED


# 5. Private variables
static var _instance: CLinkStreamingService = null

var _ws_peer: WebSocketPeer = WebSocketPeer.new()
var _active_subscriptions: Dictionary = {}
var _heartbeat_timer: float = 0.0
var _reconnect_timer: float = 0.0
var _should_reconnect: bool = false
var _previous_state: ConnectionState = ConnectionState.DISCONNECTED


# 6. Onready variables


# 7. Built-in virtual methods
func _enter_tree() -> void:
	if _instance == null:
		_instance = self


func _ready() -> void:
	if _instance == null:
		_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null
	disconnect_from_service()


func _process(delta: float) -> void:
	_poll_websocket(delta)
	_process_timers(delta)


# 8. Public methods

## Returns the global singleton instance.
## Automatically instantiates and attaches to scene tree root if not present.
static func get_instance() -> CLinkStreamingService:
	if not is_instance_valid(_instance):
		_instance = CLinkStreamingService.new()
		_instance.name = "CLinkStreamingService"
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			tree.root.call_deferred("add_child", _instance)
		else:
			push_error("[CLinkStreamingService] Failed to access SceneTree root for auto-parenting.")
	return _instance


## Connects to the streaming_service WebSocket server.
## [param url]: Optional WebSocket URL (defaults to server_url or ws://localhost:8000/ws).
func connect_to_service(url: String = "") -> Error:
	if not url.is_empty():
		server_url = url

	if server_url.is_empty():
		server_url = DEFAULT_SERVER_URL

	if is_connected_to_service():
		print("[CLinkStreamingService] Already connected to %s" % server_url)
		return OK

	_should_reconnect = auto_reconnect
	_set_state(ConnectionState.CONNECTING)

	_ws_peer = WebSocketPeer.new()
	var err: Error = _ws_peer.connect_to_url(server_url)
	if err != OK:
		push_error("[CLinkStreamingService] Failed to initiate connection to %s. Error: %d" % [server_url, err])
		_set_state(ConnectionState.DISCONNECTED)
		connection_failed.emit("Failed to connect to %s (Error code: %d)" % [server_url, err])
		_trigger_reconnect()
		return err

	print("[CLinkStreamingService] Connecting to %s..." % server_url)
	return OK


## Disconnects from the WebSocket server.
func disconnect_from_service(close_code: int = 1000, reason: String = "") -> void:
	_should_reconnect = false
	_reconnect_timer = 0.0

	if _ws_peer != null and _ws_peer.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws_peer.close(close_code, reason)

	_set_state(ConnectionState.DISCONNECTED)


## Returns true if currently connected to the server.
func is_connected_to_service() -> bool:
	return _ws_peer != null and _ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN


## Subscribes to a stream chat using a direct stream link.
## Supported platforms: Twitch, YouTube, Kick, TikTok.
## Example: "https://twitch.tv/shroud", "https://kick.com/xqc", "https://www.youtube.com/watch?v=..."
func subscribe(stream_url: String) -> bool:
	var clean_url := stream_url.strip_edges()
	if clean_url.is_empty():
		push_warning("[CLinkStreamingService] Invalid stream URL for subscribe.")
		return false

	_active_subscriptions[clean_url] = clean_url

	var payload: Dictionary = {
		"action": "subscribe",
		"channel": clean_url
	}

	return send_json(payload)


## Unsubscribes from a stream chat using the stream link.
func unsubscribe(stream_url: String) -> bool:
	var clean_url := stream_url.strip_edges()
	if clean_url.is_empty():
		push_warning("[CLinkStreamingService] Invalid stream URL for unsubscribe.")
		return false

	_active_subscriptions.erase(clean_url)

	var payload: Dictionary = {
		"action": "unsubscribe",
		"channel": clean_url
	}

	return send_json(payload)


## Sends a ping packet to check connection vitality.
func send_ping() -> bool:
	return send_json({"action": "ping"})


## Sends a JSON payload dictionary over the WebSocket connection.
func send_json(payload: Dictionary) -> bool:
	if not is_connected_to_service():
		push_warning("[CLinkStreamingService] Cannot send JSON payload: Not connected.")
		return false

	var json_str: String = JSON.stringify(payload)
	var err: Error = _ws_peer.send_text(json_str)
	if err != OK:
		push_error("[CLinkStreamingService] Error sending WebSocket packet: %d" % err)
		return false

	return true


## Returns an array of active stream subscription URLs.
func get_subscriptions() -> Array[String]:
	var result: Array[String] = []
	for url: String in _active_subscriptions:
		result.append(url)
	return result


## Returns true if currently subscribed to a specific stream link.
func is_subscribed(stream_url: String) -> bool:
	var clean_url := stream_url.strip_edges()
	return _active_subscriptions.has(clean_url)


## Searches active subscriptions for a URL matching given platform and/or channel name.
func find_url_by_channel(platform: String, channel: String) -> String:
	var chan_lower := channel.to_lower()
	var plat_lower := platform.to_lower()

	for url: String in _active_subscriptions:
		var url_lower := url.to_lower()
		if not chan_lower.is_empty() and url_lower.contains(chan_lower):
			return url

	for url: String in _active_subscriptions:
		var url_lower := url.to_lower()
		if not plat_lower.is_empty() and url_lower.contains(plat_lower):
			return url

	return ""


# Static Conveniences for clean one-line access:

## Connects to service via static call.
static func listen(url: String = "") -> Error:
	return get_instance().connect_to_service(url)

## Disconnects service via static call.
static func stop() -> void:
	if is_instance_valid(_instance):
		_instance.disconnect_from_service()

## Subscribes to stream link via static call.
static func sub(stream_url: String) -> bool:
	return get_instance().subscribe(stream_url)

## Unsubscribes from stream link via static call.
static func unsub(stream_url: String) -> bool:
	return get_instance().unsubscribe(stream_url)


# 9. Private methods & Signal Handlers

func _set_state(new_state: ConnectionState) -> void:
	if current_state != new_state:
		_previous_state = current_state
		current_state = new_state
		state_changed.emit(current_state)


func _poll_websocket(_delta: float) -> void:
	if _ws_peer == null:
		return

	_ws_peer.poll()
	var state: WebSocketPeer.State = _ws_peer.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if current_state != ConnectionState.CONNECTED:
				var was_reconnecting: bool = (current_state == ConnectionState.RECONNECTING)
				_set_state(ConnectionState.CONNECTED)
				_heartbeat_timer = 0.0
				_reconnect_timer = 0.0
				print("[CLinkStreamingService] WebSocket connected successfully.")
				connected.emit()

				if (was_reconnecting or auto_resubscribe) and not _active_subscriptions.is_empty():
					_resubscribe_all()

		WebSocketPeer.STATE_CLOSED:
			if current_state == ConnectionState.CONNECTED or current_state == ConnectionState.CONNECTING:
				var code: int = _ws_peer.get_close_code()
				var reason: String = _ws_peer.get_close_reason()
				print("[CLinkStreamingService] WebSocket closed. Code: %d, Reason: '%s'" % [code, reason])
				_set_state(ConnectionState.DISCONNECTED)
				disconnected.emit()

				if _should_reconnect:
					_trigger_reconnect()

		WebSocketPeer.STATE_CONNECTING:
			if current_state != ConnectionState.CONNECTING and current_state != ConnectionState.RECONNECTING:
				_set_state(ConnectionState.CONNECTING)

	# Read incoming packets
	while _ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN and _ws_peer.get_available_packet_count() > 0:
		var packet: PackedByteArray = _ws_peer.get_packet()
		var is_string: bool = _ws_peer.was_string_packet()
		if is_string:
			var packet_text: String = packet.get_string_from_utf8()
			_parse_and_handle_packet(packet_text)


func _parse_and_handle_packet(raw_text: String) -> void:
	if raw_text.is_empty():
		return

	var json := JSON.new()
	var err: Error = json.parse(raw_text)
	if err != OK:
		push_warning("[CLinkStreamingService] Failed to parse JSON packet: %s" % raw_text)
		return

	if not (json.data is Dictionary):
		return

	var data: Dictionary = json.data
	raw_json_received.emit(data)

	# 1. Check for subscription response
	if data.get("status") == "subscribed":
		var plat: String = str(data.get("platform", ""))
		var chan: String = str(data.get("channel", ""))
		var listeners: int = int(data.get("active_listeners", 0))
		var matched_url: String = find_url_by_channel(plat, chan)
		subscribed.emit(plat, chan, listeners)
		stream_subscribed.emit(matched_url, plat, chan, listeners)
		return

	# 2. Check for unsubscription response
	if data.get("status") == "unsubscribed":
		var plat: String = str(data.get("platform", ""))
		var chan: String = str(data.get("channel", ""))
		var remaining: int = int(data.get("remaining_listeners", 0))
		var matched_url: String = find_url_by_channel(plat, chan)
		unsubscribed.emit(plat, chan, remaining)
		stream_unsubscribed.emit(matched_url, plat, chan, remaining)
		return

	# 3. Check for pong response
	if data.get("type") == "pong":
		pong_received.emit()
		return

	# 4. Check for UnifiedChatMessage payload
	if data.has("author") or data.has("content") or data.has("id"):
		var message: CLinkChatMessage = CLinkChatMessage.from_dict(data)
		message_received.emit(message)
		return


func _process_timers(delta: float) -> void:
	# Heartbeat timer
	if heartbeat_enabled and is_connected_to_service() and heartbeat_interval > 0.0:
		_heartbeat_timer += delta
		if _heartbeat_timer >= heartbeat_interval:
			_heartbeat_timer = 0.0
			send_ping()

	# Reconnect timer
	if current_state == ConnectionState.RECONNECTING:
		_reconnect_timer += delta
		if _reconnect_timer >= reconnect_delay:
			_reconnect_timer = 0.0
			print("[CLinkStreamingService] Attempting reconnection...")
			connect_to_service()


func _trigger_reconnect() -> void:
	if not auto_reconnect:
		return
	_set_state(ConnectionState.RECONNECTING)
	_reconnect_timer = 0.0
	print("[CLinkStreamingService] Scheduling reconnection in %.1f seconds..." % reconnect_delay)


func _resubscribe_all() -> void:
	print("[CLinkStreamingService] Resubscribing to %d stream links..." % _active_subscriptions.size())
	for stream_url: String in _active_subscriptions:
		subscribe(stream_url)
