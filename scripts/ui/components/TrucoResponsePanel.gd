class_name TrucoResponsePanel
extends MarginContainer

## Handles the response buttons (Quiero, No Quiero, Raises).
## Buttons are visually grouped by purpose: Response, Envido intercept, Flor intercept.

# --- Scene References ---
@onready var quiero_button: Button = %QuieroButton
@onready var no_quiero_button: Button = %NoQuieroButton

# Groups
@onready var response_group: VBoxContainer = %ResponseGroup
@onready var envido_group: VBoxContainer = %EnvidoGroup
@onready var envido_separator: HSeparator = %EnvidoSeparator
@onready var flor_group: VBoxContainer = %FlorGroup
@onready var flor_separator: HSeparator = %FlorSeparator

# Dependencies
var truco_manager: TrucoManager

# Dynamic Buttons (created in code, added to their respective groups)
var raise_truco_btn: Button
var raise_envido_btn: Button
var raise_real_envido_btn: Button
var raise_falta_envido_btn: Button
var raise_flor_btn: Button
var raise_contra_flor_btn: Button
var raise_contra_flor_resto_btn: Button

var controls_locked: bool = false
signal action_taken

func _ready() -> void:
	if quiero_button: quiero_button.add_to_group("ui_buttons")
	if no_quiero_button: no_quiero_button.add_to_group("ui_buttons")

func initialize(manager: TrucoManager) -> void:
	truco_manager = manager
	_create_dynamic_buttons()
	_connect_signals()

func set_locked(locked: bool) -> void:
	controls_locked = locked
	update_state()

func _create_dynamic_buttons() -> void:
	# Response group: raise truco goes after Quiero/NoQuiero
	raise_truco_btn = _create_btn("Retruco", _on_raise_truco, response_group)

	# Envido group
	raise_envido_btn = _create_btn("Envido", _on_raise_envido, envido_group)
	raise_real_envido_btn = _create_btn("Real Envido", _on_raise_real_envido, envido_group)
	raise_falta_envido_btn = _create_btn("Falta Envido", _on_raise_falta_envido, envido_group)

	# Flor group
	raise_flor_btn = _create_btn("Flor", _on_raise_flor, flor_group)
	raise_contra_flor_btn = _create_btn("Contra Flor", _on_raise_contra_flor, flor_group)
	raise_contra_flor_resto_btn = _create_btn("Contra Flor Al Resto", _on_raise_contra_flor_resto, flor_group)

func _create_btn(text: String, callback: Callable, parent: Control) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.visible = false
	btn.pressed.connect(callback)
	btn.add_to_group("ui_buttons")
	parent.add_child(btn)
	return btn

func _connect_signals() -> void:
	quiero_button.pressed.connect(_on_quiero)
	no_quiero_button.pressed.connect(_on_no_quiero)

func update_state() -> void:
	if not truco_manager: return

	# Global lock override
	if controls_locked:
		quiero_button.disabled = true
		no_quiero_button.disabled = true
		_disable_dynamic_buttons()
		return

	# Re-enable if unlocked
	quiero_button.disabled = false
	no_quiero_button.disabled = false

	var p_index = TrucoConstants.PLAYER_HUMAN

	if not is_visible_in_tree(): return

	var action = truco_manager.pending_response_action

	_reset_all()

	if action == TrucoConstants.ResponseAction.ENVIDO:
		_update_envido_response(p_index)
	elif action == TrucoConstants.ResponseAction.TRUCO:
		_update_truco_response(p_index)
	elif action == TrucoConstants.ResponseAction.FLOR:
		_update_flor_response(p_index)

func _reset_all() -> void:
	# Reset response group
	quiero_button.visible = true
	no_quiero_button.visible = true
	quiero_button.text = "Quiero"
	no_quiero_button.text = "No Quiero"
	raise_truco_btn.visible = false

	# Reset envido group
	raise_envido_btn.visible = false
	raise_real_envido_btn.visible = false
	raise_falta_envido_btn.visible = false

	# Reset flor group
	raise_flor_btn.visible = false
	raise_contra_flor_btn.visible = false
	raise_contra_flor_resto_btn.visible = false

	# Hide optional groups by default
	_set_envido_group_visible(false)
	_set_flor_group_visible(false)

func _set_envido_group_visible(should_show: bool) -> void:
	envido_group.visible = should_show
	envido_separator.visible = should_show

func _set_flor_group_visible(should_show: bool) -> void:
	flor_group.visible = should_show
	flor_separator.visible = should_show

func _disable_dynamic_buttons() -> void:
	var btns = [
		raise_truco_btn,
		raise_envido_btn, raise_real_envido_btn, raise_falta_envido_btn,
		raise_flor_btn, raise_contra_flor_btn, raise_contra_flor_resto_btn
	]
	for btn in btns:
		if btn: btn.disabled = true

# --- RESPONSE BUILDERS ---

func _update_envido_response(p_index: int) -> void:
	# Flor intercept overrides everything
	if truco_manager.can_call_flor(TrucoConstants.FlorType.FLOR, p_index):
		quiero_button.visible = false
		no_quiero_button.visible = false
		response_group.visible = false
		_set_flor_group_visible(true)
		raise_flor_btn.visible = true
		raise_flor_btn.disabled = false
		return

	# Normal envido raises
	var has_envido_raise = false
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, p_index):
		raise_envido_btn.visible = true
		raise_envido_btn.disabled = false
		has_envido_raise = true
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, p_index):
		raise_real_envido_btn.visible = true
		raise_real_envido_btn.disabled = false
		has_envido_raise = true
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, p_index):
		raise_falta_envido_btn.visible = true
		raise_falta_envido_btn.disabled = false
		has_envido_raise = true

	_set_envido_group_visible(has_envido_raise)

func _update_truco_response(p_index: int) -> void:
	# Raise truco (Retruco / Vale 4)
	var proposed = truco_manager.proposed_truco_level
	if proposed < 3 and truco_manager.can_call_truco(p_index):
		raise_truco_btn.visible = true
		raise_truco_btn.disabled = false
		if proposed == 1: raise_truco_btn.text = "Retruco"
		if proposed == 2: raise_truco_btn.text = "Vale 4"

	# Envido First intercept
	var has_envido = false
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, p_index):
		raise_envido_btn.visible = true
		raise_envido_btn.disabled = false
		has_envido = true
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, p_index):
		raise_real_envido_btn.visible = true
		raise_real_envido_btn.disabled = false
		has_envido = true
	if truco_manager.can_call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, p_index):
		raise_falta_envido_btn.visible = true
		raise_falta_envido_btn.disabled = false
		has_envido = true
	_set_envido_group_visible(has_envido)

	# Flor intercept
	if truco_manager.can_call_flor(TrucoConstants.FlorType.FLOR, p_index):
		raise_flor_btn.visible = true
		raise_flor_btn.disabled = false
		_set_flor_group_visible(true)

func _update_flor_response(p_index: int) -> void:
	if truco_manager.can_call_flor(TrucoConstants.FlorType.CONTRA_FLOR, p_index):
		quiero_button.text = "Flor (Quiero)"
		no_quiero_button.visible = false

		_set_flor_group_visible(true)
		raise_contra_flor_btn.visible = true
		raise_contra_flor_btn.disabled = false
		if truco_manager.can_call_flor(TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO, p_index):
			raise_contra_flor_resto_btn.visible = true
			raise_contra_flor_resto_btn.disabled = false
	else:
		quiero_button.text = "Quiero"
		no_quiero_button.visible = false

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
