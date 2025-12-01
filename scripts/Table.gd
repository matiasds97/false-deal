class_name Table
extends Node

func _ready() -> void:
	TrucoSignalBus.on_card_played.connect(_on_card_played)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)

func _on_card_played(_player_index: int, card: Card) -> void:
	add_card(card)

func _on_hand_started(_hand_number: int) -> void:
	clear()

var cards_on_table: Array[Card] = []

# Returns 1 if card1 wins, -1 if card2 wins, 0 if tie
func compare_cards(card1: Card, card2: Card) -> int:
	return card1.compare(card2)

func add_card(card: Card) -> void:
	cards_on_table.append(card)
	print("[Table] Card added. Total cards on table: %d" % cards_on_table.size())


func clear() -> void:
	cards_on_table.clear()

# Returns the Y offset for the next card to be placed on the table
func get_stack_height() -> float:
	# Base height to avoid z-fighting with table + stacking offset per card
	var height = 0.01 + (cards_on_table.size() * 0.005) # Increased from 0.001 to 0.005
	print("[Table] get_stack_height called, cards_on_table.size=%d, returning %.4f" % [cards_on_table.size(), height])
	return height
