class_name AvatarMovementAdapter
extends Node


func simulate_movement(
	avatar: CharacterBody2D,
	movement_direction: Vector2,
	movement_speed: float,
	controls_locked: bool
) -> Vector2:
	var applied_direction := Vector2.ZERO if controls_locked else movement_direction
	avatar.velocity = applied_direction * movement_speed
	avatar.move_and_slide()
	return applied_direction
