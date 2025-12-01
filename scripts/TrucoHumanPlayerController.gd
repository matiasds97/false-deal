class_name TrucoHumanPlayerController
extends TrucoPlayerController

# Reference to the visual Hand script to enable/disable interaction
# @export var hand_visual: Node # Removed: Decoupled via SignalBus

func _ready() -> void:
	# Listen for user input via SignalBus
	TrucoSignalBus.on_user_input_card_selected.connect(_on_card_selected_input)

func _on_card_selected_input(card: Card) -> void:
	_on_card_selected(card, null)

func start_turn() -> void:
	super.start_turn()
	print("Waiting for Human Input...")
	# Hand interaction enabling should be handled by Hand.gd listening to on_turn_started
	# But Hand.gd needs to know if it's OUR turn.
	# For now, let's keep the direct signal connection in _ready if possible, OR
	# Hand.gd should emit a global signal when a card is selected?
	# Actually, Hand.gd is visual. Input handling is tricky.
	# Let's keep the signal connection in _ready for INPUT, but remove visual manipulation.
	pass

func _on_card_selected(card: Card, _card_node: MeshInstance3D) -> void:
	print("Human selected card: %s" % card)
	
	# Emit signal first so TrucoManager adds card to table (and SignalBus notifies visuals)
	emit_signal("card_played", card)
	
	# Visual throw is now handled by Hand.gd listening to TrucoSignalBus.on_card_played