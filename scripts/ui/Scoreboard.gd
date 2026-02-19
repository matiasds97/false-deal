class_name Scoreboard
extends Control

var us_points: int
var them_points: int

var us_lines: Array[Points]
var them_lines: Array[Points]

@onready var us_grid_container: GridContainer = %UsGridContainer
@onready var them_grid_container: GridContainer = %ThemGridContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in us_grid_container.get_children():
		var points: Points = child
		us_lines.append(points)
	for child in them_grid_container.get_children():
		var points: Points = child
		them_lines.append(points)

func set_points(new_us_points: int, new_them_points: int) -> void:
	self.us_points = new_us_points
	self.them_points = new_them_points
	
	_update_points_display(us_lines, us_points)
	_update_points_display(them_lines, them_points)

func _update_points_display(lines: Array[Points], score: int) -> void:
	var remaining_score = score
	for points in lines:
		# Always keep points visible to maintain layout size
		points.visible = true
		
		# If we have score left to display
		if remaining_score > 0:
			var points_to_show = min(remaining_score, 5)
			points.set_points(points_to_show)
			remaining_score -= points_to_show
		else:
			# Show empty points container (0 points)
			points.set_points(0)
