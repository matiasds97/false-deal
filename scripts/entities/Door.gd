extends Node3D

var open: bool = false

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if open:
			_close()
		else:
			_open()

func _open() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation_degrees", Vector3(0, -120, 0), 3.0)
	open = true

func _close() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation_degrees", Vector3.ZERO, 3.0)
	open = false
