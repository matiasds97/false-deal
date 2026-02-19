class_name CPUTrucoStrategy
extends RefCounted

## CPU strategy for Truco-related decisions.
## Handles when to call Truco proactively and how to respond to opponent's Truco.
## Uses CPUBrain for all decision-making parameters.

var _manager: TrucoManager
var _player: Player
var _brain: CPUBrain

func _init(manager: TrucoManager, player: Player, brain: CPUBrain) -> void:
	_manager = manager
	_player = player
	_brain = brain


## Attempts to call Truco proactively during the CPU's turn.
## Returns true if a call was made.
func try_call(my_index: int) -> bool:
	if not _manager.can_call_truco(my_index):
		return false

	var params: CPUBrain.EffectiveParams = _brain.get_effective_params()

	# Info-seeking: high info_seeking CPU waits before calling truco
	if params.info_seeking > 0.7 and randf() < params.info_seeking * 0.4:
		return false

	# Base probability from truco_call_rate + aggression boost
	var call_probability: float = params.truco_call_rate + params.aggression * 0.1

	# Risk tolerance: reduce call probability if we're winning comfortably
	if params.risk_tolerance < 0.3:
		call_probability *= 0.5

	var should_call: bool = randf() < call_probability

	# Bluff: may call even without good reason
	if not should_call and randf() < params.bluff_tendency * 0.2:
		should_call = true

	# Apply noise
	should_call = _brain.apply_noise(should_call)

	if should_call:
		_manager.call_truco(my_index)
		return true

	return false


## Decides how to respond to an opponent's Truco call.
## Includes the "Envido First" rule — may call Envido to interrupt Truco.
func decide_response(my_index: int) -> void:
	var params: CPUBrain.EffectiveParams = _brain.get_effective_params()

	# "Envido First" rule: can call Envido during a Truco challenge
	if _manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index):
		var actual_points: int = _player.get_envido_points()
		var perceived_points: int = _brain.perceive_points(actual_points, params.hand_evaluation_accuracy)

		var envido_threshold: int = roundi(lerpf(20.0, 30.0, params.envido_threshold))
		var wants_envido: bool = perceived_points >= envido_threshold or randf() < params.bluff_tendency * 0.2

		if wants_envido:
			if perceived_points > 30 and params.aggression > 0.5:
				if _manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index):
					_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index)
					return
			_manager.call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index)
			return

	# Accept/Reject/Raise decision
	# Fold resistance: base acceptance
	var accept_chance: float = params.fold_resistance * 0.6 + params.aggression * 0.2
	var wants_to_accept: bool = randf() < accept_chance

	# Bluff: accept even when we probably shouldn't
	if not wants_to_accept and randf() < params.bluff_tendency * 0.15:
		wants_to_accept = true

	# Apply noise
	wants_to_accept = _brain.apply_noise(wants_to_accept)

	if not wants_to_accept:
		_manager.resolve_truco(false, my_index)
		return

	# Try to raise instead of just accepting
	var wants_to_raise: bool = randf() < params.raise_tendency * 0.5
	if wants_to_raise and _manager.can_call_truco(my_index):
		_manager.call_truco(my_index)
	else:
		_manager.resolve_truco(true, my_index)
