class_name TrucoUI
extends Control
## Main UI Controller for the Truco match.
## Handles visibility of buttons, labels, and updates interactions based on game state.

@onready var envido_value_label: Label = %EnvidoValueLabel
@onready var fold_button: Button = $MarginContainer2/HBoxContainer/FoldButton
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
@onready var flor_button: Button # Created dynamically or we can assume it doesn't exist in scene, so created in _ready


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
var response_flor_button: Button
var response_contra_flor_button: Button
var response_contra_flor_resto_button: Button
var response_con_flor_me_achico_button: Button

func _ready() -> void:
	# Connect to Hand signals
	if hand:
		hand.envido_calculated.connect(_on_envido_calculated)
		
	# Connect Fold Button
	fold_button.text = "Fold"
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
	
	# Create Flor Button
	flor_button = create_button("Flor", calls_vbox, _on_flor_button_pressed)
	calls_vbox.move_child(flor_button, 3) # After Falta Envido
	
	# Response Buttons (Raise)
	
	# Response Buttons (Raise)
	response_envido_button = create_button("Envido", response_vbox, _on_envido_button_pressed) # Same handler, calls logic checks
	response_real_envido_button = create_button("Real Envido", response_vbox, _on_real_envido_button_pressed)
	response_falta_envido_button = create_button("Falta Envido", response_vbox, _on_falta_envido_button_pressed)
	response_raise_truco_button = create_button("Retruco", response_vbox, _on_truco_button_pressed)
	
	# Response Buttons (Flor)
	response_flor_button = create_button("Flor", response_vbox, _on_flor_button_pressed)
	response_contra_flor_button = create_button("Contra Flor", response_vbox, _on_contra_flor_button_pressed)
	response_contra_flor_resto_button = create_button("Contra Flor Al Resto", response_vbox, _on_contra_flor_resto_button_pressed)
	response_con_flor_me_achico_button = create_button("Con Flor Me Achico", response_vbox, _on_con_flor_me_achico_pressed)
	
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
	# CALLS Container (Initial Calls)
	if envido_button:
		# If we have flor, envido shouldn't even appear.
		# Disable/Hide logic:
		var can_envido = truco_manager.can_call_envido(TrucoGame.EnvidoType.ENVIDO, 0) and truco_manager.envido_chain.is_empty()
		envido_button.visible = can_envido # Hide completely if not allowed (e.g. has flor)
		envido_button.disabled = not can_envido # Keep disabled just in case, but visibility handles "not appear"
		
	if real_envido_button:
		var can_real = truco_manager.can_call_envido(TrucoGame.EnvidoType.REAL_ENVIDO, 0) and truco_manager.envido_chain.is_empty()
		real_envido_button.visible = can_real
		real_envido_button.disabled = not can_real
		
	if falta_envido_button:
		var can_falta = truco_manager.can_call_envido(TrucoGame.EnvidoType.FALTA_ENVIDO, 0) and truco_manager.envido_chain.is_empty()
		falta_envido_button.visible = can_falta
		falta_envido_button.disabled = not can_falta

	# RESPONSE Container (Raising)
	if response_container.visible:
		if response_envido_button:
			response_envido_button.visible = truco_manager.can_call_envido(TrucoGame.EnvidoType.ENVIDO, 0)
		if response_real_envido_button:
			response_real_envido_button.visible = truco_manager.can_call_envido(TrucoGame.EnvidoType.REAL_ENVIDO, 0)
		if response_falta_envido_button:
			response_falta_envido_button.visible = truco_manager.can_call_envido(TrucoGame.EnvidoType.FALTA_ENVIDO, 0)

		# Flor Response Logic
		var can_call_flor = truco_manager.can_call_flor(TrucoGame.FlorType.FLOR, 0)
		var is_envido_response = (truco_manager.pending_response_action == TrucoGame.ResponseAction.ENVIDO)
		
		# If we have Flor during Envido response, we MUST call Flor. All other options disabled.
		if is_envido_response and can_call_flor:
			# Disable standard Envido responses
			quiero_button.visible = false
			no_quiero_button.visible = false
			if response_envido_button: response_envido_button.visible = false
			if response_real_envido_button: response_real_envido_button.visible = false
			if response_falta_envido_button: response_falta_envido_button.visible = false
			
			# Enable Flor response
			if response_flor_button: response_flor_button.visible = true
			if response_contra_flor_button: response_contra_flor_button.visible = false
			# Enable Flor response
			if response_flor_button: response_flor_button.visible = true
			if response_contra_flor_button: response_contra_flor_button.visible = false
			if response_contra_flor_resto_button: response_contra_flor_resto_button.visible = false
			if response_con_flor_me_achico_button: response_con_flor_me_achico_button.visible = false
			
		elif is_envido_response:
			# Normal envido response behavior
			if response_flor_button: response_flor_button.visible = false
			quiero_button.visible = true
			no_quiero_button.visible = true
			
		# Flor Challenge Responses (ContraFlor, etc)
		var is_flor_response = (truco_manager.pending_response_action == TrucoGame.ResponseAction.FLOR)
		if response_contra_flor_button:
			response_contra_flor_button.visible = is_flor_response and truco_manager.can_call_flor(TrucoGame.FlorType.CONTRA_FLOR, 0)
		if response_contra_flor_resto_button:
			response_contra_flor_resto_button.visible = is_flor_response and truco_manager.can_call_flor(TrucoGame.FlorType.CONTRA_FLOR_AL_RESTO, 0)
			
		if response_con_flor_me_achico_button:
			response_con_flor_me_achico_button.visible = false # Always hidden, replaced by strict Flor/Quiero logic
			
		# Con Flor Me Achico REMOVED.
		# If opponent called FLOR, and I have Flor -> "Flor" (Me too / Quiero), "ContraFlor", "Al Resto".
		# If opponent called CONTRAFLOR, ... -> "Quiero" (Accept), "No Quiero" (Decline).

		if is_flor_response:
			# Check what was the last call?
			var last_flor_call = truco_manager.game.flor_chain.back()
			
			if last_flor_call == TrucoGame.FlorType.FLOR:
				# Responding to Initial Flor
				# I MUST have Flor to be here? (Manager logic should block otherwise? No logic lets you see UI)
				# But wait, if I don't have Flor, I can't call anything.
				# The Manager logic `can_call_flor` handles if I have Flor.
				# If I have Flor: Show "Flor" (as Quiero), ContraFlor, Al Resto.
				# Validate if "Flor" button exists in RESPONSE container?
				# The variable is `response_flor_button`.
				# Wait, `response_flor_button` calls `call_flor(FLOR)`. 
				# If I want to ACKNOWLEDGE Flor (Quiero), I need `resolve_flor(true)`.
				# Using `quiero_button` for that.
				var has_flor: bool = truco_manager.can_call_flor(TrucoGame.FlorType.CONTRA_FLOR, 0) # Check if we have Flor (using ContraFlor check as proxy for having cards)
				
				if has_flor:
					# Show "Flor" (Quiero) and "ContraFlor" options
					if quiero_button:
						quiero_button.text = "Flor"
						quiero_button.visible = true
					
					# "No Quiero" makes no sense if we have Flor (we can't deny it). 
					# Unless "Me achico" means "I have Flor but I fold"? 
					# User said: "Con Flor Me achico should be Flor... visible when player effectively has flor".
					# This suggests removing the "Me achico" concept or merging it into "Flor"?
					# If I click "Flor" (Quiero), we compare points.
					# If I click "ContraFlor", we raise.
					# So I just need "Flor" and "ContraFlor".
					if no_quiero_button: no_quiero_button.visible = false
					
				else:
					# I don't have Flor.
					# I should see NOTHING? Or just Acknowledge?
					# User said: "that option should only be visible when the player effectively has flor".
					# If I don't have Flor, I concede 3 points.
					# I should essentially "Quiero" (meaning "Good, you won").
					if quiero_button:
						quiero_button.text = "Quiero" # Or "Bueno"
						quiero_button.visible = true
						
					if no_quiero_button: no_quiero_button.visible = false
					
				# Ensure other buttons are correct state
				if response_flor_button: response_flor_button.visible = false # Initial Flor call not allowed here
				
			else:
				# Responding to ContraFlor / Al Resto
				# Standard Accept/Decline
				quiero_button.visible = true
				no_quiero_button.visible = true
				if no_quiero_button: no_quiero_button.text = "No Quiero"
				if quiero_button: quiero_button.text = "Quiero"

		elif is_envido_response:
			if no_quiero_button: no_quiero_button.text = "No Quiero"
			if quiero_button: quiero_button.text = "Quiero"
		elif truco_manager.pending_response_action == TrucoGame.ResponseAction.TRUCO:
			if no_quiero_button:
				no_quiero_button.text = "No Quiero"
				no_quiero_button.visible = true
			if quiero_button:
				quiero_button.text = "Quiero"
				quiero_button.visible = true
			
			# Ensure flor buttons are hidden
			if response_flor_button: response_flor_button.visible = false
			if response_contra_flor_button: response_contra_flor_button.visible = false
			if response_contra_flor_resto_button: response_contra_flor_resto_button.visible = false
			
	# Main Flor Button
	if flor_button:
		# Visible if we can call it as an action
		var can_call = truco_manager.can_call_flor(TrucoGame.FlorType.FLOR, 0)
		flor_button.visible = can_call
		flor_button.disabled = not can_call

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

func _on_envido_calculated(score: int) -> void:
	if envido_value_label:
		envido_value_label.text = str(score)

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

func _on_flor_button_pressed() -> void:
	if truco_manager:
		truco_manager.call_flor(TrucoGame.FlorType.FLOR, 0)

func _on_contra_flor_button_pressed() -> void:
	if truco_manager:
		truco_manager.call_flor(TrucoGame.FlorType.CONTRA_FLOR, 0)

func _on_contra_flor_resto_button_pressed() -> void:
	if truco_manager:
		truco_manager.call_flor(TrucoGame.FlorType.CONTRA_FLOR_AL_RESTO, 0)

func _on_con_flor_me_achico_pressed() -> void:
	if truco_manager:
		# Equivalent to "No Quiero" on a pending Flor/ContraFlor
		truco_manager.resolve_flor(false, 0)


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
		elif truco_manager.pending_response_action == TrucoGame.ResponseAction.FLOR:
			truco_manager.resolve_flor(accepted, 0)

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

func _on_flor_called(player_index: int, type: int) -> void:
	if player_index == 1: # CPU Called
		response_container.visible = true
		rival_calls_label.visible = true
		
		var call_text = "Flor!"
		match type:
			TrucoGame.FlorType.FLOR: call_text = "Flor!"
			TrucoGame.FlorType.CONTRA_FLOR: call_text = "Contra Flor!"
			TrucoGame.FlorType.CONTRA_FLOR_AL_RESTO: call_text = "Contra Flor Al Resto!"
			
		rival_calls_label.text = call_text
	else:
		response_container.visible = false

func _on_flor_resolved(accepted: bool, winner_index: int, points: int) -> void:
	response_container.visible = false
	rival_calls_label.visible = false
	
	if accepted:
		if winner_index == 0:
			rival_decision_state_label.add_theme_color_override("font_color", Color(0, 255, 0))
			rival_decision_state_label.text = "You won the Flor! (+%d)" % points
		else:
			rival_decision_state_label.add_theme_color_override("font_color", Color(255, 0, 0))
			rival_decision_state_label.text = "CPU won the Flor. (+%d)" % points
	else:
		if winner_index == 0:
			rival_decision_state_label.text = "CPU achicó (folded floor)"
		else:
			rival_decision_state_label.text = "Te achicaste"

func _on_hand_started(_hand_num: int) -> void:
	response_container.visible = false
	rival_calls_label.visible = false
	rival_decision_state_label.text = ""
	rival_decision_state_label.remove_theme_color_override("font_color")
