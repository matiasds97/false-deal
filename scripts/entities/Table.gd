class_name Table
extends Node

@onready var table_center: Marker3D = $"TableCenter"

func _ready() -> void:
	TrucoSignalBus.on_card_played.connect(_on_card_played)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)

func _on_card_played(_player_index: int, card: Card) -> void:
	add_card(card)

func _on_hand_started(_hand_number: int) -> void:
	clear()

var cards_on_table: Array[Card] = []

func add_card(card: Card) -> void:
	# Emit placement info BEFORE adding card so Hand scripts have current stack height
	var target_pos: Vector3 = table_center.global_position
	var stack_height: float = get_stack_height()
	TrucoSignalBus.card_placement_info.emit(target_pos, stack_height)
	
	cards_on_table.append(card)


func clear() -> void:
	cards_on_table.clear()

# Returns the Y offset for the next card to be placed on the table
func get_stack_height() -> float:
	# Base height to avoid z-fighting with table + stacking offset per card
	var height: float = 0.01 + (cards_on_table.size() * 0.0005) # Increased from 0.001 to 0.005
	return height
