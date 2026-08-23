class_name NetworkAdapter
extends Node

## Network adapter interface for minigames.
## Provides methods and signals for sending and receiving data without transport implementation.

# Returns true if current node is server (host)
func is_server() -> bool:
	push_error("Not implemented")
	return false


# Returns unique network peer ID
func my_peer_id() -> int:
	push_error("Not implemented")
	return 1


# Register incoming message handler for a specific message type
func register_handler(_msg_type: String, _handler: Callable) -> void:
	push_error("Not implemented")


# Remove incoming message handler for a specific message type
func unregister_handler(_msg_type: String, _handler: Callable) -> void:
	push_error("Not implemented")


# Sends a network message (reliable or unreliable) to a specified peer or all (-1)
func send_message(_msg_type: String, _data: Variant, _target_peer: int = -1, _reliable: bool = true) -> void:
	push_error("Not implemented")
