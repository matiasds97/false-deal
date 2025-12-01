class_name TrucoCPUPlayerController
extends TrucoPlayerController

# @export var rival_hand_visual: RivalHand # Removed: Decoupled via SignalBus

func start_turn() -> void:
	super.start_turn()
	# Simulate thinking time
	get_tree().create_timer(1.0).timeout.connect(_make_decision)

func _make_decision() -> void:
	# Simple AI: Play first available card
	if player.hand.size() > 0:
		var card_to_play: Card = player.hand[0]
		
		# Emit signal first so TrucoManager adds card to table (and SignalBus notifies visuals)
		emit_signal("card_played", card_to_play)
		print("CPU played: " + str(card_to_play))
		
		# Visual throw is now handled by RivalHand.gd listening to TrucoSignalBus.on_card_played
