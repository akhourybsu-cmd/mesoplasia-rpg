class_name DepthSortedStaticProp
extends StaticBody2D

@export var player_group: StringName = &"player"
@export var behind_player_z_index := 9
@export var neutral_z_index := 10
@export var in_front_of_player_z_index := 11

var _player: Node2D


func _ready() -> void:
	z_index = neutral_z_index


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D
	if _player == null:
		z_index = neutral_z_index
		return
	update_depth_for_player(_player.global_position.y)


func update_depth_for_player(player_global_y: float) -> void:
	z_index = in_front_of_player_z_index if player_global_y < global_position.y else behind_player_z_index
