class_name TrucoUI
extends Control
## Main UI Controller for the Truco match.
## Handles visibility of buttons, labels, and updates interactions based on game state.

@onready var envido_value_label: Label = %EnvidoValueLabel
@onready var flor_container: PanelContainer = %FlorContainer
@onready var fold_button: Button = $MarginContainer2/PanelContainer/HBoxContainer/DealButton
@onready var hand: Marker3D = $"../HumanHand"
@onready var cpu_hand: Node3D = $"../CPUHand"
@onready var truco_manager: TrucoManager = $"../TrucoManager"
@onready var score_label: Label = $ScoreContainer/VBoxContainer/ScoreContainer/HBoxContainer/ScoreLabel
@onready var rival_calls_label: Label = %RivalCallsLabel
@onready var rival_decision_state_label: Label = %RivalDecisionStateLabel

# Calls UI
@onready var calls_vbox: VBoxContainer = $CallsContainer/VBoxContainer
@onready var envido_button: Button = $CallsContainer/VBoxContainer/EnvidoButton
@onready var real_envido_button: Button = $CallsContainer/VBoxContainer/RealEnvidoButton
@onready var falta_envido_button: Button = $CallsContainer/VBoxContainer/FaltaEnvidoButton

@onready var truco_button: Button = $CallsContainer/VBoxContainer/TrucoButton
@onready var response_container: MarginContainer = $ResponseContainer
@onready var response_vbox: VBoxContainer = $ResponseContainer/VBoxContainer
@onready var quiero_button: Button = $ResponseContainer/VBoxContainer/QuieroButton
@onready var no_quiero_button: Button = $ResponseContainer/VBoxContainer/NoQuieroButton

# Dynamic Buttons
var response_envido_button: Button
var response_real_envido_button: Button
var response_falta_envido_button: Button
var response_raise_truco_button: Button

func _ready() -> void:
	# Connect to Hand signals
	if hand:
		hand.envido_calculated.connect(_on_envido_calculated)
		hand.flor_detected.connect(_on_flor_detected)
		
	# Connect Fold Button (Repurposed Deal Button)
	fold_button.text = "Irse al Mazo"
	fold_button.pressed.connect(_on_fold_button_pressed)
	
	# Connect to SignalBus
	TrucoSignalBus.on_score_updated.connect(_on_score_updated)
	TrucoSignalBus.on_envido_called.connect(_on_envido_called)
	TrucoSignalBus.on_envido_resolved.connect(_on_envido_resolved)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)
	TrucoSignalBus.on_truco_called.connect(_on_truco_called)
	TrucoSignalBus.on_truco_resolved.connect(_on_truco_resolved)
	
	# Connect Buttons
	if envido_button:
		envido_button.pressed.connect(_on_envido_button_pressed)
	if real_envido_button:
		real_envido_button.pressed.connect(_on_real_envido_button_pressed)
	if falta_envido_button:
		falta_envido_button.pressed.connect(_on_falta_envido_button_pressed)
	if truco_button:
		truco_button.pressed.connect(_on_truco_button_pressed)
	if quiero_button:
		quiero_button.pressed.connect(_on_response_pressed.bind(true))
	if no_quiero_button:
		no_quiero_button.pressed.connect(_on_response_pressed.bind(false))
	
	# Move Truco button to bottom of calls (optional, but good for order)
	calls_vbox.move_child(truco_button, -1)
	
	# Response Buttons (Raise)
	response_envido_button = create_button("Envido", response_vbox, _on_envido_button_pressed) # Same handler, calls logic checks
	response_real_envido_button = create_button("Real Envido", response_vbox, _on_real_envido_button_pressed)
	response_falta_envido_button = create_button("Falta Envido", response_vbox, _on_falta_envido_button_pressed)
	response_raise_truco_button = create_button("Retruco", response_vbox, _on_truco_button_pressed)
	
	# Initial State
	response_container.visible = false

## Helper to create a standard button with local style.
func create_button(text: String, parent: Node, callback: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	parent.add_child(btn)
	btn.pressed.connect(callback)
	return btn

func _process(_delta: float) -> void:
	if not truco_manager: return
	_update_call_buttons_state()

## Updates the enabled/visible state of call and response buttons based on game rules.
func _update_call_buttons_state() -> void:
	# CALLS Container (Initial Calls)
	if envido_button:
		envido_button.disabled = not (truco_manager.can_call_envido(TrucoGame.EnvidoType.ENVIDO, 0) and truco_manager.envido_chain.is_empty())
	if real_envido_button:
		real_envido_button.disabled = not (truco_manager.can_call_envido(TrucoGame.EnvidoType.REAL_ENVIDO, 0) and truco_manager.envido_chain.is_empty())
	if falta_envido_button:
		falta_envido_button.disabled = not (truco_manager.can_call_envido(TrucoGame.EnvidoType.FALTA_ENVIDO, 0) and truco_manager.envido_chain.is_empty())

	# RESPONSE Container (Raising)
	if response_container.visible:
		if response_envido_button:
			response_envido_button.visible = truco_manager.can_call_envido(TrucoGame.EnvidoType.ENVIDO, 0)
		if response_real_envido_button:
			response_real_envido_button.visible = truco_manager.can_call_envido(TrucoGame.EnvidoType.REAL_ENVIDO, 0)
		if response_falta_envido_button:
			response_falta_envido_button.visible = truco_manager.can_call_envido(TrucoGame.EnvidoType.FALTA_ENVIDO, 0)

	if truco_button:
		# Update text based on level
		var next_level_name = "Truco"
		if truco_manager.current_truco_level == 1:
			next_level_name = "Retruco"
		elif truco_manager.current_truco_level == 2:
			next_level_name = "Vale 4"
			
		truco_button.text = next_level_name
		
		# Disable if cannot call
		var can_call = truco_manager.can_call_truco(0)
		if truco_button.disabled != (not can_call):
			truco_button.disabled = not can_call

	# RESPONSE Container (Raising Truco)
	if response_container.visible:
		if response_raise_truco_button:
			# Only show if responding to Truco/Retruco (and not already Vale 4)
			var is_truco_response = (truco_manager.pending_response_action == TrucoGame.ResponseAction.TRUCO)
			var can_raise = is_truco_response and (truco_manager.proposed_truco_level < 3)
			response_raise_truco_button.visible = can_raise
			
			if can_raise:
				if truco_manager.proposed_truco_level == 1:
					response_raise_truco_button.text = "Retruco"
				elif truco_manager.proposed_truco_level == 2:
					response_raise_truco_button.text = "Vale 4"

func _on_score_updated(human_score: int, cpu_score: int) -> void:
	if score_label:
		score_label.text = "Human: %d | CPU: %d" % [human_score, cpu_score]

func _on_fold_button_pressed() -> void:
	if truco_manager:
		truco_manager.player_fold(0)
# Removed debug deal logic

func _on_envido_calculated(score: int) -> void:
	if envido_value_label:
		envido_value_label.text = str(score)

func _on_flor_detected(has_flor: bool) -> void:
	if flor_container:
		flor_container.visible = has_flor

# --- Envido / Truco Logic ---

## Handles Envido Button Press.
func _on_envido_button_pressed() -> void:
	if truco_manager:
		truco_manager.call_envido(TrucoGame.EnvidoType.ENVIDO, 0)

func _on_real_envido_button_pressed() -> void:
	if truco_manager:
		truco_manager.call_envido(TrucoGame.EnvidoType.REAL_ENVIDO, 0)

func _on_falta_envido_button_pressed() -> void:
	if truco_manager:
		truco_manager.call_envido(TrucoGame.EnvidoType.FALTA_ENVIDO, 0)

## Handles Truco Button Press.
func _on_truco_button_pressed() -> void:
	if truco_manager:
		truco_manager.call_truco(0)

## Handles Response Button Press.
func _on_response_pressed(accepted: bool) -> void:
	if truco_manager:
		if truco_manager.pending_response_action == TrucoGame.ResponseAction.ENVIDO:
			truco_manager.resolve_envido(accepted, 0)
		elif truco_manager.pending_response_action == TrucoGame.ResponseAction.TRUCO:
			truco_manager.resolve_truco(accepted, 0)

func _on_envido_called(player_index: int) -> void:
	# If CPU (1) called, show response options to Human
	if player_index == 1:
		response_container.visible = true
		rival_calls_label.visible = true
		# Logic to determine WHAT was called (for display) could be improved by checking chain
		var last_call = truco_manager.envido_chain.back()

		# Replace "_" for " ", and make every first letter capital.
		var envido_text: String = TrucoGame.EnvidoType.keys()[last_call].replace("_", " ")
		var envido_text_capitalized: String = envido_text.capitalize()
		rival_calls_label.text = envido_text_capitalized + "!"
	else:
		# Human called, waiting for CPU (handled by TrucoCPUPlayerController)
		response_container.visible = false

func _on_truco_called(player_index: int, level: int) -> void:
	# If CPU (1) called, show response options to Human
	if player_index == 1:
		response_container.visible = true
		rival_calls_label.visible = true
		
		var call_text = "Truco!"
		match level:
			1: call_text = "Truco!"
			2: call_text = "Retruco!"
			3: call_text = "Vale 4!"
		
		rival_calls_label.text = call_text
	else:
		# Human called, waiting for CPU (handled by TrucoCPUPlayerController)
		response_container.visible = false

func _on_envido_resolved(accepted: bool, winner_index: int, points: int) -> void:
	response_container.visible = false
	rival_calls_label.visible = false
	print_debug("UI: Envido resolved. Points: %d to Player %d" % [points, winner_index])
	
	if accepted:
		var human_points: int = truco_manager.players[0].get_envido_points()
		var cpu_points: int = truco_manager.players[1].get_envido_points()
		
		if winner_index == 0:
			rival_decision_state_label.add_theme_color_override("font_color", Color(0, 255, 0))
			rival_decision_state_label.text = "You won the envido! (Yours: %d vs CPU: %d)" % [human_points, cpu_points]
		else:
			rival_decision_state_label.add_theme_color_override("font_color", Color(255, 0, 0))
			rival_decision_state_label.text = "CPU won the envido. (CPU: %d vs Yours: %d)" % [cpu_points, human_points]
	else:
		# If winner is Human (0), it means CPU rejected. If winner is CPU (1), Human rejected.
		if winner_index == 0:
			rival_decision_state_label.text = "CPU rejected the envido"
		else:
			rival_decision_state_label.text = "You rejected the envido"
		

func _on_truco_resolved(accepted: bool, player_index: int, current_level: int) -> void:
	response_container.visible = false
	rival_calls_label.visible = false

	# Reset color
	rival_decision_state_label.remove_theme_color_override("font_color")
	
	var level_name = "truco"
	match current_level:
		1: level_name = "truco"
		2: level_name = "retruco"
		3: level_name = "vale 4"
	
	if accepted:
		if player_index == 1:
			rival_decision_state_label.text = "CPU accepted the %s" % level_name
		else:
			rival_decision_state_label.text = "You accepted the %s" % level_name
	else:
		# player_index is who answered.
		# Note: current_level here is the APPROVED level if accepted, OR the PROPOSED level if rejected.
		# In resolve_truco logic I passed current_truco_level for both.
		# But wait, if rejected, current_truco_level reverts to previous? 
		# No, resolve_truco implementation: 
		# if accepted: passes current_truco_level (new)
		# if rejected: passes current_truco_level (old/unchanged).
		# BUT I want to say "CPU rejected the Retruco".
		# The signal was modified to pass `current_level`. Use that.
		if player_index == 1:
			rival_decision_state_label.text = "CPU rejected the %s" % level_name
		else:
			rival_decision_state_label.text = "You rejected the %s" % level_name

func _on_hand_started(_hand_num: int) -> void:
	response_container.visible = false
	rival_calls_label.visible = false
	rival_decision_state_label.text = ""
	rival_decision_state_label.remove_theme_color_override("font_color")
