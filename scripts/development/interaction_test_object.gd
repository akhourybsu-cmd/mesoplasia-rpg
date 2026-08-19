extends StaticBody2D

var interaction_count := 0

@onready var _visual: Polygon2D = $Visual
@onready var _label: Label = $DevelopmentLabel


func _on_interacted(_interactor: Node2D) -> void:
	interaction_count += 1
	_visual.color = Color(0.9, 0.75, 0.2, 1) if interaction_count % 2 == 1 else Color(0.65, 0.25, 0.7, 1)
	_label.text = "DEV INTERACTION COUNT: %d" % interaction_count
	print("DEV interaction test activated (%d)." % interaction_count)
