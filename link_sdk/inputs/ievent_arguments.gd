extends RefCounted
class_name IEventArguments

# Register class in serializer upon type initialization
static func _static_init() -> void:
	ObjectSerializer.register_script("IEventArguments", IEventArguments)
