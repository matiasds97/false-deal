class_name CPUFlorStrategy
extends RefCounted

## CPU strategy for Flor-related decisions.
## Handles when to call Flor and how to respond to opponent's Flor/ContraFlor.
## Uses CPUBrain for all decision-making parameters.

var _manager: TrucoManager
var _player: Player
var _brain: CPUBrain

signal voice_required(voice_key: String)

func _init(manager: TrucoManager, player: Player, brain: CPUBrain) -> void:
	_manager = manager
	_player = player
	_brain = brain


## Attempts to call Flor proactively during the CPU's turn.
## Returns true if a call was made.
func try_call(my_index: int) -> bool:
	if not _manager.can_call_flor(TrucoConstants.FlorType.FLOR, my_index):
		return false

	# Flor is mandatory to declare when you have it — always call.
	voice_required.emit("flor")
	_manager.call_flor(TrucoConstants.FlorType.FLOR, my_index)
	return true


## Decides how to respond to an opponent's Flor call.
## [param type]: The FlorType of the call being responded to.
func decide_response(my_index: int, type: int) -> void:
	var has_flor: bool = _player.has_flor()

	# If we don't have flor, we acknowledge (accept the declaration)
	if not has_flor:
		# Just acknowledge points
		# voice_required.emit("quiero") # Optional, but maybe silent is better if just acknowledging points without contest
		_manager.resolve_flor(true, my_index)
		return

	var params: CPUBrain.EffectiveParams = _brain.get_effective_params()
	var actual_points: int = _player.get_envido_points()
	var perceived_points: int = _brain.perceive_points(actual_points, params.hand_evaluation_accuracy)

	# If opponent called ContraFlor
	if type == TrucoConstants.FlorType.CONTRA_FLOR:
		# Only raise to ContraFlor al Resto with strong flor + aggression
		if perceived_points >= 30 and randf() < params.raise_tendency:
			if _manager.can_call_flor(TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO, my_index):
				voice_required.emit("contra_flor")
				_manager.call_flor(TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO, my_index)
				return

		# Accept or reject ContraFlor based on fold resistance + perceived strength
		var wants_to_accept: bool = perceived_points >= 26 or randf() < params.fold_resistance * 0.4
		wants_to_accept = _brain.apply_noise(wants_to_accept)
		
		if wants_to_accept:
			voice_required.emit("quiero")
		else:
			voice_required.emit("no_quiero")

		_manager.resolve_flor(wants_to_accept, my_index)
		return

	# If opponent called simple FLOR — decide whether to raise to ContraFlor
	var wants_to_raise: bool = randf() < params.aggression * 0.5 + params.raise_tendency * 0.3
	if perceived_points >= 28:
		wants_to_raise = true

	wants_to_raise = _brain.apply_noise(wants_to_raise)

	if wants_to_raise and _manager.can_call_flor(TrucoConstants.FlorType.CONTRA_FLOR, my_index):
		voice_required.emit("contra_flor")
		_manager.call_flor(TrucoConstants.FlorType.CONTRA_FLOR, my_index)
		return

	# Fallback: accept (We have flor too)
	voice_required.emit("flor")
	_manager.resolve_flor(true, my_index)
