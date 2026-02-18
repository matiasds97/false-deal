class_name TrucoCallsPanel
extends Node

## Handles the initial call buttons (Envido, Truco, Flor).
## Should be attached to the container holding these buttons.

@export var envido_button: Button
@export var real_envido_button: Button
@export var falta_envido_button: Button
@export var flor_button: Button
@export var truco_button: Button

# Dependencies (injected or found)
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
	controls_locked = false # ensure unlocked on reset
	_reset_expansion()

func set_locked(locked: bool) -> void:
	controls_locked = locked
	update_state()

func _connect_signals() -> void:
	if envido_button: envido_button.pressed.connect(_on_envido_pressed)
	if real_envido_button: real_envido_button.pressed.connect(_on_real_envido_pressed)
	if falta_envido_button: falta_envido_button.pressed.connect(_on_falta_envido_pressed)
	if flor_button: flor_button.pressed.connect(_on_flor_pressed)
	if truco_button: truco_button.pressed.connect(_on_truco_pressed)

func update_state() -> void:
	if not truco_manager: return
	
	# Global lock override
	if controls_locked:
		if envido_button: envido_button.disabled = true
		if real_envido_button: real_envido_button.disabled = true
		if falta_envido_button: falta_envido_button.disabled = true
		if flor_button: flor_button.disabled = true
		if truco_button: truco_button.disabled = true
		return
	
	var p_index = TrucoConstants.PLAYER_HUMAN
	
	# ENVIDO Logic
	if envido_button:
		envido_button.disabled = false # Reset disabled state from lock
		# Can call envido if rules allow AND chain is empty
		var can_envido = truco_manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, p_index)
		
		# Hide if pending response action is ENVIDO (force use of ResponsePanel)
		if truco_manager.pending_response_action == TrucoConstants.ResponseAction.ENVIDO:
			can_envido = false
			
		# Hide if not allowed (e.g. Flor active or round passed)
		envido_button.visible = can_envido
	
	if real_envido_button:
		real_envido_button.disabled = false
		var can_real = truco_manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, p_index)
		# Visible only if expanded and allowed
		real_envido_button.visible = can_real and is_envido_expanded
		
	if falta_envido_button:
		falta_envido_button.disabled = false
		var can_falta = truco_manager.can_call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, p_index)
		falta_envido_button.visible = can_falta and is_envido_expanded

	# FLOR Logic
	if flor_button:
		flor_button.disabled = false
		var can_flor = truco_manager.can_call_flor(TrucoConstants.FlorType.FLOR, p_index)
		flor_button.visible = can_flor

	# TRUCO Logic
	if truco_button:
		_update_truco_button(p_index)

func _update_truco_button(p_index: int) -> void:
	# Disable main button if we are in the middle of a response flow
	# Any raises (Retruco, etc.) should come from the ResponsePanel
	if truco_manager.pending_response_action != TrucoConstants.ResponseAction.NONE:
		truco_button.disabled = true
		return

	var can_call = truco_manager.can_call_truco(p_index)
	truco_button.disabled = not can_call
	
	# Fix behavior: Update text based on current level
	# Note: TrucoManager delegates to Logic, let's use exposed properties
	var current_level = truco_manager.current_truco_level
	
	var label_text = "Truco"
	match current_level:
		0: label_text = "Truco"
		1: label_text = "Retruco"
		2: label_text = "Vale 4"
		3: label_text = "Vale 4" # Max level, probably disabled anyway
	
	truco_button.text = label_text

# --- ACTIONS ---

func _on_envido_pressed() -> void:
	if is_envido_expanded and not is_animating:
		action_taken.emit()
		# Confirm call
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
	# We want them to pop out from the Envido button
	var start_pos = envido_button.position
	var button_height = envido_button.size.y
	var spacing = 10.0
	
	# Ensure they start transparent and at the origin (Envido button)
	if real_envido_button.visible:
		real_envido_button.modulate.a = 0.0
		# If layout allows, reset position to start (might be overridden by containers immediately, but we try)
		# We use a trick: animate 'position' assuming Manual Layout inside the 'Control' parent.
		real_envido_button.position = start_pos
	
	if falta_envido_button.visible:
		falta_envido_button.modulate.a = 0.0
		falta_envido_button.position = start_pos

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 3. Animate Real Envido (1 step up/right)
	if real_envido_button.visible:
		var target_y = start_pos.y - button_height - spacing
		# If we have Falta Envido too, maybe Real stays closer?
		# Let's stack them upwards.
		tween.tween_property(real_envido_button, "position:y", target_y, 0.3)
		tween.tween_property(real_envido_button, "modulate:a", 1.0, 0.2)
		
	# 4. Animate Falta Envido (2 steps up/right)
	if falta_envido_button.visible:
		var target_y_falta = start_pos.y - (button_height * 2) - (spacing * 2)
		# If Real is not visible (rare case), adjusting target? 
		# For simplicity, fixed offset stack.
		tween.tween_property(falta_envido_button, "position:y", target_y_falta, 0.3).set_delay(0.05)
		tween.tween_property(falta_envido_button, "modulate:a", 1.0, 0.2).set_delay(0.05)

	tween.chain().tween_callback(func():
		is_animating = false
	)

func _reset_expansion() -> void:
	is_envido_expanded = false
	# Immediate reset or reverse animation?
	# For responsiveness, immediate reset is usually better, but let's be nice.
	
	# Actually, update_state() will hide them (visible=false).
	# Resetting modulate/position for next time is good practice.
	if real_envido_button:
		real_envido_button.modulate.a = 1.0
	if falta_envido_button:
		falta_envido_button.modulate.a = 1.0
		
	update_state()
	is_animating = false
