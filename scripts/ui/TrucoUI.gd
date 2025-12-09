extends Control

@onready var envido_value_label: Label = %EnvidoValueLabel
@onready var flor_container: PanelContainer = %FlorContainer
@onready var deal_button: Button = $MarginContainer2/PanelContainer/HBoxContainer/DealButton
@onready var hand: Marker3D = $"../HumanHand"
@onready var cpu_hand: Node3D = $"../CPUHand"
@onready var truco_manager: TrucoManager = $"../TrucoManager"
@onready var score_label: Label = $ScoreContainer/VBoxContainer/ScoreContainer/HBoxContainer/ScoreLabel
@onready var rival_calls_label: Label = %RivalCallsLabel
@onready var rival_decision_state_label: Label = %RivalDecisionStateLabel

# Calls UI
@onready var envido_button: Button = $CallsContainer/VBoxContainer/EnvidoButton
@onready var truco_button: Button = $CallsContainer/VBoxContainer/TrucoButton
@onready var response_container: MarginContainer = $ResponseContainer
@onready var quiero_button: Button = $ResponseContainer/VBoxContainer/QuieroButton
@onready var no_quiero_button: Button = $ResponseContainer/VBoxContainer/NoQuieroButton

func _ready() -> void:
	# Connect to Hand signals
	if hand:
		hand.envido_calculated.connect(_on_envido_calculated)
		hand.flor_detected.connect(_on_flor_detected)
		
	# Connect Deal Button to deal new hand
	deal_button.pressed.connect(_on_deal_button_pressed)
	
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
	if truco_button:
		truco_button.pressed.connect(_on_truco_button_pressed)
	if quiero_button:
		quiero_button.pressed.connect(_on_response_pressed.bind(true))
	if no_quiero_button:
		no_quiero_button.pressed.connect(_on_response_pressed.bind(false))
		
	# Initial State
	response_container.visible = false

func _process(_delta: float) -> void:
	# Keep Envido button available only if valid
	if truco_manager and envido_button:
		# We check if we are in valid state to call it
		# Optimization: Don't check every frame if performance bad, but for UI button validity it's fine for now
		if envido_button.disabled != (not truco_manager.can_call_envido(0)):
			# Update disabled state
			envido_button.disabled = not truco_manager.can_call_envido(0)
			
	if truco_manager and truco_button:
		if truco_button.disabled != (not truco_manager.can_call_truco(0)):
			truco_button.disabled = not truco_manager.can_call_truco(0)

func _on_score_updated(human_score: int, cpu_score: int) -> void:
	if score_label:
		score_label.text = "Human: %d | CPU: %d" % [human_score, cpu_score]

func _on_deal_button_pressed() -> void:
	# Reset visual hands
	if hand and hand.has_method("deal_new_hand"):
		hand.deal_new_hand()
	if cpu_hand and cpu_hand.has_method("reset_hand"):
		cpu_hand.reset_hand()
	
	# Start new hand in TrucoManager
	if truco_manager:
		truco_manager.start_new_hand()
	else:
		printerr("TrucoManager not found!")

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
		truco_manager.call_envido(0) # 0 is Human

## Handles Truco Button Press.
func _on_truco_button_pressed() -> void:
	if truco_manager:
		truco_manager.call_truco(0)

## Handles Response Button Press.
func _on_response_pressed(accepted: bool) -> void:
	if truco_manager:
		if truco_manager.pending_response_action == TrucoManager.ResponseAction.ENVIDO:
			truco_manager.resolve_envido(accepted, 0)
		elif truco_manager.pending_response_action == TrucoManager.ResponseAction.TRUCO:
			truco_manager.resolve_truco(accepted, 0)

func _on_envido_called(player_index: int) -> void:
	# If CPU (1) called, show response options to Human
	if player_index == 1:
		response_container.visible = true
		rival_calls_label.visible = true
		rival_calls_label.text = "Envido!"
	else:
		# Human called, waiting for CPU
		response_container.visible = false
		get_tree().create_timer(1.0).timeout.connect(func():
			var cpu_wants = randf() > 0.3
			truco_manager.resolve_envido(cpu_wants, 1)
		)

func _on_truco_called(player_index: int) -> void:
	# If CPU (1) called, show response options to Human
	if player_index == 1:
		response_container.visible = true
		rival_calls_label.visible = true
		rival_calls_label.text = "Truco!"
	else:
		# Human called, waiting for CPU
		response_container.visible = false
		get_tree().create_timer(1.0).timeout.connect(func():
			var cpu_wants = randf() > 0.3
			truco_manager.resolve_truco(cpu_wants, 1)
		)

func _on_envido_resolved(accepted: bool, winner_index: int, points: int) -> void:
	response_container.visible = false
	rival_calls_label.visible = false
	print("UI: Envido resolved. Points: %d to Player %d" % [points, winner_index])
	
	if accepted:
		var human_points = truco_manager.players[0].get_envido_points()
		var cpu_points = truco_manager.players[1].get_envido_points()
		
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
		

func _on_truco_resolved(accepted: bool, player_index: int) -> void:
	response_container.visible = false
	rival_calls_label.visible = false

	# Reset color
	rival_decision_state_label.remove_theme_color_override("font_color")
	
	if accepted:
		if player_index == 1:
			rival_decision_state_label.text = "CPU accepted the truco"
		else:
			rival_decision_state_label.text = "You accepted the truco"
	else:
		# player_index is who answered.
		if player_index == 1:
			rival_decision_state_label.text = "CPU rejected the truco"
		else:
			rival_decision_state_label.text = "You rejected the truco"

func _on_hand_started(_hand_num: int) -> void:
	response_container.visible = false
	rival_calls_label.visible = false
	rival_decision_state_label.text = ""
	rival_decision_state_label.remove_theme_color_override("font_color")
