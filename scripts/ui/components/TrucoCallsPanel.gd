class_name TrucoCallsPanel
extends MarginContainer

## Handles the initial call buttons (Envido, Truco, Flor).
## Self-contained scene with its own visual hierarchy.

@onready var envido_button: Button = %EnvidoButton
@onready var real_envido_button: Button = %RealEnvidoButton
@onready var falta_envido_button: Button = %FaltaEnvidoButton
@onready var flor_button: Button = %FlorButton
@onready var truco_button: Button = %TrucoButton

# Dependencies (injected)
var truco_manager: TrucoManager

# State
var is_envido_expanded: bool = false
var is_animating: bool = false
var controls_locked: bool = false

signal action_taken

func initialize(manager: TrucoManager) -> void:
	truco_manager = manager
	_connect_signals()

func reset() -> void:
	controls_locked = false
	_reset_expansion()

func set_locked(locked: bool) -> void:
	controls_locked = locked
	update_state()

func _ready() -> void:
	# Add buttons to the global UI group for sound handling
	var buttons = [envido_button, real_envido_button, falta_envido_button, flor_button, truco_button]
	for btn in buttons:
		if btn:
			btn.add_to_group("ui_buttons")

func _connect_signals() -> void:
	envido_button.pressed.connect(_on_envido_pressed)
	real_envido_button.pressed.connect(_on_real_envido_pressed)
	falta_envido_button.pressed.connect(_on_falta_envido_pressed)
	flor_button.pressed.connect(_on_flor_pressed)
	truco_button.pressed.connect(_on_truco_pressed)

func update_state() -> void:
	if not truco_manager: return
	
	# Global lock override
	if controls_locked:
		envido_button.disabled = true
		real_envido_button.disabled = true
		falta_envido_button.disabled = true
		flor_button.disabled = true
		truco_button.disabled = true
		return
	
	var p_index = TrucoConstants.PLAYER_HUMAN
	
	# ENVIDO Logic
	envido_button.disabled = false
	var can_envido = truco_manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, p_index)
	
	# Hide if pending response action is ENVIDO (force use of ResponsePanel)
	if truco_manager.pending_response_action == TrucoConstants.ResponseAction.ENVIDO:
		can_envido = false
		
	envido_button.visible = can_envido

	real_envido_button.disabled = false
	var can_real = truco_manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, p_index)
	real_envido_button.visible = can_real and is_envido_expanded
	
	falta_envido_button.disabled = false
	var can_falta = truco_manager.can_call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, p_index)
	falta_envido_button.visible = can_falta and is_envido_expanded

	# FLOR Logic
	flor_button.disabled = false
	var can_flor = truco_manager.can_call_flor(TrucoConstants.FlorType.FLOR, p_index)
	flor_button.visible = can_flor

	# TRUCO Logic
	_update_truco_button(p_index)

func _update_truco_button(p_index: int) -> void:
	# Disable main button if we are in the middle of a response flow
	if truco_manager.pending_response_action != TrucoConstants.ResponseAction.NONE:
		truco_button.disabled = true
		return

	var can_call = truco_manager.can_call_truco(p_index)
	truco_button.disabled = not can_call
	
	var current_level = truco_manager.current_truco_level
	
	var label_text = "Truco"
	match current_level:
		0: label_text = "Truco"
		1: label_text = "Retruco"
		2: label_text = "Vale 4"
		3: label_text = "Vale 4"
	
	truco_button.text = label_text

# --- ACTIONS ---

func _on_envido_pressed() -> void:
	if is_envido_expanded and not is_animating:
		action_taken.emit()
		truco_manager.call_envido(TrucoConstants.EnvidoType.ENVIDO, TrucoConstants.PLAYER_HUMAN)
		_reset_expansion()
	else:
		_animate_expansion()

func _on_real_envido_pressed() -> void:
	action_taken.emit()
	truco_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, TrucoConstants.PLAYER_HUMAN)
	_reset_expansion()

func _on_falta_envido_pressed() -> void:
	action_taken.emit()
	truco_manager.call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, TrucoConstants.PLAYER_HUMAN)
	_reset_expansion()

func _on_flor_pressed() -> void:
	action_taken.emit()
	truco_manager.call_flor(TrucoConstants.FlorType.FLOR, TrucoConstants.PLAYER_HUMAN)

func _on_truco_pressed() -> void:
	action_taken.emit()
	truco_manager.call_truco(TrucoConstants.PLAYER_HUMAN)

# --- ANIMATION ---
func _animate_expansion() -> void:
	if is_animating: return
	is_animating = true
	is_envido_expanded = true
	
	# 1. Update visibility first so we can manipulate them
	update_state()
	
	# 2. Setup initial state for animation
	var start_pos = envido_button.position
	var button_height = envido_button.size.y
	var spacing = 10.0
	
	if real_envido_button.visible:
		real_envido_button.modulate.a = 0.0
		real_envido_button.position = start_pos
	
	if falta_envido_button.visible:
		falta_envido_button.modulate.a = 0.0
		falta_envido_button.position = start_pos

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 3. Animate Real Envido (1 step up)
	if real_envido_button.visible:
		var target_y = start_pos.y - button_height - spacing
		tween.tween_property(real_envido_button, "position:y", target_y, 0.3)
		tween.tween_property(real_envido_button, "modulate:a", 1.0, 0.2)
		
	# 4. Animate Falta Envido (2 steps up)
	if falta_envido_button.visible:
		var target_y_falta = start_pos.y - (button_height * 2) - (spacing * 2)
		tween.tween_property(falta_envido_button, "position:y", target_y_falta, 0.3).set_delay(0.05)
		tween.tween_property(falta_envido_button, "modulate:a", 1.0, 0.2).set_delay(0.05)

	tween.chain().tween_callback(func():
		is_animating = false
	)

func _reset_expansion() -> void:
	is_envido_expanded = false
	
	real_envido_button.modulate.a = 1.0
	falta_envido_button.modulate.a = 1.0
		
	update_state()
	is_animating = false
