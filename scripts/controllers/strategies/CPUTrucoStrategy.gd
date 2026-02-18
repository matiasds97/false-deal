class_name CPUTrucoStrategy
extends RefCounted

## CPU strategy for Truco-related decisions.
## Handles when to call Truco proactively and how to respond to opponent's Truco.

var _manager: TrucoManager
var _player: Player
var _bluff_factor: float

func _init(manager: TrucoManager, player: Player, bluff_factor: float) -> void:
	_manager = manager
	_player = player
	_bluff_factor = bluff_factor

## Attempts to call Truco proactively during the CPU's turn.
## Returns true if a call was made.
func try_call(my_index: int) -> bool:
	if not _manager.can_call_truco(my_index):
		return false
		
	var should_call: bool = (randf() < 0.15)
	
	if should_call:
		_manager.call_truco(my_index)
		return true
		
	return false


## Decides how to respond to an opponent's Truco call.
## Includes the "Envido First" rule — may call Envido to interrupt Truco.
func decide_response(my_index: int) -> void:
	# "Envido First" rule: can call Envido during a Truco challenge
	if _manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index):
		var points = _player.get_envido_points()
		if points > 25 or (_bluff_factor < 0.2):
			if points > 30:
				if _manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index):
					_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index)
				else:
					_manager.call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index)
			else:
				_manager.call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index)
			return
	
	# Simple strategy based on bluff factor
	# 15% Reject, 85% Accept/Raise
	var roll: float = randf()
	
	if roll < 0.15 and _bluff_factor < 0.5:
		_manager.resolve_truco(false, my_index)
	else:
		# Accept or Raise?
		var wants_to_raise = (_bluff_factor > 0.7 or randf() > 0.8)
		var can_raise = _manager.can_call_truco(my_index)
		
		if wants_to_raise and can_raise:
			_manager.call_truco(my_index)
		else:
			_manager.resolve_truco(true, my_index)
