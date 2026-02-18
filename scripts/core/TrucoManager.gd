class_name TrucoManager
extends Node

## Controller class that bridges the Pure Logic (TrucoGame) with the Visuals/Input (Godot Nodes).
## Handles visual delays, animation triggers, and input delegation.

## ------- SIGNALS -------
signal match_started
signal new_hand_started(hand_number: int)
signal turn_started(player_index: int)

## ------- EXPORT VARIABLES -------
@export var deck: Deck
@export var player_nodes: Array[Node]

## ------- PUBLIC VARIABLES -------
# Use TrucoConstants.CARD_THROW_DURATION for animation timing
static var CARD_THROW_DURATION: float:
	get: return TrucoConstants.CARD_THROW_DURATION
var game: TrucoGame
var players: Array[Player] = []

# Forwarding Enums for convenience (optional, or clients can load TrucoGame)
# We can't easily export Enums from another inner class in GDScript 2.0 unless we user named classes.
# TrucoGame is a named class, so clients can use TrucoGame.EnvidoType

# --- DELEGATE PROPERTIES ---
var current_turn_index: int:
	get: return game.current_turn_index

var envido_chain: Array[int]:
	get: return game.envido_chain

var current_truco_level: int:
	get: return game.current_truco_level

var proposed_truco_level: int:
	get: return game.proposed_truco_level

var pending_response_action: int:
	get: return game.pending_response_action

var flor_state: int:
	get: return game.flor_state

var flor_chain: Array[int]:
	get: return game.flor_chain

# --- LIFECYCLE ---

func _ready() -> void:
	var _p1: Player = Player.new("Human", true, 0)
	var _p2: Player = Player.new("CPU", false, 1)
	players = [_p1, _p2]

	_find_player_nodes_if_missing()
	_initialize_player_controllers()
	
	# Initialize Game Logic
	game = TrucoGame.new(players, deck)
	_connect_game_signals()
	# Match start is triggered by TrucoUI after the splash screen finishes

func start_match() -> void:
	print_debug("TrucoManager: Starting Match...")
	game.start_match()

# --- DELEGATE METHODS (API Facade) ---

func can_call_envido(type: int, player_index: int) -> bool:
	return game.can_call_envido(type, player_index)

func call_envido(type: int, player_index: int) -> void:
	game.call_envido(type, player_index)

func resolve_envido(accepted: bool, player_index: int) -> void:
	game.resolve_envido(accepted, player_index)

func can_call_truco(player_index: int) -> bool:
	return game.can_call_truco(player_index)

func call_truco(player_index: int) -> void:
	game.call_truco(player_index)

func resolve_truco(accepted: bool, player_index: int) -> void:
	game.resolve_truco(accepted, player_index)

func player_fold(player_index: int) -> void:
	game.player_fold(player_index)

func can_call_flor(type: int, player_index: int) -> bool:
	return game.can_call_flor(type, player_index)

func call_flor(type: int, player_index: int) -> void:
	game.call_flor(type, player_index)

func resolve_flor(accepted: bool, player_index: int) -> void:
	game.resolve_flor(accepted, player_index)

# --- INPUT HANDLERS (From Controllers) ---

func on_player_play_card(card: Card, player_index: int) -> void:
	game.play_card(player_index, card)

func on_player_call_envido(player_index: int) -> void:
	game.call_envido(TrucoConstants.EnvidoType.ENVIDO, player_index)

func on_player_call_truco(player_index: int) -> void:
	game.call_truco(player_index)

# --- GAME SIGNAL HANDLERS ---

func _connect_game_signals() -> void:
	if not game: return
	
	game.match_started.connect(func(): match_started.emit())
	
	game.hand_started.connect(func(hand_num):
		TrucoSignalBus.on_hand_started.emit(hand_num)
		new_hand_started.emit(hand_num)
	)
	
	game.turn_started.connect(_on_turn_started)
	
	game.card_dealt.connect(func(p_idx, card):
		TrucoSignalBus.on_card_dealt.emit(p_idx, card)
	)
	
	game.card_played.connect(_on_card_played)
	
	game.envido_called.connect(func(p_idx, type):
		TrucoSignalBus.on_envido_called.emit(p_idx, type)
	)
	
	game.envido_resolved.connect(func(accepted, winner, points):
		TrucoSignalBus.on_envido_resolved.emit(accepted, winner, points)
	)
	
	game.truco_called.connect(func(p_idx, level):
		TrucoSignalBus.on_truco_called.emit(p_idx, level)
	)
	
	game.truco_resolved.connect(func(accepted, winner, level):
		TrucoSignalBus.on_truco_resolved.emit(accepted, winner, level)
	)

	game.flor_called.connect(func(p_idx, type):
		TrucoSignalBus.on_flor_called.emit(p_idx, type)
	)
	
	game.flor_resolved.connect(func(accepted, winner, points):
		TrucoSignalBus.on_flor_resolved.emit(accepted, winner, points)
	)
	
	game.score_updated.connect(func(s0, s1):
		TrucoSignalBus.on_score_updated.emit(s0, s1)
	)
	
	game.round_ended.connect(_on_round_ended)
	
	game.match_ended.connect(func(winner):
		print_debug("Match Finished. Winner: %d" % winner)
		TrucoSignalBus.on_match_ended.emit(winner)
	)

func _on_turn_started(player_index: int) -> void:
	print_debug("TrucoManager: Turn %d" % player_index)
	TrucoSignalBus.on_turn_started.emit(player_index)
	turn_started.emit(player_index)
	
	if player_index < player_nodes.size():
		player_nodes[player_index].start_turn()

func _on_card_played(player_index: int, card: Card) -> void:
	# Visual only
	print_debug("TrucoManager: Player %d played %s" % [player_index, card])
	TrucoSignalBus.on_card_played.emit(player_index, card)

func _on_round_ended(winner: int, reason: String) -> void:
	print_debug("TrucoManager: Round Ended (%s). Winner: %d" % [reason, winner])
	# If the match is over, don't start a new hand
	if game.current_state == TrucoGame.TrucoState.MATCH_ENDED:
		return
	# Wait for delay before starting new hand
	get_tree().create_timer(TrucoConstants.NEW_HAND_DELAY).timeout.connect(func():
		game.start_new_hand()
	)

# --- SETUP HELPERS ---

func _find_player_nodes_if_missing() -> void:
	if player_nodes.is_empty():
		var human_node: Node = get_node_or_null("../HumanPlayer")
		var cpu_node: Node = get_node_or_null("../CPUPlayer")
		if human_node and cpu_node:
			player_nodes = [human_node, cpu_node]

func _initialize_player_controllers() -> void:
	if player_nodes.size() == players.size():
		for i in range(players.size()):
			if player_nodes[i].has_method("initialize"):
				player_nodes[i].initialize(players[i])
				_connect_player_node_signals(i)

func _connect_player_node_signals(index: int) -> void:
	var node = player_nodes[index]
	if node.has_signal("card_played") and not node.card_played.is_connected(on_player_play_card):
		node.card_played.connect(on_player_play_card.bind(index))
	
	if node.has_signal("envido_called") and not node.envido_called.is_connected(on_player_call_envido):
		node.envido_called.connect(on_player_call_envido.bind(index))
	
	if node.has_signal("truco_called") and not node.truco_called.is_connected(on_player_call_truco):
		node.truco_called.connect(on_player_call_truco.bind(index))
