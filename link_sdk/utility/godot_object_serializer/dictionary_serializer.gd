class_name DictionarySerializer

# List of base data types serialized to JSON without additional conversion
const _JSON_SERIALIZABLE_TYPES = [
	TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME
]

# Flag determining whether byte arrays (PackedByteArray) are serialized as base64 for compactness
static var bytes_as_base64 := true
# Type marker for base64-encoded byte arrays
static var bytes_to_base64_type := "PackedByteArray_Base64"

# Converts any Godot objects and data structures into JSON-compatible format (Dictionary/Array/base types)
static func serialize_var(value: Variant) -> Variant:
	match typeof(value):
		TYPE_OBJECT:
			var name: StringName = value.get_script().get_global_name()
			var object_entry := ObjectSerializer._get_entry(name, value.get_script())
			if !object_entry:
				assert(
					false,
					(
						"Failed to find type (%s) in serializer registry\n%s"
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

		TYPE_PACKED_BYTE_ARRAY:
			if bytes_as_base64:
				return {
					ObjectSerializer.type_field: bytes_to_base64_type,
					ObjectSerializer.args_field:
					Marshalls.raw_to_base64(value) if !value.is_empty() else ""
				}

	if _JSON_SERIALIZABLE_TYPES.has(typeof(value)):
		return value

	return {
		ObjectSerializer.type_field: type_string(typeof(value)),
		ObjectSerializer.args_field: JSON.from_native(value)["args"]
	}

# Serializes passed data directly into a JSON string
static func serialize_json(
	value: Variant, indent := "", sort_keys := true, full_precision := false
) -> String:
	return JSON.stringify(serialize_var(value), indent, sort_keys, full_precision)

# Restores Godot objects and structures from JSON-compatible format (Dictionary/Array)
static func deserialize_var(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			if value.has(ObjectSerializer.type_field):
				var type: String = value.get(ObjectSerializer.type_field)
				if bytes_as_base64 and type == bytes_to_base64_type:
					return Marshalls.base64_to_raw(value[ObjectSerializer.args_field])

				if type.begins_with(ObjectSerializer.object_type_prefix):
					var entry := ObjectSerializer._get_entry(type)
					if !entry:
						assert(false, "Failed to find type (%s) in registry" % type)
					return entry.deserialize(value, deserialize_var, true)

				return JSON.to_native({"type": type, "args": value[ObjectSerializer.args_field]})

			var result := {}
			for i: Variant in value:
				result[i] = deserialize_var(value[i])
			return result

		TYPE_ARRAY:
			return value.map(deserialize_var)

	return value

# Parses JSON string and deserializes it into internal Godot structures/objects
static func deserialize_json(value: String) -> Variant:
	return deserialize_var(JSON.parse_string(value))
