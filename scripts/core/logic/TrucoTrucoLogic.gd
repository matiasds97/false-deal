class_name TrucoTrucoLogic
extends RefCounted

## Handles all Truco betting logic (Truco, Retruco, Vale 4).
## This includes calling, resolving, and calculating stakes.

# --- SIGNALS ---
signal truco_called(player_index: int, level: int)
signal truco_resolved(accepted: bool, winner_index: int, level: int)

# --- ENUMS ---
enum TrucoCallState {
	NONE,
	CALLED,
	PLAYED,
	TRUCO,
	RETRUCO,
	VALE_4 # Max level
}

# --- CONSTANTS ---
const MAX_LEVEL: int = 3 # Vale 4

# --- STATE ---
var state: int = TrucoCallState.NONE
var current_level: int = 0 # 0=None, 1=Truco, 2=Retruco, 3=Vale 4
var proposed_level: int = 0
var caller_index: int = -1 # Who called the current/proposed level

# --- REFERENCES ---
var _game: RefCounted # TrucoGame

func _init(game: RefCounted) -> void:
	_game = game

## Resets the truco state for a new hand.
func reset() -> void:
	state = TrucoCallState.NONE
	current_level = 0
	proposed_level = 0
	caller_index = -1

## Returns the current stakes based on truco level.
func get_current_stakes() -> int:
	if current_level == 0:
		return 1
	return current_level + 1 # Truco=2, Retruco=3, Vale4=4

## Checks if a player can call truco.
## [param player_index]: The player index.
## [param flor_state]: Current flor state from the game.
## [param pending_action]: Current pending response action.
## [return] true if the player can call truco, false otherwise.
func can_call(
	player_index: int,
	flor_state: int,
	pending_action: int
) -> bool:
	const FlorState_NONE = 0
	const FlorState_PLAYED = 2
	const ResponseAction_NONE = 0
	const ResponseAction_TRUCO = 2
	
	# No calling if Flor is active (not NONE and not PLAYED)
	if flor_state != FlorState_NONE and flor_state != FlorState_PLAYED:
		return false

	if pending_action == ResponseAction_NONE:
		if current_level == 0:
			return true
		if current_level > 0 and current_level < MAX_LEVEL:
			# Only opponent of last caller can raise
			return caller_index != player_index
	elif pending_action == ResponseAction_TRUCO:
		# Can raise if opponent of caller
		if player_index != caller_index:
			return proposed_level < MAX_LEVEL
			
	return false

## Calls truco. Returns the new proposed level.
## [param player_index]: The player calling.
## [param pending_action]: Current pending response action.
## [return] The proposed level after calling.
func call_truco(player_index: int, pending_action: int) -> int:
	const ResponseAction_TRUCO = 2
	
	var next_level: int = 1
	if pending_action == ResponseAction_TRUCO:
		next_level = proposed_level + 1
	else:
		next_level = current_level + 1
		
	state = TrucoCallState.CALLED
	proposed_level = next_level
	caller_index = player_index
	
	truco_called.emit(player_index, next_level)
	return next_level

## Resolves the truco call.
## [param accepted]: Whether the call was accepted.
## [param answering_player_index]: The player who answered.
## [return] Dictionary with "winner", "points", and "round_ends" keys.
func resolve(accepted: bool, answering_player_index: int) -> Dictionary:
	var result = {
		"winner": - 1,
		"points": 0,
		"round_ends": false,
		"level": proposed_level
	}
	
	if accepted:
		state = TrucoCallState.PLAYED
		current_level = proposed_level
		result["winner"] = answering_player_index
		result["points"] = 0 # No points awarded on accept, just higher stakes
		truco_resolved.emit(true, answering_player_index, current_level)
	else:
		result["winner"] = caller_index
		result["points"] = proposed_level # Points equal to rejected level
		result["round_ends"] = true
		truco_resolved.emit(false, answering_player_index, proposed_level)
	
	return result
