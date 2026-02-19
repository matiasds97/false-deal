class_name CPUEnvidoStrategy
extends RefCounted

## CPU strategy for Envido-related decisions.
## Handles when to call Envido proactively and how to respond to opponent's Envido.
## Uses CPUBrain for all decision-making parameters.

var _manager: TrucoManager
var _player: Player
var _brain: CPUBrain

signal voice_required(voice_key: String)

func _init(manager: TrucoManager, player: Player, brain: CPUBrain) -> void:
	_manager = manager
	_player = player
	_brain = brain


## Attempts to call Envido proactively during the CPU's turn.
## Returns true if a call was made.
func try_call(my_index: int) -> bool:
	if not _manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index):
		return false

	var params: CPUBrain.EffectiveParams = _brain.get_effective_params()

	# Info-seeking: high info_seeking CPU prefers to wait
	if params.info_seeking > 0.6 and randf() < params.info_seeking * 0.5:
		return false

	var actual_points: int = _player.get_envido_points()
	var perceived_points: int = _brain.perceive_points(actual_points, params.hand_evaluation_accuracy)

	# Threshold: maps envido_threshold [0,1] → required points [20, 33]
	var threshold: int = roundi(lerpf(20.0, 33.0, params.envido_threshold))
	var should_call: bool = perceived_points >= threshold

	# Bluff: may call even with bad hand
	if not should_call and randf() < params.bluff_tendency * 0.3:
		should_call = true

	# Decision noise can flip
	should_call = _brain.apply_noise(should_call)

	if should_call:
		# Decide which type to call based on aggression + raise_tendency
		if perceived_points >= 30 and randf() < params.aggression * 0.7:
			if _manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index):
				voice_required.emit("real_envido")
				_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index)
				return true
		voice_required.emit("envido")
		_manager.call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index)
		return true

	return false


## Decides how to respond to an opponent's Envido call.
func decide_response(my_index: int) -> void:
	var params: CPUBrain.EffectiveParams = _brain.get_effective_params()
	var actual_points: int = _player.get_envido_points()
	var perceived_points: int = _brain.perceive_points(actual_points, params.hand_evaluation_accuracy)

	# Check for Flor Override — must call Flor in response to Envido if we have it
	if _player.has_flor():
		if _manager.can_call_flor(TrucoConstants.FlorType.FLOR, my_index):
			_manager.call_flor(TrucoConstants.FlorType.FLOR, my_index)
			return

	# High points or aggressive bluff → try to raise
	var wants_to_raise: bool = perceived_points >= 30 or randf() < params.bluff_tendency * 0.15
	wants_to_raise = wants_to_raise and randf() < params.raise_tendency

	if wants_to_raise:
		if _manager.can_call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, my_index):
			voice_required.emit("falta_envido")
			_manager.call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, my_index)
			return
		elif _manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index):
			voice_required.emit("real_envido")
			_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index)
			return
		elif _manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index):
			voice_required.emit("envido")
			_manager.call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index)
			return

	# Medium-tier raise: good points + some raise tendency
	if perceived_points >= 27 and randf() < params.raise_tendency * 0.6:
		if _manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index):
			voice_required.emit("real_envido")
			_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index)
			return

	# Accept/Reject decision based on threshold
	var accept_threshold: int = roundi(lerpf(20.0, 30.0, params.envido_threshold))
	var wants_to_accept: bool = perceived_points >= accept_threshold

	# Fold resistance: makes it harder to reject
	if not wants_to_accept and randf() < params.fold_resistance * 0.3:
		wants_to_accept = true

	# Apply noise
	wants_to_accept = _brain.apply_noise(wants_to_accept)

	if wants_to_accept:
		voice_required.emit("quiero")
	else:
		voice_required.emit("no_quiero")

	_manager.resolve_envido(wants_to_accept, my_index)
