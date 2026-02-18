class_name CPUFlorStrategy
extends RefCounted

## CPU strategy for Flor-related decisions.
## Handles when to call Flor and how to respond to opponent's Flor/ContraFlor.

var _manager: TrucoManager
var _player: Player

func _init(manager: TrucoManager, player: Player) -> void:
	_manager = manager
	_player = player


## Attempts to call Flor proactively during the CPU's turn.
## Returns true if a call was made.
func try_call(my_index: int) -> bool:
	if not _manager.can_call_flor(TrucoConstants.FlorType.FLOR, my_index):
		return false
	
	_manager.call_flor(TrucoConstants.FlorType.FLOR, my_index)
	return true


## Decides how to respond to an opponent's Flor call.
## [param type]: The FlorType of the call being responded to.
func decide_response(my_index: int, type: int) -> void:
	var has_flor: bool = _player.has_flor()
	
	# If we don't have flor, we acknowledge (accept the declaration)
	if not has_flor:
		_manager.resolve_flor(true, my_index)
		return
	
	# If opponent called ContraFlor
	if type == TrucoConstants.FlorType.CONTRA_FLOR:
		var p_envido = _player.get_envido_points()
		
		if p_envido >= 30:
			if _manager.can_call_flor(TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO, my_index):
				_manager.call_flor(TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO, my_index)
				return
				
		_manager.resolve_flor(true, my_index)
		return
		
	# If opponent called simple FLOR — we should call ContraFlor
	if _manager.can_call_flor(TrucoConstants.FlorType.CONTRA_FLOR, my_index):
		_manager.call_flor(TrucoConstants.FlorType.CONTRA_FLOR, my_index)
		return

	# Fallback
	_manager.resolve_flor(true, my_index)
