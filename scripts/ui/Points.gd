extends Control
class_name Points

var _points: int = 0
var lines: Array[ColorRect]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var control: Control = get_child(0)
	for child in control.get_children():
		var color_rect: ColorRect = child
		print(color_rect.name)
		lines.append(color_rect)

	set_points(0)

func set_points(points: int) -> void:
	_points = points
	_draw_lines()

func _draw_lines() -> void:
	for i in range(lines.size()):
		lines[i].visible = i < _points
