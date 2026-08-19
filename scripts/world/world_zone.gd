class_name WorldZone
extends Node2D

@export var camera_bounds := Rect2i()


func get_entry_position(entry_id: StringName) -> Vector2:
	var entry_point := get_node_or_null("EntryPoints/%s" % entry_id) as Marker2D
	if entry_point == null:
		push_error("Zone '%s' has no entry point named '%s'." % [name, entry_id])
		return Vector2.ZERO

	return entry_point.position
