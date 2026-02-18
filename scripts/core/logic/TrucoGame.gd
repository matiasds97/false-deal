class_name TrucoGame
extends RefCounted

## Pure logic class for the Truco Game.
## Handles state, rules, turn management, and scoring.
## Does NOT handle UI, Audio, or Waiting delays (unless logic-bound).
##
## This class delegates specific mechanics to specialized modules:
## - TrucoEnvidoLogic: Envido calling and resolution
## - TrucoFlorLogic: Flor calling and resolution  
## - TrucoTrucoLogic: Truco/Retruco/Vale4 betting

# --- SIGNALS ---
signal match_started
signal hand_started(hand_number: int)
signal turn_started(player_index: int)
signal card_dealt(player_index: int, card: Card)
signal card_played(player_index: int, card: Card)
signal envido_called(player_index: int, type: int)
signal envido_resolved(accepted: bool, winner_index: int, points: int)
signal truco_called(player_index: int, level: int)
signal truco_resolved(accepted: bool, winner_index: int, level: int)
signal flor_called(player_index: int, type: int)
signal flor_resolved(accepted: bool, winner_index: int, points: int)
signal score_updated(score_p0: int, score_p1: int)
signal round_ended(winner_index: int, reason: String)
signal match_ended(winner_index: int)

# --- ENUMS ---
enum TrucoState {
	WAITING_FOR_START,
	DEALING,
	PLAYER_TURN,
	RESOLVING_HAND,
	MATCH_ENDED
}

# Enum ResponseAction moved to TrucoConstants

# Re-export sub-module enums for external access
# Type aliases removed (using TrucoConstants)
const FlorState = TrucoFlorLogic.FlorState
const EnvidoCallState = TrucoEnvidoLogic.EnvidoCallState
const TrucoCallState = TrucoTrucoLogic.TrucoCallState

# --- LOGIC MODULES ---
var _envido: TrucoEnvidoLogic
var _flor: TrucoFlorLogic
var _truco: TrucoTrucoLogic

# --- STATE VARIABLES ---
var current_state: int = TrucoState.WAITING_FOR_START
var players: Array[Player] = []
var deck: Deck

var dealer_index: int = 0
var mano_index: int = 0
var current_turn_index: int = 0
var mano_player_index: int = 0

var player_scores: Dictionary = {0: 0, 1: 0}

# Round Logic
var cards_played_current_vuelta: Array[Dictionary] = []
var vuelta_results: Array[int] = []

# Cross-module state
var pending_response_action: int = TrucoConstants.ResponseAction.NONE
var truco_pending_during_envido: bool = false

# --- PUBLIC ACCESSORS (for backward compatibility) ---
var envido_chain: Array[int]:
	get: return _envido.chain

var envido_state: int:
	get: return _envido.state

var current_truco_level: int:
	get: return _truco.current_level

var proposed_truco_level: int:
	get: return _truco.proposed_level

var truco_caller_index: int:
	get: return _truco.caller_index

var flor_state: int:
	get: return _flor.state

var flor_chain: Array[int]:
	get: return _flor.chain

var current_stakes: int:
	get: return _truco.get_current_stakes()

# --- INITIALIZATION ---

func _init(_players: Array[Player], _deck: Deck):
	players = _players
	deck = _deck
	
	# Initialize logic modules
	_envido = TrucoEnvidoLogic.new(self)
	_flor = TrucoFlorLogic.new(self)
	_truco = TrucoTrucoLogic.new(self)
	
	# Connect module signals to our signals (forwarding)
	_envido.envido_called.connect(func(p, t): envido_called.emit(p, t))
	_envido.envido_resolved.connect(func(a, w, p): envido_resolved.emit(a, w, p))
	_flor.flor_called.connect(func(p, t): flor_called.emit(p, t))
	_flor.flor_resolved.connect(func(a, w, p): flor_resolved.emit(a, w, p))
	_truco.truco_called.connect(func(p, l): truco_called.emit(p, l))
	_truco.truco_resolved.connect(func(a, w, l): truco_resolved.emit(a, w, l))

# --- GAME LOOP ---

## Starts a new match of Truco.
func start_match() -> void:
	current_state = TrucoState.WAITING_FOR_START
	player_scores = {0: 0, 1: 0}
	dealer_index = randi() % players.size()
	
	match_started.emit()
	score_updated.emit(player_scores[0], player_scores[1])
	
	start_new_hand()

## Starts a new hand of Truco.
func start_new_hand() -> void:
	current_state = TrucoState.DEALING
	cards_played_current_vuelta.clear()
	vuelta_results.clear()
	_set_new_hand_player_indices()
	_reset_call_states()

	hand_started.emit(1)
	_deal_cards()

func _set_new_hand_player_indices() -> void:
	dealer_index = (dealer_index + 1) % players.size()
	mano_index = (dealer_index + 1) % players.size()
	mano_player_index = mano_index
	current_turn_index = mano_index

func _reset_call_states() -> void:
	_envido.reset()
	_flor.reset()
	_truco.reset()
	pending_response_action = TrucoConstants.ResponseAction.NONE
	truco_pending_during_envido = false

func _deal_cards() -> void:
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
				card_dealt.emit(p_idx, card)
	
	_start_turn_cycle()

func _start_turn_cycle() -> void:
	if _is_match_over():
		return
		
	current_state = TrucoState.PLAYER_TURN
	turn_started.emit(current_turn_index)

# --- CARD ACTIONS ---

func play_card(player_index: int, card: Card) -> void:
	if current_state != TrucoState.PLAYER_TURN:
		push_warning("TrucoGame: Not in PLAYER_TURN state.")
		return
	if player_index != current_turn_index:
		push_warning("TrucoGame: Wrong turn. Expected %d, got %d" % [current_turn_index, player_index])
		return
	if pending_response_action != TrucoConstants.ResponseAction.NONE:
		push_warning("TrucoGame: Cannot play card while call is pending response.")
		return
		
	card_played.emit(player_index, card)
	cards_played_current_vuelta.append({"card": card, "player_index": player_index})
	players[player_index].play_specific_card(card)
	
	_advance_turn()

func _advance_turn() -> void:
	if cards_played_current_vuelta.size() >= players.size():
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
		_add_score(round_winner, current_stakes)
		if current_state != TrucoState.MATCH_ENDED:
			current_state = TrucoState.RESOLVING_HAND
		round_ended.emit(round_winner, reason)
		return true
		
	return false

# --- ENVIDO LOGIC (Delegated) ---

func can_call_envido(type: int, player_index: int) -> bool:
	return _envido.can_call(
		type,
		player_index,
		_flor.state,
		players[player_index].has_flor(),
		vuelta_results.size(),
		_truco.state,
		pending_response_action,
		_truco.proposed_level
	)

func call_envido(type: int, player_index: int) -> void:
	if not can_call_envido(type, player_index):
		return
		
	if pending_response_action == TrucoConstants.ResponseAction.TRUCO:
		truco_pending_during_envido = true
	
	# Update state BEFORE emitting signal (inside _envido.call_envido)
	pending_response_action = TrucoConstants.ResponseAction.ENVIDO
	_envido.call_envido(type, player_index)

func resolve_envido(accepted: bool, answering_player_index: int) -> void:
	if pending_response_action != TrucoConstants.ResponseAction.ENVIDO: return
	
	pending_response_action = TrucoConstants.ResponseAction.NONE
	
	var result = _envido.resolve(
		accepted,
		answering_player_index,
		players,
		mano_player_index,
		player_scores
	)
	
	_add_score(result["winner"], result["points"])
	
	# Resume Truco if it was interrupted
	if truco_pending_during_envido:
		truco_pending_during_envido = false
		pending_response_action = TrucoConstants.ResponseAction.TRUCO
		truco_called.emit(_truco.caller_index, _truco.proposed_level)

# --- FLOR LOGIC (Delegated) ---

func can_call_flor(type: int, player_index: int) -> bool:
	return _flor.can_call(
		type,
		player_index,
		players[player_index].has_flor(),
		vuelta_results.size(),
		_truco.state,
		pending_response_action,
		_truco.proposed_level
	)

func call_flor(type: int, player_index: int) -> void:
	if not can_call_flor(type, player_index):
		return

	# Handle interruptions
	if pending_response_action == TrucoConstants.ResponseAction.ENVIDO:
		_envido.reset()
	elif pending_response_action == TrucoConstants.ResponseAction.TRUCO:
		truco_pending_during_envido = true
	
	# Update state BEFORE signal
	pending_response_action = TrucoConstants.ResponseAction.FLOR
	_flor.call_flor(type, player_index)

func resolve_flor(accepted: bool, answering_player_index: int) -> void:
	if pending_response_action != TrucoConstants.ResponseAction.FLOR: return
	
	pending_response_action = TrucoConstants.ResponseAction.NONE
	
	var result = _flor.resolve(
		accepted,
		answering_player_index,
		players,
		mano_player_index,
		player_scores
	)
	
	_add_score(result["winner"], result["points"])
	
	# Resume Truco if it was interrupted
	if truco_pending_during_envido:
		truco_pending_during_envido = false
		pending_response_action = TrucoConstants.ResponseAction.TRUCO
		truco_called.emit(_truco.caller_index, _truco.proposed_level)

# --- TRUCO LOGIC (Delegated) ---

func can_call_truco(player_index: int) -> bool:
	return _truco.can_call(player_index, _flor.state, pending_response_action)

func call_truco(player_index: int) -> void:
	if not can_call_truco(player_index): return
	
	var current_pending = pending_response_action
	# Update state BEFORE signal
	pending_response_action = TrucoConstants.ResponseAction.TRUCO
	
	_truco.call_truco(player_index, current_pending)

func resolve_truco(accepted: bool, answering_player_index: int) -> void:
	if pending_response_action != TrucoConstants.ResponseAction.TRUCO: return
	
	pending_response_action = TrucoConstants.ResponseAction.NONE
	
	var result = _truco.resolve(accepted, answering_player_index)
	
	if result["round_ends"]:
		_add_score(result["winner"], result["points"])
		round_ended.emit(result["winner"], "Truco Rejected")

# --- FOLD ---

func player_fold(player_index: int) -> void:
	var opponent = (player_index + 1) % 2
	var points = 0
	
	# Envido penalty check
	var is_envido_time = (vuelta_results.size() == 0)
	if is_envido_time and _envido.state != EnvidoCallState.PLAYED:
		points += 1
		
	if pending_response_action == TrucoConstants.ResponseAction.TRUCO:
		points += _truco.proposed_level
	else:
		points += current_stakes
		
	_add_score(opponent, points)
	round_ended.emit(opponent, "Folded")

# --- SCORING ---

func _add_score(player_index: int, points: int) -> void:
	player_scores[player_index] += points
	score_updated.emit(player_scores[0], player_scores[1])
	_check_match_winner()

func _check_match_winner() -> void:
	if player_scores[0] >= TrucoConstants.MAX_SCORE:
		match_ended.emit(0)
		current_state = TrucoState.MATCH_ENDED
	elif player_scores[1] >= TrucoConstants.MAX_SCORE:
		match_ended.emit(1)
		current_state = TrucoState.MATCH_ENDED

func _is_match_over() -> bool:
	return current_state == TrucoState.MATCH_ENDED
