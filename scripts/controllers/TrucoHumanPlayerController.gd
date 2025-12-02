class_name TrucoHumanPlayerController
extends TrucoPlayerController

## This controller is used for the Human player in the game.
## It handles the input from the user and emits the card played signal.

func _ready() -> void:
	TrucoSignalBus.on_user_input_card_selected.connect(_on_card_selected_input)

func _on_card_selected_input(card: Card) -> void:
	_on_card_selected(card, null)

func start_turn() -> void:
	super.start_turn()
	pass

func _on_card_selected(card: Card, _card_node: MeshInstance3D) -> void:
	emit_signal("card_played", card)
