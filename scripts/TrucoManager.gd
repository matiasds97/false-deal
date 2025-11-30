extends Node
class_name TrucoManager

@export var deck: Deck
@export var player_nodes: Array[Node]
@export var table: Table

var current_state = TrucoState.WAITING_FOR_START
var players: Array[Player] = []
var dealer_index = 0
var mano_index: int = 0
var current_turn_index: int = 0

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
	dealer_index = randi() % players.size()
	start_new_hand()

func start_new_hand() -> void:
	current_state = TrucoState.DEALING
	
	# Clear table from previous hand
	if table:
		table.clear()

	dealer_index = (dealer_index + 1) % players.size()
	mano_index = (dealer_index + 1) % players.size()
	current_turn_index = mano_index

	print("NewHand.Dealer: %s, Mano: %s, Turn: %s" % [players[dealer_index].name, players[mano_index].name, players[current_turn_index].name])
	emit_signal("new_hand_started", 1)

	deal_cards()

func deal_cards() -> void:
	if not deck:
		printerr("NodeckassignedtoTrucoManager!")
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
	
	print("Cards dealt.")
	start_turn_cycle()

func start_turn_cycle() -> void:
	if players[current_turn_index].is_human:
		current_state = TrucoState.PLAYER_TURN
	else:
		current_state = TrucoState.RIVAL_TURN

	print("Turn: %s" % players[current_turn_index].name)
	emit_signal("turn_started", current_turn_index)

	# Trigger the controller!
	if current_turn_index < player_nodes.size():
		player_nodes[current_turn_index].start_turn()

func _on_player_card_played(card: Card, player_index: int) -> void:
	if player_index != current_turn_index:
		printerr("Player %d played out of turn!" % player_index)
		return
		
	print("Player %d played %s" % [player_index, card])
	
	# Add to logical table
	if table:
		table.add_card(card)
		
	# Remove from player hand (Logic)
	players[player_index].play_specific_card(card)
	
	# Advance turn
	advance_turn()

func advance_turn() -> void:
	# Check if Baza is over (2 cards played for 2 players)
	if table and table.cards_on_table.size() >= players.size():
		# Wait a bit before resolving so players can see the cards
		get_tree().create_timer(1.0).timeout.connect(resolve_baza)
	else:
		current_turn_index = (current_turn_index + 1) % players.size()
		start_turn_cycle()

func resolve_baza() -> void:
	print("Resolving Baza...")
	# TODO: Determine winner properly
	# Note: We DON'T clear the table here - cards accumulate across all 3 bazas
	# The table will be cleared when starting a new hand
	
	# Winner of baza starts next one (TODO: Implement winner logic)
	# For now, just keep rotating
	current_turn_index = (current_turn_index + 1) % players.size()
	start_turn_cycle()
