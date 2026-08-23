class_name CLinkChatAdapter
extends Node

## Chat adapter node bridging high-level chat events with CLinkStreamingService.
signal message_received(message: CLinkChatMessage)

static var instance: CLinkChatAdapter = null

static func get_instance() -> CLinkChatAdapter:
	if not is_instance_valid(instance):
		instance = CLinkChatAdapter.new()
		instance.name = "CLinkChatAdapter"
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			tree.root.call_deferred("add_child", instance)
	return instance
