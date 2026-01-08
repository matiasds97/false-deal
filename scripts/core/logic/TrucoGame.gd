class_name TrucoGame
extends RefCounted

## Pure logic class for the Truco Game.
## Handles state, rules, turn management, and scoring.
## Does NOT handle UI, Audio, or Waiting delays (unless logic-bound).

# --- SIGNALS ---
signal match_started
signal hand_started(hand_number: int)
signal turn_started(player_index: int)
signal card_dealt(player_index: int, card: Card)
signal card_played(player_index: int, card: Card)
signal envido_called(player_index: int, type: int) # type is EnvidoType
signal envido_resolved(accepted: bool, winner_index: int, points: int)
signal truco_called(player_index: int, level: int)
signal truco_resolved(accepted: bool, winner_index: int, level: int)
signal score_updated(score_p0: int, score_p1: int)
signal round_ended(winner_index: int, reason: String)
signal match_ended(winner_index: int)

# --- ENUMS ---
enum TrucoState {
	WAITING_FOR_START,
	DEALING,
	PLAYER_TURN, # Waiting for input from current_turn_index
	RESOLVING_HAND,
	MATCH_ENDED
}

enum EnvidoType {
	ENVIDO,
	REAL_ENVIDO,
	FALTA_ENVIDO
}

enum ResponseAction {
	NONE,
	ENVIDO,
	TRUCO
}

enum EnvidoCallState {
	NONE,
	CALLED,
	PLAYED
}

enum TrucoCallState {
	NONE,
	CALLED,
	PLAYED,
	TRUCO,
	RETRUCO,
	VALE_4 # Max level
}

# --- STATE VARIABLES ---
var current_state: int = TrucoState.WAITING_FOR_START

var players: Array[Player] = []
var deck: Deck

var dealer_index: int = 0
var mano_index: int = 0
var current_turn_index: int = 0
var mano_player_index: int = 0 # Usually same as mano_index, kept for logic clarity

var current_stakes: int = 1
var player_scores: Dictionary = {0: 0, 1: 0}

# Round Logic
var cards_played_current_vuelta: Array[Dictionary] = [] # { "card": Card, "player_index": int }
var vuelta_results: Array[int] = [] # Winner of each vuelta

# Envido State
var envido_state: int = EnvidoCallState.NONE
var envido_chain: Array[int] = [] # Array of EnvidoType
var truco_pending_during_envido: bool = false # If Envido interrupted Truco

# Truco State
var truco_state: int = TrucoCallState.NONE
var current_truco_level: int = 0 # 0=None, 1=Truco, 2=Retruco, 3=Vale 4
var proposed_truco_level: int = 0
var truco_caller_index: int = -1 # Who called the CURRENT accepted level (or proposed)
var pending_response_action: int = ResponseAction.NONE

# --- CONFIG ---
const MAX_SCORE: int = 30
const THRESHOLD_BUENAS: int = 16

func _init(_players: Array[Player], _deck: Deck):
	players = _players
	deck = _deck

# --- GAME LOOP ---

func start_match():
	current_state = TrucoState.WAITING_FOR_START
	player_scores = {0: 0, 1: 0}
	dealer_index = randi() % players.size()
	
	emit_signal("match_started")
	emit_signal("score_updated", player_scores[0], player_scores[1])
	
	start_new_hand()

func start_new_hand():
	current_state = TrucoState.DEALING
	
	cards_played_current_vuelta.clear()
	vuelta_results.clear()
	
	dealer_index = (dealer_index + 1) % players.size()
	mano_index = (dealer_index + 1) % players.size()
	mano_player_index = mano_index
	current_turn_index = mano_index
	
	# Reset Call States
	envido_state = EnvidoCallState.NONE
	envido_chain.clear()
	truco_state = TrucoCallState.NONE
	current_truco_level = 0
	proposed_truco_level = 0
	current_stakes = 1
	truco_caller_index = -1
	pending_response_action = ResponseAction.NONE
	truco_pending_during_envido = false
	
	emit_signal("hand_started", 1) # Hand number tracking could be added later
	
	_deal_cards()

func _deal_cards():
	if not deck:
		push_error("TrucoGame: No Deck assigned!")
		return
		
	deck.reset()
	for p in players:
		p.hand.clear()
		
	for i in range(3):
		for j in range(players.size()):
			var p_idx = (mano_index + j) % players.size()
			var card = deck.draw_card()
			if card:
				players[p_idx].receive_card(card)
				emit_signal("card_dealt", p_idx, card)
	
	_start_turn_cycle()

func _start_turn_cycle():
	if _is_match_over():
		return
		
	current_state = TrucoState.PLAYER_TURN
	emit_signal("turn_started", current_turn_index)

# --- ACTIONS ---

func play_card(player_index: int, card: Card) -> void:
	if current_state != TrucoState.PLAYER_TURN:
		push_warning("TrucoGame: Not in PLAYER_TURN state.")
		return
	if player_index != current_turn_index:
		push_warning("TrucoGame: Wrong turn. Expected %d, got %d" % [current_turn_index, player_index])
		return
	if pending_response_action != ResponseAction.NONE:
		push_warning("TrucoGame: Cannot play card while call is pending response.")
		return
		
	# Update Logic
	emit_signal("card_played", player_index, card)
	cards_played_current_vuelta.append({"card": card, "player_index": player_index})
	players[player_index].play_specific_card(card)
	
	_advance_turn()

func _advance_turn() -> void:
	if cards_played_current_vuelta.size() >= players.size():
		# Vuelta complete
		# IMPORTANT: In Pure Logic, we might want to resolve immediately.
		# But 'Manager' might want to show animation. 
		# We will just resolve immediately here for the logic state, 
		# and assume Manager handles visual delays via signals.
		# Wait... if Manager wants delays, maybe we should expose 'resolve_vuelta' as public 
		# or have a 'step' method?
		# Better: resolve immediately, emit result. Manager queues animations.
		_resolve_vuelta()
	else:
		current_turn_index = (current_turn_index + 1) % players.size()
		_start_turn_cycle()

func _resolve_vuelta() -> void:
	if cards_played_current_vuelta.size() != 2: return
	
	var c1_data = cards_played_current_vuelta[0]
	var c2_data = cards_played_current_vuelta[1]
	
	var c1 = c1_data["card"] as Card
	var c2 = c2_data["card"] as Card
	
	var comparison = c1.compare(c2)
	var winner_index = -1
	
	if comparison > 0:
		winner_index = c1_data["player_index"]
	elif comparison < 0:
		winner_index = c2_data["player_index"]
	else:
		winner_index = -1 # Parda
		
	vuelta_results.append(winner_index)
	cards_played_current_vuelta.clear()
	
	if _check_round_winner():
		return
		
	# Next Vuelta starter
	if winner_index != -1:
		current_turn_index = winner_index
	else:
		# Parda: Previous starter starts again
		current_turn_index = c1_data["player_index"]
		
	_start_turn_cycle()

func _check_round_winner() -> bool:
	var round_winner = -1
	var reason = ""
	
	if vuelta_results.size() == 2:
		var v1 = vuelta_results[0]
		var v2 = vuelta_results[1]
		
		if v1 != -1 and v2 != -1 and v1 == v2:
			round_winner = v1
			reason = "Won 1st and 2nd"
		elif v1 == -1 and v2 != -1:
			round_winner = v2
			reason = "Parda 1st, Won 2nd"
		elif v1 != -1 and v2 == -1:
			round_winner = v1
			reason = "Won 1st, Parda 2nd"
			
	elif vuelta_results.size() == 3:
		var v1 = vuelta_results[0]
		var v2 = vuelta_results[1]
		var v3 = vuelta_results[2]
		
		if v1 != -1 and v2 != -1 and v1 != v2:
			if v3 != -1:
				round_winner = v3
				reason = "Split, Won 3rd"
			else:
				round_winner = v1
				reason = "Split, Parda 3rd (1st wins)"
		elif v1 == -1 and v2 == -1:
			if v3 != -1:
				round_winner = v3
				reason = "Double Parda, Won 3rd"
			else:
				round_winner = mano_player_index
				reason = "Triple Parda (Mano wins)"
				
	if round_winner != -1:
		# End Round
		_add_score(round_winner, current_stakes)
		current_state = TrucoState.RESOLVING_HAND
		emit_signal("round_ended", round_winner, reason)
		# NOTE: Manager should call start_new_hand() after delay, 
		# or we can auto-call it? Logic class should probably wait for command 
		# or just update state. Let's wait for command to avoid infinite loops if signals are sync.
		# Ideally Logic doesn't wait. But Manager needs time to show "Round End".
		return true
		
	return false

func _add_score(player_index: int, points: int) -> void:
	player_scores[player_index] += points
	emit_signal("score_updated", player_scores[0], player_scores[1])
	_check_match_winner()

func _check_match_winner():
	if player_scores[0] >= MAX_SCORE:
		emit_signal("match_ended", 0)
		current_state = TrucoState.MATCH_ENDED
	elif player_scores[1] >= MAX_SCORE:
		emit_signal("match_ended", 1)
		current_state = TrucoState.MATCH_ENDED

func _is_match_over() -> bool:
	return current_state == TrucoState.MATCH_ENDED

# --- ENVIDO LOGIC ---

func can_call_envido(type: int, _player_index: int) -> bool:
	# 1. Blocked by Truco (unless pending response to First Truco)
	var is_truco_pending_response = (truco_state == TrucoCallState.CALLED \
		and pending_response_action == ResponseAction.TRUCO \
		and proposed_truco_level == 1)
		
	if truco_state != TrucoCallState.NONE and not is_truco_pending_response:
		return false
		
	if envido_state == EnvidoCallState.PLAYED:
		return false
		
	if envido_chain.is_empty():
		# Only in first vuelta
		if vuelta_results.size() > 0:
			return false
		return true
	else:
		var last_call = envido_chain.back()
		match type:
			EnvidoType.ENVIDO:
				if last_call == EnvidoType.ENVIDO and envido_chain.count(EnvidoType.ENVIDO) < 2:
					return true
				return false
			EnvidoType.REAL_ENVIDO:
				if last_call == EnvidoType.ENVIDO: return true
				return false
			EnvidoType.FALTA_ENVIDO:
				if last_call == EnvidoType.FALTA_ENVIDO: return false
				return true
				
	return false

func call_envido(type: int, player_index: int) -> void:
	if not can_call_envido(type, player_index):
		return
		
	if pending_response_action == ResponseAction.TRUCO:
		truco_pending_during_envido = true
		
	envido_chain.append(type)
	envido_state = EnvidoCallState.CALLED
	pending_response_action = ResponseAction.ENVIDO
	
	emit_signal("envido_called", player_index, type)

func resolve_envido(accepted: bool, answering_player_index: int) -> void:
	if pending_response_action != ResponseAction.ENVIDO: return
	
	envido_state = EnvidoCallState.PLAYED
	pending_response_action = ResponseAction.NONE
	
	var points = 0
	var winner = -1
	
	if not accepted:
		points = _calculate_rejected_envido_points()
		winner = (answering_player_index + 1) % 2
	else:
		points = _calculate_accepted_envido_points()
		var p0_score = players[0].get_envido_points()
		var p1_score = players[1].get_envido_points()
		
		if p0_score > p1_score:
			winner = 0
		elif p1_score > p0_score:
			winner = 1
		else:
			winner = mano_player_index # Mano wins ties
	
	emit_signal("envido_resolved", accepted, winner, points)
	_add_score(winner, points)
	
	# Resume Truco if needed
	if truco_pending_during_envido:
		truco_pending_during_envido = false
		pending_response_action = ResponseAction.TRUCO
		emit_signal("truco_called", truco_caller_index, proposed_truco_level)

func _calculate_rejected_envido_points() -> int:
	var length = envido_chain.size()
	if length <= 1: return 1
	
	# Check specific patterns or just fallback logic
	var chain_keys = envido_chain
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.ENVIDO]: return 2
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.REAL_ENVIDO]: return 2
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.FALTA_ENVIDO]: return 2
	if chain_keys == [EnvidoType.REAL_ENVIDO, EnvidoType.FALTA_ENVIDO]: return 3
	
	if length == 3:
		if chain_keys.has(EnvidoType.FALTA_ENVIDO):
			if chain_keys.has(EnvidoType.REAL_ENVIDO): return 5
			return 4
		if chain_keys.has(EnvidoType.REAL_ENVIDO): return 4
		
	if length == 4: return 7
	
	return 1

func _calculate_accepted_envido_points() -> int:
	if envido_chain.has(EnvidoType.FALTA_ENVIDO):
		return _calculate_falta_envido_value()
	
	var chain_keys = envido_chain
	if chain_keys == [EnvidoType.ENVIDO]: return 2
	if chain_keys == [EnvidoType.REAL_ENVIDO]: return 3
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.ENVIDO]: return 4
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.REAL_ENVIDO]: return 5
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.ENVIDO, EnvidoType.REAL_ENVIDO]: return 7
	
	return 2

func _calculate_falta_envido_value() -> int:
	var p0 = player_scores[0]
	var p1 = player_scores[1]
	
	var p0_buenas = p0 >= THRESHOLD_BUENAS
	var p1_buenas = p1 >= THRESHOLD_BUENAS
	
	if not p0_buenas and not p1_buenas:
		return 30 # Game win
	else:
		var leader = max(p0, p1)
		return MAX_SCORE - leader

# --- TRUCO LOGIC ---

func can_call_truco(player_index: int) -> bool:
	# No calling if waiting for response (except raise)
	if pending_response_action == ResponseAction.NONE:
		if current_truco_level == 0: return true
		if current_truco_level > 0 and current_truco_level < 3:
			# Only opponent of last caller can raise
			return truco_caller_index != player_index
	elif pending_response_action == ResponseAction.TRUCO:
		# Can raise if opponent of caller
		if player_index != truco_caller_index:
			return proposed_truco_level < 3
			
	return false

func call_truco(player_index: int) -> void:
	if not can_call_truco(player_index): return
	
	var next_level = 1
	if pending_response_action == ResponseAction.TRUCO:
		next_level = proposed_truco_level + 1
	else:
		next_level = current_truco_level + 1
		
	truco_state = TrucoCallState.CALLED
	proposed_truco_level = next_level
	truco_caller_index = player_index
	pending_response_action = ResponseAction.TRUCO
	
	emit_signal("truco_called", player_index, next_level)

func resolve_truco(accepted: bool, answering_player_index: int) -> void:
	if pending_response_action != ResponseAction.TRUCO: return
	
	pending_response_action = ResponseAction.NONE
	
	if accepted:
		truco_state = TrucoCallState.PLAYED
		current_truco_level = proposed_truco_level
		current_stakes = current_truco_level + 1
		emit_signal("truco_resolved", true, answering_player_index, current_truco_level)
	else:
		var points = proposed_truco_level
		var winner = truco_caller_index
		emit_signal("truco_resolved", false, answering_player_index, proposed_truco_level)
		_add_score(winner, points)
		
		# Round end due to rejection
		emit_signal("round_ended", winner, "Truco Rejected")

func player_fold(player_index: int) -> void:
	var opponent = (player_index + 1) % 2
	var points = 0
	
	# Envido penalty check
	var is_envido_time = (vuelta_results.size() == 0)
	if is_envido_time and envido_state != EnvidoCallState.PLAYED:
		points += 1
		
	if pending_response_action == ResponseAction.TRUCO:
		points += proposed_truco_level
	else:
		points += current_stakes
		
	_add_score(opponent, points)
	emit_signal("round_ended", opponent, "Folded")
