extends Node
class_name TrucoManager

@export var deck: Deck
@export var player_nodes: Array[Node]

var current_state = TrucoState.WAITING_FOR_START
var players: Array[Player] = []
var dealer_index = 0
var mano_index: int = 0
var current_turn_index: int = 0
var cards_played_current_vuelta: Array[Dictionary] = [] # Stores { "card": Card, "player_index": int }
var vuelta_results: Array[int] = [] # Stores winner of each vuelta (-1 for tie)
var player_scores: Dictionary = {0: 0, 1: 0}
var mano_player_index: int = 0


signal match_started
signal new_hand_started(hand_number: int)
signal turn_started(player_index: int)

func _ready() -> void:
	var p1 = Player.new("Human", true, 0)
	var p2 = Player.new("CPU", false, 1)
	players = [p1, p2]

	# Initialize controllers
	if player_nodes.size() == players.size():
		for i in range(players.size()):
			if player_nodes[i].has_method("initialize"):
				player_nodes[i].initialize(players[i])
				if player_nodes[i].has_signal("card_played"):
					player_nodes[i].card_played.connect(_on_player_card_played.bind(i))
	else:
		printerr("Mismatch between Players count and Player Nodes count!")

	call_deferred("start_match")

func start_match() -> void:
	print("Truco match started!")
	emit_signal("match_started")
	
	# Emit initial score
	TrucoSignalBus.emit_signal("on_score_updated", player_scores[0], player_scores[1])
	
	dealer_index = randi() % players.size()
	start_new_hand()

func start_new_hand() -> void:
	current_state = TrucoState.DEALING
	
	cards_played_current_vuelta.clear()
	vuelta_results.clear()

	dealer_index = (dealer_index + 1) % players.size()
	mano_index = (dealer_index + 1) % players.size()
	mano_player_index = mano_index
	current_turn_index = mano_index

	print("NewHand.Dealer: %s, Mano: %s, Turn: %s" % [players[dealer_index].name, players[mano_index].name, players[current_turn_index].name])
	
	TrucoSignalBus.emit_signal("on_hand_started", 1)
	emit_signal("new_hand_started", 1) # Keep local signal for now if needed by other logic

	deal_cards()

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
			var card = deck.draw_card()
			if card:
				players[player_index].receive_card(card)
				# Emit via SignalBus
				TrucoSignalBus.emit_signal("on_card_dealt", player_index, card)
	
	print("Cards dealt.")
	start_turn_cycle()

func start_turn_cycle() -> void:
	if players[current_turn_index].is_human:
		current_state = TrucoState.PLAYER_TURN
	else:
		current_state = TrucoState.RIVAL_TURN

	print("Turn: %s" % players[current_turn_index].name)
	
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
		
	print("Player %d played %s" % [player_index, card])
	
	# Emit via SignalBus
	TrucoSignalBus.emit_signal("on_card_played", player_index, card)
	
	# Track internally
	cards_played_current_vuelta.append({"card": card, "player_index": player_index})
		
	# Remove from player hand (Logic)
	players[player_index].play_specific_card(card)
	
	# Advance turn
	advance_turn()

func advance_turn() -> void:
	# Check if Baza is over (2 cards played for 2 players)
	if cards_played_current_vuelta.size() >= players.size():
		# Wait a bit before resolving so players can see the cards
		get_tree().create_timer(1.0).timeout.connect(resolve_vuelta)
	else:
		current_turn_index = (current_turn_index + 1) % players.size()
		start_turn_cycle()

func resolve_vuelta() -> void:
	print("Resolving Vuelta...")
	
	if cards_played_current_vuelta.size() != 2:
		printerr("Error: resolve_vuelta called with %d cards!" % cards_played_current_vuelta.size())
		return

	var c1_data = cards_played_current_vuelta[0]
	var c2_data = cards_played_current_vuelta[1]
	
	var c1 = c1_data["card"] as Card
	var c2 = c2_data["card"] as Card
	
	var comparison = c1.compare(c2)
	var winner_index = -1
	
	if comparison > 0:
		winner_index = c1_data["player_index"]
		print("Vuelta winner: Player %d" % winner_index)
	elif comparison < 0:
		winner_index = c2_data["player_index"]
		print("Vuelta winner: Player %d" % winner_index)
	else:
		winner_index = -1
		print("Vuelta result: Parda (Tie)")
		
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

func check_round_winner() -> bool:
	var round_winner = -1
	var reason = ""
	
	# Parda Rules Logic
	# 1. Parda in 1st Vuelta: The winner of the 2nd Vuelta wins the round.
	# 2. Parda in 1st and 2nd Vuelta: The winner of the 3rd Vuelta wins the round.
	# 3. Parda in 1st, 2nd, and 3rd Vuelta: The player who is "Mano" wins.
	# 4. Parda in 2nd Vuelta (after a winner in 1st): The winner of the 1st Vuelta wins the round.
	# 5. Parda in 3rd Vuelta (after split wins in 1st and 2nd): The winner of the 1st Vuelta wins the round.
	
	if vuelta_results.size() == 2:
		var v1 = vuelta_results[0]
		var v2 = vuelta_results[1]
		
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
		var v1 = vuelta_results[0]
		var v2 = vuelta_results[1]
		var v3 = vuelta_results[2]
		
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
		print("Round Ended! Winner: Player %d (%s)" % [round_winner, reason])
		player_scores[round_winner] += 1
		print("Score: Player 0: %d - Player 1: %d" % [player_scores[0], player_scores[1]])
		
		# Emit score update
		TrucoSignalBus.emit_signal("on_score_updated", player_scores[0], player_scores[1])
		
		# Wait a bit then start new hand
		get_tree().create_timer(2.0).timeout.connect(start_new_hand)
		return true
		
	return false
