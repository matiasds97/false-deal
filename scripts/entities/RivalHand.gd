class_name RivalHand
extends BaseHand

## CPU player's hand visualization.
## Shows cards face-down and animates them when the CPU plays.
## Extends BaseHand for shared card management logic.
##
## Tracks which logical Card maps to which visual CardVisual node,
## so the correct visual card is thrown when the CPU plays.

## Maps logical Card → visual CardVisual node index.
var _card_to_node: Dictionary = {}
var _deal_index: int = 0


func _get_player_index() -> int:
	return TrucoConstants.PLAYER_CPU


func _ready() -> void:
	_setup_card_placeholders()
	_reset_card_nodes(true)

	# Connect to SignalBus
	_connect_base_signals()
	TrucoSignalBus.on_card_dealt.connect(_on_card_dealt)
	TrucoSignalBus.on_card_played.connect(_on_card_played)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)


func _on_hand_started(_hand_number: int) -> void:
	_card_to_node.clear()
	_deal_index = 0
	_reset_card_nodes(true)


func _on_card_dealt(player_index: int, card: Card) -> void:
	if player_index != TrucoConstants.PLAYER_CPU:
		return

	# Map this card to the next available card node
	if _deal_index < card_nodes.size():
		_card_to_node[card] = _deal_index
		_deal_index += 1


func _on_card_played(player_index: int, card: Card) -> void:
	if player_index == TrucoConstants.PLAYER_CPU:
		play_card(card)


## Plays a card from the rival's hand onto the table.
## Finds the specific card node mapped to this logical card and throws it.
## [param card_data]: The Card resource containing visual data.
func play_card(card_data: Card) -> void:
	var card_node: CardVisual = null

	# Look up the correct node for this card
	if _card_to_node.has(card_data):
		var idx: int = _card_to_node[card_data]
		if idx < card_nodes.size():
			card_node = card_nodes[idx]
			_card_to_node.erase(card_data)

	# Fallback: find first visible card still in hand (shouldn't happen normally)
	if not card_node:
		for c in card_nodes:
			if c.visible and c.get_parent() == self:
				card_node = c
				break

	if not card_node:
		printerr("Rival has no cards to throw!")
		return

	_update_card_visuals(card_node, card_data)
	_throw_card_to_table(card_node, card_data)
