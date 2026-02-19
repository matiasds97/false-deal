extends Control
class_name Points

var _points: int = 0
var lines: Array[ColorRect]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var control: Control = $Container
	if not control:
		push_error("Points node missing 'Container' child")
		return
		
	for child in control.get_children():
		if child is ColorRect:
			lines.append(child)

	set_points(0)

func set_points(points: int) -> void:
	_points = points
	_draw_lines()

func _draw_lines() -> void:
	for i in range(lines.size()):
		lines[i].visible = i < _points
