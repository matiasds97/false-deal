class_name TrucoCPUPlayerController
extends TrucoPlayerController
## Controls the AI opponent's actions, including playing cards and making/responding to calls.

@onready var truco_manager: TrucoManager = $"../TrucoManager"

## Whether we are waiting for a response from the opponent.
var _waiting_for_response: bool = false

## Simple bluff factor for this hand (could be randomized per hand start)
## In the future it should be parameterized for every different opponent.
var _bluff_factor: float = 0.0

## Token used to prevent race conditions by invalidating old scheduled 
## decisions if a new one is made.
var _decision_token: int = 0

func _ready() -> void:
	TrucoSignalBus.on_envido_resolved.connect(_on_envido_resolved)
	TrucoSignalBus.on_truco_resolved.connect(_on_truco_resolved)
	TrucoSignalBus.on_envido_called.connect(_on_envido_called)
	TrucoSignalBus.on_truco_called.connect(_on_truco_called_by_opponent)
	
	_bluff_factor = randf()

func start_turn() -> void:
	super.start_turn()
	_waiting_for_response = false
	_schedule_decision(1.0)

## Schedules a decision to be made after a delay,
## invalidating any previous pending decisions. [br]
## [delay]: The delay in seconds before the decision is made.
func _schedule_decision(delay: float) -> void:
	_decision_token += 1
	var current_token: int = _decision_token
	get_tree().create_timer(delay).timeout.connect(_make_decision.bind(current_token))

func _make_decision(token: int) -> void:
	# Validation: Check if token is valid, if we are waiting, and if it is OUR turn
	if token != _decision_token: return
	if _waiting_for_response: return
	
	if truco_manager and truco_manager.current_turn_index != 1:
		return

	# 1. Try to call Envido
	if _try_call_envido(1): return

	# 2. Try to call Truco
	if _try_call_truco(1): return

	# 3. Play a Card
	_play_card()

## Attempts to call Envido if rules allow and strategy dictates.
## Returns true if an action was taken (call made).
func _try_call_envido(my_index: int) -> bool:
	if not truco_manager.can_call_envido(TrucoManager.EnvidoType.ENVIDO, my_index):
		return false
		
	var points: int = player.get_envido_points()
	# Simple logic: Call if points > 27 or small chance of bluff
	var should_call: bool = points >= 26 or (_bluff_factor < 0.15)
	
	if should_call:
		print_debug("CPU Decided to call Envido with %d points" % points)
		# Randomly choose between Envido and Real Envido if points are super high
		if points >= 30 and randf() > 0.5:
			truco_manager.call_envido(TrucoManager.EnvidoType.REAL_ENVIDO, my_index)
		else:
			truco_manager.call_envido(TrucoManager.EnvidoType.ENVIDO, my_index)
			
		_waiting_for_response = true
		return true
		
	return false

## Attempts to call Truco if rules allow and strategy dictates.
## Returns true if an action was taken.
func _try_call_truco(my_index: int) -> bool:
	if not truco_manager.can_call_truco(my_index):
		return false
		
	# Simple logic: random chance to call Truco if having high card or bluff
	# Real logic would check hand strength
	var should_call_truco: bool = (randf() < 0.15)
	
	if should_call_truco:
		print_debug("CPU Decided to call Truco!")
		truco_manager.call_truco(my_index)
		_waiting_for_response = true
		return true
		
	return false

## Plays the first available card (basic strategy).
func _play_card() -> void:
	if player.hand.size() > 0:
		var card_to_play: Card = player.hand[0]
		emit_signal("card_played", card_to_play)
		print_debug("CPU played: " + str(card_to_play))

func _on_envido_called(caller_index: int) -> void:
	if _caller_was_CPU(caller_index):
		return
	
	_waiting_for_response = true
	
	# Simulate thought
	get_tree().create_timer(1.0 + randf()).timeout.connect(func():
		_decide_envido_response()
	)

func _caller_was_CPU(caller_index: int) -> bool:
	return caller_index == 1

## Decides how to respond to an opponent's Envido call.
func _decide_envido_response() -> void:
	var my_index: int = 1
	var points: int = player.get_envido_points()
	
	print_debug("CPU considering Envido response. Points: %d" % points)
	
	# High Points Strategy or Aggressive Bluff
	if points >= 30 or _bluff_factor < 0.1:
		# If we can raise to Falta Envido, do it?
		if truco_manager.can_call_envido(TrucoManager.EnvidoType.FALTA_ENVIDO, my_index):
			print_debug("CPU Raising to Falta Envido!")
			truco_manager.call_envido(TrucoManager.EnvidoType.FALTA_ENVIDO, my_index)
			return
		elif truco_manager.can_call_envido(TrucoManager.EnvidoType.REAL_ENVIDO, my_index):
			print_debug("CPU Raising to Real Envido!")
			truco_manager.call_envido(TrucoManager.EnvidoType.REAL_ENVIDO, my_index)
			return
		elif truco_manager.can_call_envido(TrucoManager.EnvidoType.ENVIDO, my_index): # Envido-Envido
			print_debug("CPU Raising to Envido-Envido!")
			truco_manager.call_envido(TrucoManager.EnvidoType.ENVIDO, my_index)
			return
			
	# Medium Points Strategy: Accept or Raise slightly
	if points >= 27:
		# If opponent called simple Envido, maybe raise to Real?
		if truco_manager.can_call_envido(TrucoManager.EnvidoType.REAL_ENVIDO, my_index) and randf() > 0.6:
			truco_manager.call_envido(TrucoManager.EnvidoType.REAL_ENVIDO, my_index)
			return
		
		# Otherwise just Accept
		print_debug("CPU Accepted Envido")
		truco_manager.resolve_envido(true, my_index)
		return
	
	# Low Points Strategy: Reject or Accepted if decent (24-26)
	if points >= 24:
		# Accept
		print_debug("CPU Accepted Envido (Low-Mid points)")
		truco_manager.resolve_envido(true, my_index)
		return
		
	# Bad Points: Reject
	print_debug("CPU Rejected Envido")
	truco_manager.resolve_envido(false, my_index)
	# Note: TrucoManager handles the state reset, but we are still waiting for turn or resolution?
	# _waiting_for_response will be cleared by _on_envido_resolved callback

func _on_truco_called_by_opponent(caller_index: int) -> void:
	# If WE called it, ignore.
	if caller_index == 1: return
	
	_waiting_for_response = true
	
	# Simulate thought
	get_tree().create_timer(1.0 + randf()).timeout.connect(func():
		_decide_truco_response()
	)

## Decides how to respond to an opponent's Truco call.
func _decide_truco_response() -> void:
	var my_index: int = 1
	print_debug("CPU considering Truco response.")
	
	# Simple strategy based on bluff factor or random for now
	# In a real implementation we would evaluate hand strength (Ancho de espatas, etc)
	# For now: 15% Reject, 85% Accept/Raise
	
	var roll: float = randf()
	
	if roll < 0.15 and _bluff_factor < 0.5:
		print_debug("CPU Rejected Truco")
		truco_manager.resolve_truco(false, my_index)
	else:
		# Accept
		print_debug("CPU Accepted Truco")
		truco_manager.resolve_truco(true, my_index)
		# TODO: Implement Retruco logic here later

func _on_envido_resolved(_accepted: bool, _winner_index: int, _points: int) -> void:
	# If we were waiting (meaning we called it, or maybe we answered it?)
	# Use a small delay to resume so it doesn't look instant
	if _waiting_for_response:
		_waiting_for_response = false
		_schedule_decision(1.5)

func _on_truco_resolved(accepted: bool, _player_index: int) -> void:
	# If accepted, we continue playing. If rejected, round ends so this logic matters less but good to reset.
	if _waiting_for_response and accepted:
		_waiting_for_response = false
		_schedule_decision(1.5)
