class_name CPUCardPlayStrategy
extends RefCounted

## CPU strategy for choosing which card to play.
## Currently plays the first available card (basic strategy).
## Can be extended with smarter card selection logic.

var _player: Player

func _init(player: Player) -> void:
	_player = player


## Selects a card to play from the CPU's hand.
## Returns the selected Card, or null if no cards are available.
func select_card() -> Card:
	if _player.hand.size() > 0:
		return _player.hand[0]
	return null
