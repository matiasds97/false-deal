extends Camera3D

## Toggles camera between default seated view and top-down table inspection view.
## Mapped to "toggle_table_view" input action (W key / joystick up by default).
## Auto-returns to default view when a new hand starts.

## Reference to the table center marker for calculating the top-down view target
@export var table_center_path: NodePath
@onready var _audio: AudioStreamPlayer = $AudioStreamPlayer

## Duration of the camera transition tween
const TWEEN_DURATION: float = 0.4

## Whether the camera is currently in top-down table view
var _is_table_view: bool = false

## Stored default transform to return to
var _default_transform: Transform3D

## Active tween (to kill if interrupted)
var _active_tween: Tween = null


func _ready() -> void:
	_default_transform = transform
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_table_view"):
		_toggle_view()
		return
		
	if event.is_action_pressed("return_table_view"):
		if _is_table_view:
			_toggle_view()
		return
		
	if event.is_action_pressed("hold_table_view"):
		if not _is_table_view:
			_toggle_view()
		return
	elif event.is_action_released("hold_table_view"):
		if _is_table_view:
			_toggle_view()
		return


func _on_hand_started(_hand_number: int) -> void:
	if _is_table_view:
		_return_to_default()


func _toggle_view() -> void:
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	_is_table_view = not _is_table_view
	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.set_trans(Tween.TRANS_CUBIC)

	if _is_table_view:
		# Exact position and rotation tested with OverrideCamera3D
		var top_down_transform := Transform3D()
		top_down_transform.origin = Vector3(0, 1, 0)
		# Rotation (-90, 0, 0) = looking straight down
		top_down_transform.basis = Basis.from_euler(Vector3(deg_to_rad(-90), 0, 0))

		_active_tween.tween_property(self, "global_transform", top_down_transform, TWEEN_DURATION)
		_audio.play()
	else:
		_animate_to_default()
		_audio.play()


func _return_to_default() -> void:
	_is_table_view = false
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_animate_to_default()


func _animate_to_default() -> void:
	var parent_transform: Transform3D = get_parent().global_transform if get_parent() else Transform3D.IDENTITY
	var target_global := parent_transform * _default_transform
	_active_tween.tween_property(self, "global_transform", target_global, TWEEN_DURATION)
