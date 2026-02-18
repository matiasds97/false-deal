class_name TrucoEnvidoLogic
extends RefCounted

## Handles all Envido-related logic for the Truco game.
## This includes calling, resolving, and calculating points for Envido.

# --- SIGNALS ---
signal envido_called(player_index: int, type: int)
signal envido_resolved(accepted: bool, winner_index: int, points: int)

# --- ENUMS ---
# Enum EnvidoType moved to TrucoConstants

enum EnvidoCallState {
	NONE,
	CALLED,
	PLAYED
}

# --- STATE ---
var state: int = EnvidoCallState.NONE
var chain: Array[int] = [] # Array of EnvidoType

# --- REFERENCES ---
## Reference to the main game for accessing players, scores, etc.
var _game: RefCounted # TrucoGame (avoiding circular reference by using RefCounted)

func _init(game: RefCounted) -> void:
	_game = game

## Resets the envido state for a new hand.
func reset() -> void:
	state = EnvidoCallState.NONE
	chain.clear()

## Checks if a player can call envido.
## [param type]: The type of envido to call (EnvidoType).
## [param player_index]: The player index.
## [param flor_state]: Current flor state from the game.
## [param has_flor]: Whether the player has flor.
## [param vuelta_count]: Number of vueltas completed.
## [param truco_state]: Current truco call state.
## [param pending_action]: Current pending response action.
## [param proposed_truco_level]: The proposed truco level if any.
## [return] true if the player can call envido, false otherwise.
func can_call(
	type: int,
	_player_index: int,
	flor_state: int,
	has_flor: bool,
	vuelta_count: int,
	truco_state: int,
	pending_action: int,
	proposed_truco_level: int
) -> bool:
	# 0. Flor cancels Envido interactions if Flor is active
	if flor_state != TrucoFlorLogic.FlorState.NONE:
		return false
		
	# If player HAS flor, they cannot call Envido (must call Flor)
	if has_flor:
		return false

	# Blocked by Truco (unless pending response to First Truco)
	var is_truco_pending_response = (truco_state == TrucoTrucoLogic.TrucoCallState.CALLED \
		and pending_action == TrucoConstants.ResponseAction.TRUCO \
 		and proposed_truco_level == 1)
		
	if truco_state != TrucoTrucoLogic.TrucoCallState.NONE and not is_truco_pending_response:
		return false
		
	if state == EnvidoCallState.PLAYED:
		return false
		
	if chain.is_empty():
		# Only in first vuelta
		if vuelta_count > 0:
			return false
		return true
	else:
		var last_call = chain.back()
		match type:
			TrucoConstants.EnvidoType.ENVIDO:
				if last_call == TrucoConstants.EnvidoType.ENVIDO and chain.count(TrucoConstants.EnvidoType.ENVIDO) < 2:
					return true
				return false
			TrucoConstants.EnvidoType.REAL_ENVIDO:
				if last_call == TrucoConstants.EnvidoType.ENVIDO: return true
				return false
			TrucoConstants.EnvidoType.FALTA_ENVIDO:
				if last_call == TrucoConstants.EnvidoType.FALTA_ENVIDO: return false
				return true
				
	return false

## Calls envido. Returns true if successful.
## [param type]: The type of envido to call.
## [param player_index]: The player calling.
func call_envido(type: int, player_index: int) -> bool:
	chain.append(type)
	state = EnvidoCallState.CALLED
	envido_called.emit(player_index, type)
	return true

## Resolves the envido call.
## [param accepted]: Whether the call was accepted.
## [param answering_player_index]: The player who answered.
## [param players]: Array of players to calculate points.
## [param mano_player_index]: The mano player (wins ties).
## [param player_scores]: Current scores for Falta Envido calculation.
## [return] Dictionary with "winner" and "points" keys.
func resolve(
	accepted: bool,
	answering_player_index: int,
	players: Array,
	mano_player_index: int,
	player_scores: Dictionary
) -> Dictionary:
	state = EnvidoCallState.PLAYED
	
	var points: int = 0
	var winner: int = -1
	
	if not accepted:
		points = _calculate_rejected_points()
		winner = (answering_player_index + 1) % 2
	else:
		points = _calculate_accepted_points(player_scores)
		var p0_score = players[0].get_envido_points()
		var p1_score = players[1].get_envido_points()
		
		if p0_score > p1_score:
			winner = 0
		elif p1_score > p0_score:
			winner = 1
		else:
			winner = mano_player_index # Mano wins ties
	
	envido_resolved.emit(accepted, winner, points)
	return {"winner": winner, "points": points}

## Calculates points when envido is rejected.
func _calculate_rejected_points() -> int:
	var length = chain.size()
	if length <= 1: return 1
	
	# Check specific patterns
	if chain == [TrucoConstants.EnvidoType.ENVIDO, TrucoConstants.EnvidoType.ENVIDO]: return 2
	if chain == [TrucoConstants.EnvidoType.ENVIDO, TrucoConstants.EnvidoType.REAL_ENVIDO]: return 2
	if chain == [TrucoConstants.EnvidoType.ENVIDO, TrucoConstants.EnvidoType.FALTA_ENVIDO]: return 2
	if chain == [TrucoConstants.EnvidoType.REAL_ENVIDO, TrucoConstants.EnvidoType.FALTA_ENVIDO]: return 3
	
	if length == 3:
		if chain.has(TrucoConstants.EnvidoType.FALTA_ENVIDO):
			if chain.has(TrucoConstants.EnvidoType.REAL_ENVIDO): return 5
			return 4
		if chain.has(TrucoConstants.EnvidoType.REAL_ENVIDO): return 4
		
	if length == 4: return 7
	
	return 1

## Calculates points when envido is accepted.
func _calculate_accepted_points(player_scores: Dictionary) -> int:
	if chain.has(TrucoConstants.EnvidoType.FALTA_ENVIDO):
		return _calculate_falta_envido_value(player_scores)
	
	if chain == [TrucoConstants.EnvidoType.ENVIDO]: return 2
	if chain == [TrucoConstants.EnvidoType.REAL_ENVIDO]: return 3
	if chain == [TrucoConstants.EnvidoType.ENVIDO, TrucoConstants.EnvidoType.ENVIDO]: return 4
	if chain == [TrucoConstants.EnvidoType.ENVIDO, TrucoConstants.EnvidoType.REAL_ENVIDO]: return 5
	if chain == [TrucoConstants.EnvidoType.ENVIDO, TrucoConstants.EnvidoType.ENVIDO, TrucoConstants.EnvidoType.REAL_ENVIDO]: return 7
	
	return 2

## Calculates the value of Falta Envido based on current scores.
func _calculate_falta_envido_value(player_scores: Dictionary) -> int:
	var p0 = player_scores[0]
	var p1 = player_scores[1]
	
	var p0_buenas = p0 >= TrucoConstants.THRESHOLD_BUENAS
	var p1_buenas = p1 >= TrucoConstants.THRESHOLD_BUENAS
	
	if not p0_buenas and not p1_buenas:
		return TrucoConstants.MAX_SCORE # Game win
	else:
		var leader = max(p0, p1)
		return TrucoConstants.MAX_SCORE - leader
