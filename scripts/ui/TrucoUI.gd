class_name TrucoUI
extends Control

## Main UI Controller for the Truco match.
## Orchestrates sub-components for Calls, Responses, and Notifications.

# --- UI SUB-COMPONENTS (Scene instances in editor) ---
@onready var calls_panel: TrucoCallsPanel = %TrucoCallsPanel
@onready var response_panel: TrucoResponsePanel = %TrucoResponsePanel
@onready var notification_display: TrucoNotificationDisplay = %TrucoNotificationDisplay
@onready var scoreboard: Scoreboard = %Scoreboard

# --- OTHER UI ELEMENTS ---
@onready var envido_value_label: Label = %EnvidoValueLabel
@onready var fold_button: Button = $MarginContainer2/HBoxContainer/FoldButton

# --- EXTERNAL DEPENDENCIES (set from parent scene) ---
@export var truco_manager_path: NodePath
@export var hand_path: NodePath

var truco_manager: TrucoManager
var hand: Marker3D

# --- OVERLAY SCENES (instantiated at runtime) ---
var results_screen: TrucoResults
var match_start_splash: TrucoMatchStart

const RESULTS_SCENE = preload("res://scenes/ui/truco_results.tscn")
const MATCH_START_SCENE = preload("res://scenes/ui/truco_match_start.tscn")

var ui_locked: bool = false

func _ready() -> void:
	# 0. Resolve external dependencies
	if truco_manager_path:
		truco_manager = get_node(truco_manager_path) as TrucoManager
	if hand_path:
		hand = get_node(hand_path) as Marker3D
	
	if not truco_manager:
		push_warning("TrucoUI: truco_manager_path not set — UI will not function.")
		return
	
	# 1. Initialize Sub-components (inject manager reference only)
	_setup_components()
	
	# 2. Connect Global Signals
	_connect_global_signals()
	
	# 3. Connect Local UI
	if hand:
		hand.envido_calculated.connect(_on_envido_calculated)
	
	fold_button.pressed.connect(_on_fold_button_pressed)
	
	# 4. Initial Update
	call_deferred("_update_ui_state")
	
	# 5. Hide containers that shouldn't show during splash
	response_panel.visible = false
	notification_display.visible = false
	
	# 6. Show splash and start match after it finishes
	call_deferred("_start_match_with_splash")

func _setup_components() -> void:
	# Initialize sub-components with manager reference
	calls_panel.initialize(truco_manager)

	calls_panel.action_taken.connect(_on_ui_action_taken)
	
	response_panel.initialize(truco_manager)
	response_panel.action_taken.connect(_on_ui_action_taken)
	
	# Results Screen (instantiated but hidden)
	results_screen = RESULTS_SCENE.instantiate() as TrucoResults
	add_child(results_screen)
	results_screen.replay_requested.connect(_on_replay_requested)
	results_screen.exit_requested.connect(_on_exit_requested)
	
	# Match Start Splash
	match_start_splash = MATCH_START_SCENE.instantiate() as TrucoMatchStart
	add_child(match_start_splash)
	match_start_splash.finished.connect(_on_splash_finished)

func _start_match_with_splash() -> void:
	set_ui_locked(true)
	match_start_splash.play()

func _on_splash_finished() -> void:
	notification_display.visible = true
	truco_manager.start_match()

func set_ui_locked(locked: bool) -> void:
	ui_locked = locked
	fold_button.disabled = locked
	calls_panel.set_locked(locked)
	response_panel.set_locked(locked)

func _check_unlock_needs() -> void:
	var is_human_turn: bool = truco_manager.current_turn_index == TrucoConstants.PLAYER_HUMAN
	var pending_action: int = truco_manager.pending_response_action
	
	if pending_action != TrucoConstants.ResponseAction.NONE:
		if response_panel.visible:
			set_ui_locked(false)
		else:
			set_ui_locked(true)
	else:
		if is_human_turn:
			set_ui_locked(false)
		else:
			set_ui_locked(true)

func _on_ui_action_taken() -> void:
	set_ui_locked(true)

func _connect_global_signals() -> void:
	# SignalBus connections
	TrucoSignalBus.on_match_ended.connect(_on_match_ended)
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
	_check_unlock_needs()

func _on_turn_started(_player_index: int) -> void:
	_update_ui_state()

# --- CALL EVENT HANDLERS ---

## Shared handler for when the opponent (CPU) makes a call.
func _handle_opponent_call(call_text: String) -> void:
	calls_panel.visible = false
	response_panel.visible = true
	response_panel.update_state()
	set_ui_locked(false)
	notification_display.show_call(call_text)

## Shared handler for when we (human) make a call.
func _handle_own_call() -> void:
	response_panel.visible = false
	calls_panel.visible = true
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
	response_panel.visible = false
	calls_panel.visible = true
	
	var p0_score: int = truco_manager.players[0].get_envido_points()
	var p1_score: int = truco_manager.players[1].get_envido_points()
	
	notification_display.on_envido_resolved(accepted, winner_index, points, p0_score, p1_score)
	_update_ui_state()

func _on_truco_resolved(accepted: bool, player_index: int, level: int) -> void:
	response_panel.visible = false
	calls_panel.visible = true
	notification_display.on_truco_resolved(accepted, player_index, level)
	_update_ui_state()

func _on_flor_resolved(accepted: bool, winner_index: int, points: int) -> void:
	response_panel.visible = false
	calls_panel.visible = true
	notification_display.on_flor_resolved(accepted, winner_index, points)
	_update_ui_state()

func _on_hand_started(_hand_num: int) -> void:
	response_panel.visible = false
	notification_display.hide_call()
	notification_display.clear_result()
	calls_panel.reset()
	_update_ui_state()

func _on_score_updated(human_score: int, cpu_score: int) -> void:
	scoreboard.set_points(human_score, cpu_score)

func _on_envido_calculated(score: int) -> void:
	envido_value_label.text = str(score)

func _on_fold_button_pressed() -> void:
	if ui_locked: return
	set_ui_locked(true)
	truco_manager.player_fold(TrucoConstants.PLAYER_HUMAN)

func _on_match_ended(winner_index: int) -> void:
	set_ui_locked(true)
	response_panel.visible = false
	get_tree().create_timer(2.5).timeout.connect(func():
		results_screen.show_result(winner_index == TrucoConstants.PLAYER_HUMAN)
	)

func _on_replay_requested() -> void:
	results_screen.visible = false
	_start_match_with_splash()

func _on_exit_requested() -> void:
	get_tree().quit()
