class_name Table
extends Node

@onready var table_center: Marker3D = $"TableCenter"

## Number of cards played per player side (determines which slot column to use)
var cards_per_player: Array[int] = [0, 0]

func _ready() -> void:
	TrucoSignalBus.on_card_played.connect(_on_card_played)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)

func _on_card_played(player_index: int, card: Card) -> void:
	add_card(player_index, card)

func _on_hand_started(_hand_number: int) -> void:
	clear()

var cards_on_table: Array[Card] = []

## Registers a card as played on the table using the slot grid layout.
## Column is determined by how many cards the player has already played (baza number).
## Row is determined by the player index (human = front, CPU = back).
func add_card(player_index: int, card: Card) -> void:
	var slot_index: int = cards_per_player[player_index]
	
	# Clamp to 3 columns max (shouldn't exceed 3 cards per player)
	slot_index = clampi(slot_index, 0, TrucoConstants.TABLE_SLOT_X.size() - 1)
	
	# Calculate slot position
	var x_pos: float = TrucoConstants.TABLE_SLOT_X[slot_index]
	var z_offset: float = TrucoConstants.HUMAN_ROW_Z if player_index == TrucoConstants.PLAYER_HUMAN else TrucoConstants.CPU_ROW_Z
	var target_pos: Vector3 = table_center.global_position + Vector3(x_pos, 0, z_offset)
	var stack_height: float = get_stack_height(player_index)

	# Emit placement info BEFORE incrementing count
	TrucoSignalBus.card_placement_info.emit(player_index, target_pos, stack_height)

	cards_per_player[player_index] += 1
	cards_on_table.append(card)


## Clears all cards from the table (used at hand start).
func clear() -> void:
	cards_on_table.clear()
	cards_per_player = [0, 0]

## Returns the Y offset for the next card on a player's side to avoid z-fighting.
func get_stack_height(player_index: int) -> float:
	var count: int = cards_per_player[player_index] if player_index < cards_per_player.size() else 0
	return 0.01 + (count * TrucoConstants.CARD_STACK_HEIGHT)
