class_name DepthSortedStaticProp
extends StaticBody2D

@export var behind_player_z_index := 9
@export var neutral_z_index := 10
@export var in_front_of_player_z_index := 11

var _depth_reference: Node2D


func _ready() -> void:
	z_index = neutral_z_index


func _process(_delta: float) -> void:
	if not is_instance_valid(_depth_reference):
		z_index = neutral_z_index
		return
	update_depth_for_player(_depth_reference.global_position.y)


func set_depth_reference(avatar: Node2D) -> void:
	_depth_reference = avatar


func get_depth_reference() -> Node2D:
	return _depth_reference if is_instance_valid(_depth_reference) else null


func update_depth_for_player(player_global_y: float) -> void:
	z_index = in_front_of_player_z_index if player_global_y < global_position.y else behind_player_z_index
