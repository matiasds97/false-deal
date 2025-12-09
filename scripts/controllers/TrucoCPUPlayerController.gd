class_name TrucoCPUPlayerController
extends TrucoPlayerController

# @export var rival_hand_visual: RivalHand # Removed: Decoupled via SignalBus

@onready var truco_manager: TrucoManager = $"../TrucoManager"

var _waiting_for_response: bool = false

func _ready() -> void:
	TrucoSignalBus.on_envido_resolved.connect(_on_envido_resolved)
	TrucoSignalBus.on_truco_resolved.connect(_on_truco_resolved)

func start_turn() -> void:
	super.start_turn()
	_waiting_for_response = false
	# Simulate thinking time
	get_tree().create_timer(1.0).timeout.connect(_make_decision)

func _make_decision() -> void:
	if _waiting_for_response:
		return

	# 1. Check for Envido Chance
	# Assuming CPU is player index 1 (or we can get it from player.team/index logic if we added it, but forcing 1 for now or asking manager)
	# For simplicity, we check if WE can call it.
	# We need our index: TrucoManager players array: Human=0, CPU=1.
	var my_index = 1
	
	if truco_manager and truco_manager.can_call_envido(my_index):
		var points = player.get_envido_points()
		# Simple logic: Call if points > 27 or small chance of bluff
		var should_call = points >= 26 or (randf() < 0.1)
		
		if should_call:
			print("CPU Decided to call Envido with %d points" % points)
			emit_signal("envido_called")
			_waiting_for_response = true
			return # Stop here, wait for resolution

	# 2. Check for Truco Chance
	if truco_manager and truco_manager.can_call_truco(my_index):
		# Simple logic: random chance to call Truco if having high card or bluff
		# Real logic would check hand strength
		var has_ace_swords = false # Placeholder logic
		var should_call_truco = (randf() < 0.15)
		
		if should_call_truco:
			print("CPU Decided to call Truco!")
			emit_signal("truco_called")
			_waiting_for_response = true
			return

	# 3. Play Card
	if player.hand.size() > 0:
		var card_to_play: Card = player.hand[0]
		
		# Emit signal first so TrucoManager adds card to table (and SignalBus notifies visuals)
		emit_signal("card_played", card_to_play)
		print("CPU played: " + str(card_to_play))

func _on_envido_resolved(_accepted: bool, _winner_index: int, _points: int) -> void:
	# If we were waiting (meaning we called it, or maybe we answered it?)
	# Use a small delay to resume so it doesn't look instant
	if _waiting_for_response:
		_waiting_for_response = false
		get_tree().create_timer(1.5).timeout.connect(_make_decision)

func _on_truco_resolved(accepted: bool, _player_index: int) -> void:
	# If accepted, we continue playing. If rejected, round ends so this logic matters less but good to reset.
	if _waiting_for_response and accepted:
		_waiting_for_response = false
		get_tree().create_timer(1.5).timeout.connect(_make_decision)
