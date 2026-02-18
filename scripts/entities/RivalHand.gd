class_name RivalHand
extends BaseHand

## CPU player's hand visualization.
## Shows cards face-down and animates them when the CPU plays.
## Extends BaseHand for shared card management logic.


func _ready() -> void:
	_setup_card_placeholders()
	_reset_card_nodes(true)
	
	# Connect to SignalBus
	_connect_base_signals()
	TrucoSignalBus.on_card_played.connect(_on_card_played)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)


func _on_hand_started(_hand_number: int) -> void:
	_reset_card_nodes(true)


func _on_card_played(player_index: int, card: Card) -> void:
	if player_index == TrucoConstants.PLAYER_CPU:
		play_card(card)


## Plays a card from the rival's hand onto the table.
## Finds the first visible card in hand, applies the texture, and throws it.
## [param card_data]: The Card resource containing visual data.
func play_card(card_data: Card) -> void:
	# Find the first visible card to "throw"
	var card_node: CardVisual = null
	for c in card_nodes:
		if c.visible and c.get_parent() == self:
			card_node = c
			break
	
	if not card_node:
		printerr("Rival has no cards to throw!")
		return

	_update_card_visuals(card_node, card_data)
	_throw_card_to_table(card_node)
