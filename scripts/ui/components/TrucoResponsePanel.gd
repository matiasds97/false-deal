class_name TrucoResponsePanel
extends Node

## Handles the response buttons (Quiero, No Quiero, Raises).
## Should be attached to the ResponseContainer.

@export var quiero_button: Button
@export var no_quiero_button: Button
@export var vbox_container: VBoxContainer

# Dependencies
var truco_manager: TrucoManager

# Dynamic Buttons
var raise_envido_btn: Button
var raise_real_envido_btn: Button
var raise_falta_envido_btn: Button
var raise_truco_btn: Button # For Retruco/Vale 4
var raise_flor_btn: Button
var raise_contra_flor_btn: Button
var raise_contra_flor_resto_btn: Button

var controls_locked: bool = false
signal action_taken

func initialize(manager: TrucoManager) -> void:
	truco_manager = manager
	_create_dynamic_buttons()
	_connect_signals()

func set_locked(locked: bool) -> void:
	controls_locked = locked
	update_state()

func _create_dynamic_buttons() -> void:
	if not vbox_container: return
	
	raise_envido_btn = _create_btn("Envido", _on_raise_envido)
	raise_real_envido_btn = _create_btn("Real Envido", _on_raise_real_envido)
	raise_falta_envido_btn = _create_btn("Falta Envido", _on_raise_falta_envido)
	raise_truco_btn = _create_btn("Retruco", _on_raise_truco)
	
	raise_flor_btn = _create_btn("Flor", _on_raise_flor)
	raise_contra_flor_btn = _create_btn("Contra Flor", _on_raise_contra_flor)
	raise_contra_flor_resto_btn = _create_btn("Contra Flor Al Resto", _on_raise_contra_flor_resto)

func _create_btn(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.visible = false
	btn.pressed.connect(callback)
	vbox_container.add_child(btn)
	return btn

func _connect_signals() -> void:
	if quiero_button: quiero_button.pressed.connect(_on_quiero)
	if no_quiero_button: no_quiero_button.pressed.connect(_on_no_quiero)

func update_state() -> void:
	if not truco_manager: return
	
	# Global lock override
	if controls_locked:
		if quiero_button: quiero_button.disabled = true
		if no_quiero_button: no_quiero_button.disabled = true
		_disable_dynamic_buttons()
		return
		
	# Re-enable if unlocked
	if quiero_button: quiero_button.disabled = false
	if no_quiero_button: no_quiero_button.disabled = false
	
	var p_index = TrucoConstants.PLAYER_HUMAN
	
	# Only visible if there is a pending action to OUR player?
	# TrucoManager doesn't explicitly expose WHO is waiting. 
	# But Logic does: TrucoGame.PLAYER_TURN state implies waiting for action?
	# Actually, `TrucoHumanPlayerController` handles turn.
	# But `pending_response_action` logic is global.
	# We rely on TrucoUI logic: "If CPU called, Show response".
	# This logic is best kept in TrucoUI or checked here via a "is_responding" flag?
	# Let's assume this panel is VISIBLE only when needed, so we just update content.
	
	if not vbox_container or not vbox_container.is_visible_in_tree(): return # Skip update if hidden
	
	var action = truco_manager.pending_response_action
	
	_reset_buttons()
	
	if action == TrucoConstants.ResponseAction.ENVIDO:
		_update_envido_response(p_index)
	elif action == TrucoConstants.ResponseAction.TRUCO:
		_update_truco_response(p_index)
	elif action == TrucoConstants.ResponseAction.FLOR:
		_update_flor_response(p_index)

func _reset_buttons() -> void:
	quiero_button.visible = true
	no_quiero_button.visible = true
	# Reset texts to default
	quiero_button.text = "Quiero"
	no_quiero_button.text = "No Quiero"
	
	raise_envido_btn.visible = false
	raise_real_envido_btn.visible = false
	raise_falta_envido_btn.visible = false
	raise_truco_btn.visible = false
	raise_flor_btn.visible = false
	raise_contra_flor_btn.visible = false
	raise_contra_flor_resto_btn.visible = false

func _disable_dynamic_buttons() -> void:
	var btns = [
		raise_envido_btn, raise_real_envido_btn, raise_falta_envido_btn,
		raise_truco_btn, raise_flor_btn, raise_contra_flor_btn,
		raise_contra_flor_resto_btn
	]
	for btn in btns:
		if btn: btn.disabled = true

func _update_envido_response(p_index: int) -> void:
	# Check for Flor interception
	var can_call_flor = truco_manager.can_call_flor(TrucoConstants.FlorType.FLOR, p_index)
	
	if can_call_flor:
		# Must call Flor (swaps Envido response for Flor declaration)
		quiero_button.visible = false
		no_quiero_button.visible = false
		raise_flor_btn.visible = true
		raise_flor_btn.disabled = false
		return
	
	# Normal Envido raises
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, p_index):
		raise_envido_btn.visible = true
		raise_envido_btn.disabled = false
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, p_index):
		raise_real_envido_btn.visible = true
		raise_real_envido_btn.disabled = false
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, p_index):
		raise_falta_envido_btn.visible = true
		raise_falta_envido_btn.disabled = false

func _update_truco_response(p_index: int) -> void:
	# Raise Truco?
	# Check proposed level
	var proposed = truco_manager.proposed_truco_level
	if proposed < 3: # Can raise unless Vale 4
		# Check if we allow raising (not caller_index etc is checked by manager)
		# But can_call_truco handles most logic.
		# Note: can_call_truco might return false if we are the one answering?
		# TrucoTrucoLogic: `can_call` handles the "pending_action == TRUCO" case.
		if truco_manager.can_call_truco(p_index):
			raise_truco_btn.visible = true
			raise_truco_btn.disabled = false
			if proposed == 1: raise_truco_btn.text = "Retruco"
			if proposed == 2: raise_truco_btn.text = "Vale 4"

	# Envido interception? (Envido First rule)
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, p_index):
		raise_envido_btn.visible = true
		raise_envido_btn.disabled = false
	# Also Real/Falta...
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, p_index):
		raise_real_envido_btn.visible = true
		raise_real_envido_btn.disabled = false
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, p_index):
		raise_falta_envido_btn.visible = true
		raise_falta_envido_btn.disabled = false
		
	# Flor interception
	if truco_manager.can_call_flor(TrucoConstants.FlorType.FLOR, p_index):
		raise_flor_btn.visible = true
		raise_flor_btn.disabled = false

func _update_flor_response(p_index: int) -> void:
	# Analyze chain
	var _chain = truco_manager.flor_chain
	# Or assume last call implies state.
	
	# If simple "Flor" called:
	# We can: "Quiero" (Flor/Me too), "ContraFlor", "Al Resto".
	# Logic check:
	if truco_manager.can_call_flor(TrucoConstants.FlorType.CONTRA_FLOR, p_index):
		# We have Flor too.
		quiero_button.text = "Flor (Quiero)"
		no_quiero_button.visible = false # Cannot say No if we have Flor (must play)?
		# Wait, if we DON'T have Flor, we just say "Quiero" (acknowledge)?
		# Or "Me achico" -> Implies folding the Flor points?
		# TrucoFlorLogic handles resolve(false) as "Caller wins".
		
		raise_contra_flor_btn.visible = true
		raise_contra_flor_btn.disabled = false
		if truco_manager.can_call_flor(TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO, p_index):
			raise_contra_flor_resto_btn.visible = true
			raise_contra_flor_resto_btn.disabled = false
	else:
		# We don't have Flor.
		# We acknowledge.
		quiero_button.text = "Quiero"
		no_quiero_button.visible = false # Usually simple Flor isn't rejected, just accepted (points for them)

# --- ACTIONS ---

func _on_quiero() -> void:
	action_taken.emit()
	_resolve(true)

func _on_no_quiero() -> void:
	action_taken.emit()
	_resolve(false)

func _resolve(accepted: bool) -> void:
	var action = truco_manager.pending_response_action
	match action:
		TrucoConstants.ResponseAction.ENVIDO: truco_manager.resolve_envido(accepted, TrucoConstants.PLAYER_HUMAN)
		TrucoConstants.ResponseAction.TRUCO: truco_manager.resolve_truco(accepted, TrucoConstants.PLAYER_HUMAN)
		TrucoConstants.ResponseAction.FLOR: truco_manager.resolve_flor(accepted, TrucoConstants.PLAYER_HUMAN)

func _on_raise_envido() -> void:
	action_taken.emit()
	truco_manager.call_envido(TrucoConstants.EnvidoType.ENVIDO, TrucoConstants.PLAYER_HUMAN)

func _on_raise_real_envido() -> void:
	action_taken.emit()
	truco_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, TrucoConstants.PLAYER_HUMAN)

func _on_raise_falta_envido() -> void:
	action_taken.emit()
	truco_manager.call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, TrucoConstants.PLAYER_HUMAN)

func _on_raise_truco() -> void:
	action_taken.emit()
	truco_manager.call_truco(TrucoConstants.PLAYER_HUMAN)

func _on_raise_flor() -> void:
	action_taken.emit()
	truco_manager.call_flor(TrucoConstants.FlorType.FLOR, TrucoConstants.PLAYER_HUMAN)

func _on_raise_contra_flor() -> void:
	action_taken.emit()
	truco_manager.call_flor(TrucoConstants.FlorType.CONTRA_FLOR, TrucoConstants.PLAYER_HUMAN)

func _on_raise_contra_flor_resto() -> void:
	action_taken.emit()
	truco_manager.call_flor(TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO, TrucoConstants.PLAYER_HUMAN)
