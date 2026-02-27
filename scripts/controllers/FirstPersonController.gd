extends CharacterBody3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.003
@export var controller_sensitivity: float = 2.0

## Intervalo entre pasos en segundos.
@export var step_interval: float = 0.6

const STEP_SOUNDS: Array[Resource] = [
	preload("res://assets/audio/sounds/step1.wav"),
	preload("res://assets/audio/sounds/step2.wav"),
	preload("res://assets/audio/sounds/step3.wav"),
]

var _is_interacting: bool = false
var _step_timer: float = 0.0
var _step_player: AudioStreamPlayer = null

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_step_player = AudioStreamPlayer.new()
	_step_player.volume_db = -10
	_step_player.bus = "Master"
	add_child(_step_player)

func _unhandled_input(event):
	if _is_interacting:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if _is_interacting:
		velocity = Vector3.ZERO
		return

	# Get the input direction and handle the movement/deceleration.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# Controller Look
	var look_dir: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_dir.length() > 0:
		head.rotate_y(-look_dir.x * controller_sensitivity * delta)
		camera.rotate_x(-look_dir.y * controller_sensitivity * delta)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	move_and_slide()

	# Pasos
	_update_footsteps(delta)


## Activa/desactiva el estado de interacción.
## Bloquea movimiento y controles de cámara durante diálogos.
func set_interacting(value: bool) -> void:
	_is_interacting = value
	if value:
		velocity = Vector3.ZERO
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Reproduce sonidos de pasos al caminar.
func _update_footsteps(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.5 and is_on_floor():
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = step_interval
			_step_player.stream = STEP_SOUNDS.pick_random()
			_step_player.pitch_scale = randf_range(0.9, 1.1)
			_step_player.play()
	else:
		_step_timer = 0.0
