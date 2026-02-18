class_name TrucoUI
extends Control

## Main UI Controller for the Truco match.
## Orchestrates sub-components for Calls, Responses, and Notifications.

# --- REFERENCES (Assigned via Editor) ---
@onready var envido_value_label: Label = %EnvidoValueLabel
@onready var fold_button: Button = $MarginContainer2/HBoxContainer/FoldButton
@onready var hand: Marker3D = $"../HumanHand"
@onready var scoreboard: Scoreboard = %Scoreboard
@onready var rival_calls_label: Label = %RivalCallsLabel
@onready var rival_decision_state_label: Label = %RivalDecisionStateLabel

# Calls UI Nodes
@onready var envido_button: Button = $CallsContainer/VBoxContainer/Control/EnvidoButton
@onready var real_envido_button: Button = $CallsContainer/VBoxContainer/Control/RealEnvidoButton
@onready var falta_envido_button: Button = $CallsContainer/VBoxContainer/Control/FaltaEnvidoButton
@onready var flor_button: Button = %FlorButton
@onready var truco_button: Button = $CallsContainer/VBoxContainer/Control/TrucoButton

# Response UI Nodes
@onready var response_container: MarginContainer = $ResponseContainer
@onready var response_vbox: VBoxContainer = $ResponseContainer/VBoxContainer
@onready var quiero_button: Button = $ResponseContainer/VBoxContainer/QuieroButton
@onready var no_quiero_button: Button = $ResponseContainer/VBoxContainer/NoQuieroButton

# Dependencies
@onready var truco_manager: TrucoManager = $"../TrucoManager"

# --- SUB-COMPONENTS (Logic Controllers) ---
var calls_panel: TrucoCallsPanel
var response_panel: TrucoResponsePanel
var notification_display: TrucoNotificationDisplay

var ui_locked: bool = false

func _ready() -> void:
	# 1. Initialize Sub-components
	_setup_components()
	
	# 2. Connect Global Signals
	_connect_global_signals()
	
	# 3. Connect Local UI
	if hand:
		hand.envido_calculated.connect(_on_envido_calculated)
	
	fold_button.pressed.connect(_on_fold_button_pressed)
	
	# 4. Initial Update
	call_deferred("_update_ui_state")

func _setup_components() -> void:
	# Calls Panel Logic
	calls_panel = TrucoCallsPanel.new()
	calls_panel.name = "CallsPanelController"
	add_child(calls_panel)
	
	# Inject references
	calls_panel.envido_button = envido_button
	calls_panel.real_envido_button = real_envido_button
	calls_panel.falta_envido_button = falta_envido_button
	calls_panel.flor_button = flor_button
	calls_panel.truco_button = truco_button
	calls_panel.initialize(truco_manager)
	
	calls_panel.action_taken.connect(_on_ui_action_taken)
	
	# Response Panel Logic
	response_panel = TrucoResponsePanel.new()
	response_panel.name = "ResponsePanelController"
	add_child(response_panel)
	
	# Inject references
	response_panel.quiero_button = quiero_button
	response_panel.no_quiero_button = no_quiero_button
	response_panel.vbox_container = response_vbox # For dynamic buttons
	response_panel.initialize(truco_manager)
	
	response_panel.action_taken.connect(_on_ui_action_taken)
	
	# Notification Display
	notification_display = TrucoNotificationDisplay.new()
	notification_display.name = "NotificationController"
	add_child(notification_display)
	
	notification_display.rival_calls_label = rival_calls_label
	notification_display.result_label = rival_decision_state_label

func set_ui_locked(locked: bool) -> void:
	ui_locked = locked
	if fold_button: fold_button.disabled = locked
	if calls_panel: calls_panel.set_locked(locked)
	if response_panel: response_panel.set_locked(locked)

func _check_unlock_needs() -> void:
	# Determine if we should unlock based on game state
	var is_human_turn: bool = truco_manager.current_turn_index == TrucoConstants.PLAYER_HUMAN
	var pending_action: int = truco_manager.pending_response_action
	
	# If there is a pending action (challenge logic), are we the ones supposed to answer?
	# We infer this from the fact that response_container is visible (handled by _on_calls)
	# Or simply: if pending action exists, normal turn logic is suspended.
	
	if pending_action != TrucoConstants.ResponseAction.NONE:
		# If we are showing response options, we must be unlocked
		if response_container.visible:
			set_ui_locked(false)
		else:
			set_ui_locked(true) # Waiting for CPU response
	else:
		# No pending challenge, check turn
		if is_human_turn:
			set_ui_locked(false)
		else:
			set_ui_locked(true)

func _on_ui_action_taken() -> void:
	set_ui_locked(true)

func _connect_global_signals() -> void:
	# SignalBus connections
	TrucoSignalBus.on_score_updated.connect(_on_score_updated)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)
	
	# State changes triggers
	TrucoSignalBus.on_turn_started.connect(_on_turn_started)
	TrucoSignalBus.on_envido_resolved.connect(_on_envido_resolved)
	TrucoSignalBus.on_truco_resolved.connect(_on_truco_resolved)
	TrucoSignalBus.on_flor_resolved.connect(_on_flor_resolved)
	
	# Incoming Calls (Show Response UI)
	TrucoSignalBus.on_envido_called.connect(_on_envido_called)
	TrucoSignalBus.on_truco_called.connect(_on_truco_called)
	TrucoSignalBus.on_flor_called.connect(_on_flor_called)

func _update_ui_state() -> void:
	calls_panel.update_state()
	response_panel.update_state()
	# Check lock state too?
	_check_unlock_needs()

func _on_turn_started(_player_index: int) -> void:
	_update_ui_state()

# --- CALL EVENT HANDLERS ---

## Shared handler for when the opponent (CPU) makes a call.
func _handle_opponent_call(call_text: String) -> void:
	response_container.visible = true
	response_panel.update_state()
	set_ui_locked(false)
	notification_display.show_call(call_text)
	calls_panel.update_state()

## Shared handler for when we (human) make a call.
func _handle_own_call() -> void:
	response_container.visible = false
	set_ui_locked(true)
	calls_panel.update_state()

func _on_envido_called(player_index: int, type: int) -> void:
	if player_index == TrucoConstants.PLAYER_CPU:
		var text: String = "Envido!"
		match type:
			TrucoConstants.EnvidoType.REAL_ENVIDO: text = "Real Envido!"
			TrucoConstants.EnvidoType.FALTA_ENVIDO: text = "Falta Envido!"
		_handle_opponent_call(text)
	else:
		_handle_own_call()

func _on_truco_called(player_index: int, level: int) -> void:
	if player_index == TrucoConstants.PLAYER_CPU:
		var text: String = "Truco!"
		match level:
			2: text = "Retruco!"
			3: text = "Vale 4!"
		_handle_opponent_call(text)
	else:
		_handle_own_call()

func _on_flor_called(player_index: int, type: int) -> void:
	if player_index == TrucoConstants.PLAYER_CPU:
		var text: String = "Flor!"
		match type:
			TrucoConstants.FlorType.CONTRA_FLOR: text = "Contra Flor!"
			TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO: text = "Contra Flor Al Resto!"
		_handle_opponent_call(text)
	else:
		_handle_own_call()

func _on_envido_resolved(accepted: bool, winner_index: int, points: int) -> void:
	response_container.visible = false
	
	var p0_score: int = truco_manager.players[0].get_envido_points()
	var p1_score: int = truco_manager.players[1].get_envido_points()
	
	notification_display.on_envido_resolved(accepted, winner_index, points, p0_score, p1_score)
	_update_ui_state()

func _on_truco_resolved(accepted: bool, player_index: int, level: int) -> void:
	response_container.visible = false
	notification_display.on_truco_resolved(accepted, player_index, level)
	_update_ui_state()

func _on_flor_resolved(accepted: bool, winner_index: int, points: int) -> void:
	response_container.visible = false
	notification_display.on_flor_resolved(accepted, winner_index, points)
	_update_ui_state()

func _on_hand_started(_hand_num: int) -> void:
	response_container.visible = false
	notification_display.hide_call()
	notification_display.clear_result()
	calls_panel.reset()
	_update_ui_state()

func _on_score_updated(human_score: int, cpu_score: int) -> void:
	if scoreboard:
		scoreboard.set_points(human_score, cpu_score)

func _on_envido_calculated(score: int) -> void:
	if envido_value_label:
		envido_value_label.text = str(score)

func _on_fold_button_pressed() -> void:
	if ui_locked: return
	set_ui_locked(true) # Instant lock
	if truco_manager:
		truco_manager.player_fold(TrucoConstants.PLAYER_HUMAN)
