# Serializer for use with Godot's built-in binary serialization (var_to_bytes and bytes_to_var).
# Serializes custom objects while leaving built-in Godot data types unchanged.
class_name BinarySerializer


# Serializes the passed value (Variant) into a format that can be processed by var_to_bytes
static func serialize_var(value: Variant) -> Variant:
	match typeof(value):
		TYPE_OBJECT:
			var name: StringName = value.get_script().get_global_name()
			var object_entry := ObjectSerializer._get_entry(name, value.get_script())
			if !object_entry:
				assert(
					false,
					(
						"Failed to find type (%s) in registry\n%s"
						% [name if name else "unnamed", value.get_script().source_code]
					)
				)

			return object_entry.serialize(value, serialize_var)
		TYPE_ARRAY:
			return value.map(serialize_var)
		TYPE_DICTIONARY:
			var result := {}
			for i: Variant in value:
				result[i] = serialize_var(value[i])
			return result

	return value


# Serializes data into a byte array (PackedByteArray) using serialize_var and var_to_bytes
static func serialize_bytes(value: Variant) -> PackedByteArray:
	return var_to_bytes(serialize_var(value))


# Deserializes value from the format obtained after bytes_to_var call
static func deserialize_var(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			if value.has(ObjectSerializer.type_field):
				var type: String = value.get(ObjectSerializer.type_field)
				if type.begins_with(ObjectSerializer.object_type_prefix):
					var entry := ObjectSerializer._get_entry(type)
					if !entry:
						assert(false, "Failed to find type (%s) in registry" % type)

					return entry.deserialize(value, deserialize_var)

			var result := {}
			for i: Variant in value:
				result[i] = deserialize_var(value[i])
			return result
		TYPE_ARRAY:
			return value.map(deserialize_var)

	return value


# Deserializes byte array into original object or data structure using bytes_to_var and deserialize_var
static func deserialize_bytes(value: PackedByteArray) -> Variant:
	return deserialize_var(bytes_to_var(value))
