class_name TrucoManager
extends Node
## Manager class that handles the core game loop, rules, and state of a Truco match.
## It manages players, turns, scoring, and the state of complex calls like Envido and Truco.


## ------- SIGNALS -------

## Signal emitted when the match starts.
signal match_started

## Signal emitted when a new hand starts.
signal new_hand_started(hand_number: int)

## Signal emitted when a player's turn starts.
signal turn_started(player_index: int)

## ------- EXPORT VARIABLES -------

## The deck used for the game.
@export var deck: Deck

## The nodes of the players.
@export var player_nodes: Array[Node]

## ------- PUBLIC VARIABLES -------

## Current state of the game.
var current_state: int = TrucoState.WAITING_FOR_START

## Array of players in the game.
var players: Array[Player] = []

## Inidicates which player must deal the cards.
var dealer_index: int = 0

## Inidicates which player must play the cards in the first turn.
var mano_index: int = 0

## Inidicates which player must play the cards in the current turn.
var current_turn_index: int = 0

## Inidicates which player must play the cards in the mano.
var mano_player_index: int = 0

## Inidicates the current stakes of the game.
var current_stakes: int = 1

## Stores { "card": Card, "player_index": int } for the current "baza" (vuelta).
var cards_played_current_vuelta: Array[Dictionary] = []

## Stores winner of each vuelta (-1 for tie).
var vuelta_results: Array[int] = []

## Stores the scores of each player. 
## Key is the player index and value is the score.
var player_scores: Dictionary = {0: 0, 1: 0}

## Who called the CURRENT level of Truco (used for determining points on rejection).
## -1 indicates no player has called a Truco level.
var truco_caller_index: int = -1

var pending_response_action: ResponseAction = ResponseAction.NONE


var envido_state: EnvidoCallState = EnvidoCallState.NONE
var truco_state: TrucoCallState = TrucoCallState.NONE


## History of Envido calls in the current exchange (e.g. [ENVIDO, REAL_ENVIDO]).
var envido_chain: Array[EnvidoType] = []

## Flag to indicate if a Truco call was put on hold to play Envido.
var truco_pending_during_envido: bool = false

## ------- ENUMS -------

## Different states of the game flow.
enum TrucoState {

	## Represents the state in which the truco game has not yet started.
	WAITING_FOR_START,

	## Represents the state in which the cards are being dealed.
	DEALING,

	## Represents the state in which the player's turn is active.
	PLAYER_TURN,

	## Represents the state in which the rival's turn is active.
	RIVAL_TURN,

	## Represents the state in which the hand is being resolved.
	RESOLVING_HAND,

	## Represents the state in which the match has ended.
	MATCH_ENDED
}

## Types of Envido calls available.
enum EnvidoType {

	## The normal Envido call.
	ENVIDO,
	
	## The Real Envido call.
	REAL_ENVIDO,
	
	## The Falta Envido call.
	FALTA_ENVIDO
}


## Enum for defining which call is pending a response.
enum ResponseAction {
	NONE,
	ENVIDO,
	TRUCO
}

## State of the Envido call (e.g., if it was already played this hand).
enum EnvidoCallState {
	NONE,
	CALLED,
	PLAYED
}

## State of the Truco call.
enum TrucoCallState {
	NONE,
	CALLED,
	PLAYED,
	TRUCO,
	RETRUCO,
	VALE_4
}

## Level of Truco currently active (0=None, 1=Truco, 2=Retruco, 3=Vale 4)
## This represents the "Accepted" level.
var current_truco_level: int = 0
## The level being PROPOSED (waiting for response).
var proposed_truco_level: int = 0

## ------- FUNCTIONS -------

func _ready() -> void:
	var _p1: Player = Player.new("Human", true, 0)
	var _p2: Player = Player.new("CPU", false, 1)
	players = [_p1, _p2]

	# Auto-fill player_nodes if empty (Fallback)
	if player_nodes.is_empty():
		push_warning("TrucoManager: Player Nodes not assigned. Auto-finding...")
		var human_node: Node = get_node_or_null("../HumanPlayer")
		var cpu_node: Node = get_node_or_null("../CPUPlayer")
		if human_node and cpu_node:
			print_debug("TrucoManager: Auto-found Player Nodes.")
			player_nodes = [human_node, cpu_node]
		else:
			printerr("TrucoManager: Player Nodes not assigned and could not be auto-found!")

	# Initialize controllers
	if player_nodes.size() == players.size():
		for i in range(players.size()):
			if player_nodes[i].has_method("initialize"):
				player_nodes[i].initialize(players[i])
				_connect_signals()
	else:
		printerr("Mismatch between Players count and Player Nodes count! \
		Players: %d, Nodes: %d" % [players.size(), player_nodes.size()])

	call_deferred("start_match")

## Connects signals from player nodes to the manager. The signals connected
## are for when a player plays a card, calls Envido, or calls Truco.
func _connect_signals() -> void:
	for i in range(players.size()):
		if player_nodes[i].has_signal("card_played"):
			if not player_nodes[i].card_played.is_connected(_on_player_card_played):
				player_nodes[i].card_played.connect(_on_player_card_played.bind(i))
		
		if player_nodes[i].has_signal("envido_called"):
			if not player_nodes[i].envido_called.is_connected(_on_player_envido_called):
				player_nodes[i].envido_called.connect(_on_player_envido_called.bind(i))

		if player_nodes[i].has_signal("truco_called"):
			if not player_nodes[i].truco_called.is_connected(_on_player_truco_called):
				player_nodes[i].truco_called.connect(_on_player_truco_called.bind(i))

## Starts the match, initializes scores and calls the first hand.
func start_match() -> void:
	print_debug("Truco match started!")
	emit_signal("match_started")
	
	# Emit initial score
	TrucoSignalBus.emit_signal("on_score_updated", player_scores[0], player_scores[1])
	
	dealer_index = randi() % players.size()
	start_new_hand()

## Resets the state for a new hand (dealing cards).
func start_new_hand() -> void:
	current_state = TrucoState.DEALING
	
	cards_played_current_vuelta.clear()
	vuelta_results.clear()

	dealer_index = (dealer_index + 1) % players.size()
	mano_index = (dealer_index + 1) % players.size()
	mano_player_index = mano_index
	current_turn_index = mano_index

	# Reset states for new hand
	envido_state = EnvidoCallState.NONE
	envido_chain.clear()
	truco_state = TrucoCallState.NONE
	current_truco_level = 0
	proposed_truco_level = 0
	current_stakes = 1
	truco_caller_index = -1
	pending_response_action = ResponseAction.NONE
	truco_pending_during_envido = false

	print_debug("NewHand.Dealer: %s, Mano: %s, Turn: %s" % [players[dealer_index].name, players[mano_index].name, players[current_turn_index].name])
	
	TrucoSignalBus.emit_signal("on_hand_started", 1)
	emit_signal("new_hand_started", 1) # Keep local signal for now if needed by other logic

	deal_cards()

## Deals 3 cards to each player from the deck.
func deal_cards() -> void:
	if not deck:
		printerr("No deck assigned to TrucoManager!")
		return

	deck.reset()
	for player in players:
		player.hand.clear()

	for i in range(3):
		for j in range(players.size()):
			# Start dealing to the player AFTER the dealer (mano)
			var player_index = (mano_index + j) % players.size()
			var card: Card = deck.draw_card()
			if card:
				players[player_index].receive_card(card)
				# Emit via SignalBus
				TrucoSignalBus.emit_signal("on_card_dealt", player_index, card)
	
	print_debug("Cards dealt.")
	start_turn_cycle()

## Sets the current state to the correct turn type and notifies listeners.
func start_turn_cycle() -> void:
	if players[current_turn_index].is_human:
		current_state = TrucoState.PLAYER_TURN
	else:
		current_state = TrucoState.RIVAL_TURN

	print_debug("Turn: %s" % players[current_turn_index].name)
	
	# Emit via SignalBus
	TrucoSignalBus.emit_signal("on_turn_started", current_turn_index)
	emit_signal("turn_started", current_turn_index)

	# Trigger the controller!
	if current_turn_index < player_nodes.size():
		player_nodes[current_turn_index].start_turn()

func _on_player_card_played(card: Card, player_index: int) -> void:
	if player_index != current_turn_index:
		printerr("Player %d played out of turn!" % player_index)
		return
		
	if pending_response_action != ResponseAction.NONE:
		printerr("Player %d tried to play a card while a call is pending!" % player_index)
		return
		
	print_debug("Player %d played %s" % [player_index, card])
	
	# Emit via SignalBus
	TrucoSignalBus.emit_signal("on_card_played", player_index, card)
	
	# Track internally
	cards_played_current_vuelta.append({"card": card, "player_index": player_index})
		
	# Remove from player hand (Logic)
	players[player_index].play_specific_card(card)
	
	# Advance turn
	advance_turn()

func _on_player_envido_called(player_index: int) -> void:
	call_envido(EnvidoType.ENVIDO, player_index)

## Moves the turn to the next player or resolves the vuelta if everybody played.
func advance_turn() -> void:
	# Check if Baza is over (2 cards played for 2 players)
	if cards_played_current_vuelta.size() >= players.size():
		# Wait a bit before resolving so players can see the cards
		get_tree().create_timer(1.0).timeout.connect(resolve_vuelta)
	else:
		current_turn_index = (current_turn_index + 1) % players.size()
		start_turn_cycle()

## Compares the cards played in the current vuelta and determines the winner.
func resolve_vuelta() -> void:
	print_debug("Resolving Vuelta...")
	
	if cards_played_current_vuelta.size() != 2:
		printerr("Error: resolve_vuelta called with %d cards!" % cards_played_current_vuelta.size())
		return

	var c1_data: Dictionary = cards_played_current_vuelta[0]
	var c2_data: Dictionary = cards_played_current_vuelta[1]
	
	var c1: Card = c1_data["card"] as Card
	var c2: Card = c2_data["card"] as Card
	
	var comparison: int = c1.compare(c2)
	var winner_index: int = -1
	
	if comparison > 0:
		winner_index = c1_data["player_index"]
		print_debug("Vuelta winner: Player %d" % winner_index)
	elif comparison < 0:
		winner_index = c2_data["player_index"]
		print_debug("Vuelta winner: Player %d" % winner_index)
	else:
		winner_index = -1
		print_debug("Vuelta result: Parda (Tie)")
		
	vuelta_results.append(winner_index)
	
	# Reset for next vuelta
	cards_played_current_vuelta.clear()
	
	if check_round_winner():
		return

	# Determine who starts next vuelta
	if winner_index != -1:
		current_turn_index = winner_index
	else:
		# If Parda, the player who started the CURRENT vuelta starts the next one.
		# We can find who started the current vuelta by looking at who played the first card.
		current_turn_index = c1_data["player_index"]
		
	start_turn_cycle()

## Checks if the round has a winner based on the results of the vueltas (best of 3).
## Returns true if the round ended, false otherwise.
func check_round_winner() -> bool:
	var round_winner: int = -1
	var reason: String = ""
	
	# Parda Rules Logic
	# 1. Parda in 1st Vuelta: The winner of the 2nd Vuelta wins the round.
	# 2. Parda in 1st and 2nd Vuelta: The winner of the 3rd Vuelta wins the round.
	# 3. Parda in 1st, 2nd, and 3rd Vuelta: The player who is "Mano" wins.
	# 4. Parda in 2nd Vuelta (after a winner in 1st): The winner of the 1st Vuelta wins the round.
	# 5. Parda in 3rd Vuelta (after split wins in 1st and 2nd): The winner of the 1st Vuelta wins the round.
	
	if vuelta_results.size() == 2:
		var v1: int = vuelta_results[0]
		var v2: int = vuelta_results[1]
		
		if v1 != -1 and v2 != -1 and v1 == v2:
			round_winner = v1
			reason = "Won 1st and 2nd vueltas"
		elif v1 == -1 and v2 != -1:
			round_winner = v2
			reason = "Parda in 1st, Won 2nd"
		elif v1 != -1 and v2 == -1:
			round_winner = v1
			reason = "Won 1st, Parda in 2nd"
			
	elif vuelta_results.size() == 3:
		var v1: int = vuelta_results[0]
		var v2: int = vuelta_results[1]
		var v3: int = vuelta_results[2]
		
		if v1 != -1 and v2 != -1 and v1 != v2:
			# Split 1st and 2nd
			if v3 != -1:
				round_winner = v3
				reason = "Split 1st/2nd, Won 3rd"
			else:
				round_winner = v1
				reason = "Split 1st/2nd, Parda in 3rd (1st winner takes it)"
		elif v1 == -1 and v2 == -1:
			if v3 != -1:
				round_winner = v3
				reason = "Parda 1st/2nd, Won 3rd"
			else:
				round_winner = mano_player_index
				reason = "Triple Parda (Mano wins)"
	
	if round_winner != -1:
		print_debug("Round Ended! Winner: Player %d (%s)" % [round_winner, reason])
		
		# Award points based on current stakes (unless it was a special early win, but Parda logic implies full play)
		# Actually, standard round win awards current_stakes.
		add_score(round_winner, current_stakes)
		
		# Wait a bit then start new hand
		get_tree().create_timer(2.0).timeout.connect(start_new_hand)
		return true
		
	return false

func add_score(player_index: int, points: int) -> void:
	player_scores[player_index] += points
	print_debug("Score Update: Player %d gets %d points. Total: P0:%d - P1:%d" % [player_index, points, player_scores[0], player_scores[1]])
	TrucoSignalBus.emit_signal("on_score_updated", player_scores[0], player_scores[1])

# --- ENVIDO IMPLEMENTATION ---

## Checks if a player can call the specified Envido type based on game rules and current chain.
func can_call_envido(type: EnvidoType, _player_index: int) -> bool:
	# 1. Truco not called (Truco blocks Envido calls)
	# EXCEPTION: If Truco IS called (pending response), and it is the first vuelta, 
	# and Envido hasn't been played, we CAN call Envido ("El envido esta primero").
	# BUT only on the first call (Truco), not on Retruco/Vale 4.
	var is_truco_pending_response = (truco_state == TrucoCallState.CALLED and pending_response_action == ResponseAction.TRUCO and proposed_truco_level == 1)
	
	if truco_state != TrucoCallState.NONE and not is_truco_pending_response:
		return false
		
	# 1.5 Envido not already played
	if envido_state == EnvidoCallState.PLAYED:
		return false
	
	# 2. Constraints based on current chain
	if envido_chain.is_empty():
		# Only allowed in first Vuelta (before played cards or responding pending actions)
		# NOTE: If reacting to Truco, we are effectively "before played cards" in terms of phase, 
		# even if cards are on table, it must be the FIRST vuelta's play.
		if vuelta_results.size() > 0:
			return false
		# Can start with any call types logically, usually Envido or Real or Falta directly
		return true
	else:
		# If chain exists, check if this call is a valid raise
		var last_call = envido_chain.back()
		
		match type:
			EnvidoType.ENVIDO:
				# Can call Envido only if previous was Envido AND we haven't already said Envido-Envido
				# Standard limit is Envido-Envido. No Envido-Envido-Envido.
				if last_call == EnvidoType.ENVIDO and envido_chain.count(EnvidoType.ENVIDO) < 2:
					return true
				return false
			EnvidoType.REAL_ENVIDO:
				# Can call Real Envido on top of Envido or Envido-Envido
				if last_call == EnvidoType.ENVIDO:
					return true
				# Cannot call Real Envido on top of Falta Envido or Real Envido (usually)
				return false
			EnvidoType.FALTA_ENVIDO:
				# Can call Falta Envido on top of anything
				return true
				
	return false

# Simplified check for UI button "Envido" (base)
func can_call_any_initial_envido() -> bool:
	return can_call_envido(EnvidoType.ENVIDO, 0) and envido_chain.is_empty()

## Executes the Envido call, updates state, and notifies UI.
func call_envido(type: EnvidoType, player_index: int) -> void:
	if not can_call_envido(type, player_index):
		printerr("Player %d tried to call Envido Type %s but it is not allowed!" % [player_index, type])
		return
		
	print_debug("Player %d called %s!" % [player_index, EnvidoType.keys()[type]])
	
	# Check if we are interrupting a Truco call
	if pending_response_action == ResponseAction.TRUCO:
		print_debug("Envido called in response to Truco! Pausing Truco...")
		truco_pending_during_envido = true

	envido_chain.append(type)
	envido_state = EnvidoCallState.CALLED
	pending_response_action = ResponseAction.ENVIDO
	
	# Emit signal so UI shows ResponseContainer
	TrucoSignalBus.emit_signal("on_envido_called", player_index)

## Resolves the Envido state after a player accepts or rejects.
func resolve_envido(accepted: bool, answering_player_index: int) -> void:
	print_debug("Envido Resolved. Accepted: %s" % accepted)
	envido_state = EnvidoCallState.PLAYED
	pending_response_action = ResponseAction.NONE
	
	var points: int = 0
	var winner: int = -1
	
	if not accepted:
		points = _calculate_rejected_envido_points()
		# Winner is the one who called last (opponent of answerer)
		winner = (answering_player_index + 1) % 2
		print_debug("Envido Rejected. %d Point(s) to Player %d" % [points, winner])
	else:
		points = _calculate_accepted_envido_points()
		# Compare points
		var p0_score: int = players[0].get_envido_points()
		var p1_score: int = players[1].get_envido_points()
		
		print_debug("Envido Showdown! P0: %d vs P1: %d" % [p0_score, p1_score])
		
		if p0_score > p1_score:
			winner = 0
		elif p1_score > p0_score:
			winner = 1
		else:
			# Tie: Mano wins
			print_debug("Envido Tie! Mano wins.")
			if mano_player_index == 0:
				winner = 0
			else:
				winner = 1
		
		print_debug("Envido Accepted. %d Points to Player %d" % [points, winner])
	
	# Handle Falta Envido Special Win Condition
	if is_falta_envido_accepted():
		# If Falta Envido was won, check if it ends the game or just points
		# Standard Falta Envido rule logic usually returns points needed to win
		# We'll just add points. If logic inside calculcate returned match-winning points, it works out.
		pass

	# Award points
	add_score(winner, points)
	TrucoSignalBus.emit_signal("on_envido_resolved", accepted, winner, points)

	# Check if we need to restore a pending Truco call
	if truco_pending_during_envido:
		print_debug("Resuming pending Truco call...")
		truco_pending_during_envido = false
		pending_response_action = ResponseAction.TRUCO
		
		# We need to re-notify the UI/Players that Truco is pending.
		# The caller is still `truco_caller_index`.
		# Current level is `proposed_truco_level`.
		TrucoSignalBus.emit_signal("on_truco_called", truco_caller_index, proposed_truco_level)

func _calculate_rejected_envido_points() -> int:
	# Calculate points for NO QUIERO based on chain
	# Chain example: [ENVIDO] -> Reject -> 1 (Default)
	# [ENVIDO, ENVIDO] -> Reject -> 2
	# [ENVIDO, REAL] -> Reject -> 2
	# [ENVIDO, FALTA] -> Reject -> 2
	# [REAL, FALTA] -> Reject -> 3
	# [ENVIDO, ENVIDO, FALTA] -> Reject -> 4
	# [ENVIDO, ENVIDO, REAL] -> Reject -> 4
	# [ENVIDO, REAL, FALTA] -> Reject -> 5
	# [ENVIDO, ENVIDO, REAL, FALTA] -> Reject -> 7
	var length: int = envido_chain.size()
	if length == 0: return 0 # Should not happen
	
	var _last = envido_chain.back()
	
	# If rejecting the FIRST call
	if length == 1:
		return 1
	
	# If rejecting a raise
	var chain_keys: Array[Variant] = []
	for item in envido_chain:
		chain_keys.append(item)
		
	# Patterns from user table (No Querido column)
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.ENVIDO]: return 2
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.REAL_ENVIDO]: return 2
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.FALTA_ENVIDO]: return 2
	
	if chain_keys == [EnvidoType.REAL_ENVIDO, EnvidoType.FALTA_ENVIDO]: return 3
	# Note: REAL -> FALTA implies initial was REAL. If Envido->Real->Falta, that's length 3.
	
	if length == 3:
		if chain_keys == [EnvidoType.ENVIDO, EnvidoType.ENVIDO, EnvidoType.FALTA_ENVIDO]: return 4
		if chain_keys == [EnvidoType.ENVIDO, EnvidoType.ENVIDO, EnvidoType.REAL_ENVIDO]: return 4
		if chain_keys == [EnvidoType.ENVIDO, EnvidoType.REAL_ENVIDO, EnvidoType.FALTA_ENVIDO]: return 5

	if length == 4:
		# Envido - Envido - Real - Falta
		return 7

	# Fallback / Simplification if pattern mismatch (though code should strictly control flow)
	# Logic: Points equal to the value of the PREVIOUS valid accepted state. 
	# Envido (2) -> Raised to Envido (4). Reject = 2.
	# Envido (2) -> Real (5). Reject = 2.
	# Real (3) -> Falta. Reject = 3.
	return 1

func _calculate_accepted_envido_points() -> int:
	var chain_keys: Array[Variant] = []
	for item in envido_chain:
		chain_keys.append(item)
		
	if chain_keys.has(EnvidoType.FALTA_ENVIDO):
		return calculate_falta_envido_value()
	
	if chain_keys == [EnvidoType.ENVIDO]: return 2
	if chain_keys == [EnvidoType.REAL_ENVIDO]: return 3
	
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.ENVIDO]: return 4
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.REAL_ENVIDO]: return 5
	
	if chain_keys == [EnvidoType.ENVIDO, EnvidoType.ENVIDO, EnvidoType.REAL_ENVIDO]: return 7
	
	# Default fallback
	return 2

func calculate_falta_envido_value() -> int:
	# Calculate points needed to win
	# "Buenas" / "Malas" Logic
	# Max Core is 30. Malas = 0-15?? Usually played to 30 points total. "Buenas" starts at 16.
	# If both in Malas: Winner wins the GAME (30 points or enough to reach 30)
	# If one in Buenas: Points equal to what the LEADER needs to win.
	var p0 = player_scores[0]
	var p1 = player_scores[1]
	
	var max_points: int = 30
	var threshold_buenas: int = 16
	
	var p0_buenas = p0 >= threshold_buenas
	var p1_buenas = p1 >= threshold_buenas
	
	if not p0_buenas and not p1_buenas:
		# Both in Malas -> Game Over (Win match)
		# We need to return points sufficient to reach 30 for the winner or just 30
		# The add_score function adds to current.
		# If I return 30, it guarantees win.
		return 30
	else:
		# Someone is in Buenas
		var leader_score = max(p0, p1)
		var points_to_win = max_points - leader_score
		return points_to_win

func is_falta_envido_accepted() -> bool:
	return envido_chain.has(EnvidoType.FALTA_ENVIDO)

func debug_cpu_call_envido() -> void:
	if can_call_envido(EnvidoType.ENVIDO, 1):
		call_envido(EnvidoType.ENVIDO, 1)

# --- TRUCO IMPLEMENTATION ---

## Checks if a player can call Truco based on current state.
## Checks if a player can call Truco/Retruco/Vale 4 based on current state.
func can_call_truco(player_index: int) -> bool:
	# Cannot call if a response is pending (unless it's a counter-call, handled separately or implicitly)
	# Actually, if response is pending, only the responder can call (raise).
	# Case 1: No Truco called yet (Level 0) -> Any player can call Truco
	if current_truco_level == 0 and pending_response_action == ResponseAction.NONE:
		return true
		
	# Case 2: Truco/Retruco called and ACCEPTED. 
	# Only the player who DID NOT call the last level can raise.
	# We need to track who called the last level. `truco_caller_index` stores the LAST caller.
	if pending_response_action == ResponseAction.NONE and current_truco_level > 0 and current_truco_level < 3:
		if truco_caller_index != player_index:
			return true
		return false

	# Case 3: Truco/Retruco just called (Pending Response).
	# The responder can raise (Retruco/Vale 4).
	if pending_response_action == ResponseAction.TRUCO:
		# The player attempting to call MUST be the one who needs to respond.
		# We don't store "responder_index" specifically but we know `truco_caller_index` is the one who called.
		# So player_index must be != truco_caller_index.
		if player_index != truco_caller_index:
			if proposed_truco_level < 3: # Can raise if proposed is less than Vale 4
				return true
				
	return false

## Executes the Truco call, updates state, and notifies UI.
## Executes the Truco/Retruco/Vale 4 call, updates state, and notifies UI.
func call_truco(player_index: int) -> void:
	if not can_call_truco(player_index):
		return
		
	# Determine level
	var next_level = 1
	if pending_response_action == ResponseAction.TRUCO:
		# Raising a pending call
		next_level = proposed_truco_level + 1
	else:
		# Creating a new call (raising accepted state)
		next_level = current_truco_level + 1
		
	var call_name = ""
	match next_level:
		1: call_name = "Truco"
		2: call_name = "Retruco"
		3: call_name = "Vale 4"
		
	print_debug("Player %d called %s!" % [player_index, call_name])
	
	truco_state = TrucoCallState.CALLED # General state
	proposed_truco_level = next_level
	truco_caller_index = player_index # Update caller to this new raiser
	pending_response_action = ResponseAction.TRUCO
	
	TrucoSignalBus.emit_signal("on_truco_called", player_index, next_level)

## Resolves the Truco call after a player accepts or rejects.
func resolve_truco(accepted: bool, answering_player_index: int) -> void:
	print_debug("Truco Level %d Resolved. Accepted: %s" % [proposed_truco_level, accepted])
	pending_response_action = ResponseAction.NONE
	
	if accepted:
		truco_state = TrucoCallState.PLAYED
		current_truco_level = proposed_truco_level
		
		# Update Stakes
		# Truco = 2, Retruco = 3, Vale 4 = 4
		current_stakes = current_truco_level + 1
		
		print_debug("%s Accepted! Sticks: %d" % [_get_truco_name(current_truco_level), current_stakes])
		TrucoSignalBus.emit_signal("on_truco_resolved", true, answering_player_index, current_truco_level)
	else:
		print_debug("%s Rejected! Round Ends." % _get_truco_name(proposed_truco_level))
		# Winner is the one who called (caller_index)
		# Points awarded is dependent on the rejected level
		# Truco rejected -> 1
		# Retruco rejected -> 2
		# Vale 4 rejected -> 3
		var points = proposed_truco_level # Conveniently maps 1->1, 2->2, 3->3
		
		var winner: int = truco_caller_index
		add_score(winner, points)
		TrucoSignalBus.emit_signal("on_truco_resolved", false, answering_player_index, proposed_truco_level)
		
		# End Round
		get_tree().create_timer(1.0).timeout.connect(start_new_hand)

func _get_truco_name(level: int) -> String:
	match level:
		1: return "Truco"
		2: return "Retruco"
		3: return "Vale 4"
	return "None"

func debug_cpu_call_truco() -> void:
	if can_call_truco(1):
		call_truco(1)

func _on_player_truco_called(player_index: int) -> void:
	call_truco(player_index)

## Player gives up the round ("Irse al mazo").
func player_fold(player_index: int) -> void:
	print_debug("Player %d folded (Se fue al mazo)." % player_index)
	var opponent_index = (player_index + 1) % 2
	var points_to_award = 0
	
	# 1. Envido Penalty
	# If Envido turn hasn't finished (meaning it wasn't played yet, and we are in a state where it COULD be played or is being played),
	# the folder loses 1 point for Envido.
	# "Si aun no finalizo el turno del Envido"
	# We consider it "not finished" if state is not PLAYED. 
	# BUT, technically if we are in 2nd round, Envido time is over.
	# Logic: If we are in 1st vuelta (or dealing) and envido not played -> +1.
	var is_envido_time = (vuelta_results.size() == 0) # Only in first vuelta
	if is_envido_time and envido_state != EnvidoCallState.PLAYED:
		print_debug("Fold: Envido not finished. +1 extra point.")
		points_to_award += 1
		
	# 2. Truco Points (No Querido)
	if pending_response_action == ResponseAction.TRUCO:
		# Rejecting a proposal
		points_to_award += proposed_truco_level
	else:
		# Just giving up current stakes
		points_to_award += current_stakes
		
	print_debug("Fold Result: Opponent wins %d points." % points_to_award)
	add_score(opponent_index, points_to_award)
	
	# End Hand
	# We use a short timer to allow UI to maybe show "Folded" message if we wanted, 
	# but for now immediate reset cycle.
	get_tree().create_timer(1.0).timeout.connect(start_new_hand)

func _input(event: InputEvent) -> void:
	# DEBUG: Press E to make CPU call Envido
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		debug_cpu_call_envido()
	# DEBUG: Press T to make CPU call Truco
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		debug_cpu_call_truco()
