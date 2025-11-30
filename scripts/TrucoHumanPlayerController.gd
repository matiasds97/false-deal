class_name TrucoHumanPlayerController
extends TrucoPlayerController

# Reference to the visual Hand script to enable/disable interaction
@export var hand_visual: Node

func _ready() -> void:
	if hand_visual:
		if hand_visual.has_signal("card_selected"):
			hand_visual.card_selected.connect(_on_card_selected)
	else:
		printerr("Hand visual not assigned to TrucoHumanPlayerController!")

func start_turn() -> void:
	super.start_turn()
	print("Waiting for Human Input...")
	if hand_visual and hand_visual.has_method("enable_interaction"):
		hand_visual.enable_interaction()

func _on_card_selected(card: Card, card_node: MeshInstance3D) -> void:
	print("Human selected card: %s" % card)
	if hand_visual:
		if hand_visual.has_method("disable_interaction"):
			hand_visual.disable_interaction()
			
	# Emit signal first so TrucoManager adds card to table
	emit_signal("card_played", card)
	
	# Defer visual throw to next frame so table is updated first
	call_deferred("_do_visual_throw", card_node)

func _do_visual_throw(card_node: MeshInstance3D) -> void:
	if hand_visual:
		if hand_visual.has_method("throw_card"):
			hand_visual.throw_card(card_node)
		if hand_visual.has_method("play_card_throw_sound"):
			hand_visual.play_card_throw_sound()