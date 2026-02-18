class_name TrucoFlorLogic
extends RefCounted

## Handles all Flor-related logic for the Truco game.
## This includes calling, resolving, and calculating points for Flor.

# --- SIGNALS ---
signal flor_called(player_index: int, type: int)
signal flor_resolved(accepted: bool, winner_index: int, points: int)

# --- ENUMS ---
# Enum FlorType moved to TrucoConstants

enum FlorState {
	NONE,
	CALLED,
	PLAYED
}

# --- STATE ---
var state: int = FlorState.NONE
var chain: Array[int] = [] # Array of FlorType
var caller_index: int = -1

# --- REFERENCES ---
var _game: RefCounted # TrucoGame

func _init(game: RefCounted) -> void:
	_game = game

## Resets the flor state for a new hand.
func reset() -> void:
	state = FlorState.NONE
	chain.clear()
	caller_index = -1

## Checks if a player can call flor.
## [param type]: The type of flor to call (FlorType).
## [param player_index]: The player index.
## [param has_flor]: Whether the player has flor in their hand.
## [param vuelta_count]: Number of vueltas completed.
## [param truco_state]: Current truco call state.
## [param pending_action]: Current pending response action.
## [param proposed_truco_level]: The proposed truco level if any.
## [return] true if the player can call flor, false otherwise.
func can_call(
	type: int,
	player_index: int,
	has_flor: bool,
	vuelta_count: int,
	truco_state: int,
	pending_action: int,
	proposed_truco_level: int
) -> bool:
	# Check if player has flor
	if not has_flor:
		return false
		
	# Blocked by Truco? Similar to Envido.
	var is_truco_pending_response = (truco_state == TrucoTrucoLogic.TrucoCallState.CALLED \
		and pending_action == TrucoConstants.ResponseAction.TRUCO \
		and proposed_truco_level == 1)
		
	if truco_state != TrucoTrucoLogic.TrucoCallState.NONE and not is_truco_pending_response:
		return false
		
	if state == FlorState.PLAYED:
		return false
		
	# If Envido is pending, we CAN call Flor to cancel it
	if pending_action == TrucoConstants.ResponseAction.ENVIDO:
		return true

	if chain.is_empty():
		# Only in first vuelta
		if vuelta_count > 0:
			return false
		# Can start flor if nothing else is pending
		if pending_action == TrucoConstants.ResponseAction.NONE:
			return true
		# Or if responding to Truco (first level)
		if is_truco_pending_response:
			return true
			
		return false
	else:
		# Responding to Flor - Only opponent of last caller
		if caller_index == player_index:
			return false
			
		var last_call = chain.back()
		match type:
			TrucoConstants.FlorType.FLOR:
				# Cannot call Flor on Flor (It's ContraFlor)
				return false
			TrucoConstants.FlorType.CONTRA_FLOR:
				if last_call == TrucoConstants.FlorType.FLOR: return true
				return false
			TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO:
				if last_call == TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO: return false
				return true
				
	return false

## Calls flor. Returns true if successful.
## [param type]: The type of flor to call.
## [param player_index]: The player calling.
func call_flor(type: int, player_index: int) -> bool:
	chain.append(type)
	state = FlorState.CALLED
	caller_index = player_index
	flor_called.emit(player_index, type)
	return true

## Resolves the flor call.
## [param accepted]: Whether the call was accepted.
## [param answering_player_index]: The player who answered.
## [param players]: Array of players to calculate points.
## [param mano_player_index]: The mano player (wins ties).
## [param player_scores]: Current scores for Al Resto calculation.
## [return] Dictionary with "winner" and "points" keys.
func resolve(
	accepted: bool,
	answering_player_index: int,
	players: Array,
	mano_player_index: int,
	player_scores: Dictionary
) -> Dictionary:
	state = FlorState.PLAYED
	
	var points: int = 0
	var winner: int = -1
	
	if not accepted:
		var length = chain.size()
		if length > 1:
			winner = (answering_player_index + 1) % 2
			points = _calculate_rejected_points()
		else:
			winner = caller_index
			points = 3
	else:
		# Accepted challenge or acknowledging Flor
		if chain.size() == 1 and chain[0] == TrucoConstants.FlorType.FLOR:
			# If answering player also has Flor, compare points
			if players[answering_player_index].has_flor():
				var p0_envido = players[0].get_envido_points()
				var p1_envido = players[1].get_envido_points()
				
				if p0_envido > p1_envido:
					winner = 0
				elif p1_envido > p0_envido:
					winner = 1
				else:
					winner = mano_player_index
				
				points = 3 # Flor vs Flor is 3 points
			else:
				# Answering player doesn't have Flor - caller wins
				winner = caller_index
				points = 3
		else:
			# ContraFlor / Al Resto accepted - compare points
			var p0_envido = players[0].get_envido_points()
			var p1_envido = players[1].get_envido_points()
			
			if p0_envido > p1_envido:
				winner = 0
			elif p1_envido > p0_envido:
				winner = 1
			else:
				winner = mano_player_index
				
			points = _calculate_accepted_points(player_scores)
	
	flor_resolved.emit(accepted, winner, points)
	return {"winner": winner, "points": points}

## Calculates points when flor challenge is rejected.
func _calculate_rejected_points() -> int:
	var length = chain.size()
	if length == 2: return 4 # Flor vs ContraFlor -> Reject -> 4
	if length == 3: return 6 # ... vs Al Resto -> Reject -> 6
	return 3

## Calculates points when flor challenge is accepted.
func _calculate_accepted_points(player_scores: Dictionary) -> int:
	if chain.has(TrucoConstants.FlorType.CONTRA_FLOR_AL_RESTO):
		var p0 = player_scores[0]
		var p1 = player_scores[1]
		var leader = max(p0, p1)
		return TrucoConstants.MAX_SCORE - leader
		
	if chain.has(TrucoConstants.FlorType.CONTRA_FLOR):
		return 6
		
	return 3 # Base Flor
