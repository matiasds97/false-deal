class_name TrucoCPUPlayerController
extends TrucoPlayerController

@export var rival_hand_visual: RivalHand

func start_turn() -> void:
	super.start_turn()
	# Simulate thinking time
	get_tree().create_timer(1.0).timeout.connect(_make_decision)

func _make_decision() -> void:
	# Simple AI: Play first available card
	if player.hand.size() > 0:
		var card_to_play: Card = player.hand[0]
		
		# Emit signal first so TrucoManager adds card to table
		emit_signal("card_played", card_to_play)
		print("CPU played: " + str(card_to_play))
		
		# Defer visual throw to next frame so table is updated first
		call_deferred("_do_visual_throw", card_to_play)

func _do_visual_throw(card: Card) -> void:
	if rival_hand_visual and rival_hand_visual.has_method("play_card"):
		rival_hand_visual.play_card(card)
	else:
		printerr("Rival hand visual not assigned to TrucoCPUPlayerController!")
