class_name CPUEnvidoStrategy
extends RefCounted

## CPU strategy for Envido-related decisions.
## Handles when to call Envido proactively and how to respond to opponent's Envido.

var _manager: TrucoManager
var _player: Player
var _bluff_factor: float

func _init(manager: TrucoManager, player: Player, bluff_factor: float) -> void:
	_manager = manager
	_player = player
	_bluff_factor = bluff_factor


## Attempts to call Envido proactively during the CPU's turn.
## Returns true if a call was made.
func try_call(my_index: int) -> bool:
	if not _manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index):
		return false
		
	var points: int = _player.get_envido_points()
	var should_call: bool = points >= 26 or (_bluff_factor < 0.15)
	
	if should_call:
		if points >= 30 and randf() > 0.5:
			_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index)
		else:
			_manager.call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index)
		return true
		
	return false


## Decides how to respond to an opponent's Envido call.
func decide_response(my_index: int) -> void:
	var points: int = _player.get_envido_points()
	
	# Check for Flor Override — must call Flor in response to Envido if we have it
	if _player.has_flor():
		if _manager.can_call_flor(TrucoConstants.FlorType.FLOR, my_index):
			_manager.call_flor(TrucoConstants.FlorType.FLOR, my_index)
			return
	
	# High Points Strategy or Aggressive Bluff
	if points >= 30 or _bluff_factor < 0.1:
		if _manager.can_call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, my_index):
			_manager.call_envido(TrucoConstants.EnvidoType.FALTA_ENVIDO, my_index)
			return
		elif _manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index):
			_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index)
			return
		elif _manager.can_call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index):
			_manager.call_envido(TrucoConstants.EnvidoType.ENVIDO, my_index)
			return
			
	# Medium Points Strategy: Accept or Raise slightly
	if points >= 27:
		if _manager.can_call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index) and randf() > 0.6:
			_manager.call_envido(TrucoConstants.EnvidoType.REAL_ENVIDO, my_index)
			return
		_manager.resolve_envido(true, my_index)
		return
	
	# Low Points Strategy: Accept if decent (24-26)
	if points >= 24:
		_manager.resolve_envido(true, my_index)
		return
		
	# Bad Points: Reject
	_manager.resolve_envido(false, my_index)
