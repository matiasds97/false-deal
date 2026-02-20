class_name CardThrowHelper
extends RefCounted

## Utility class for card throw animations and sounds.
## Consolidates shared logic previously duplicated in Hand.gd and RivalHand.gd.

## Throws a card node toward a target position with animation.
## [param card_node]: The CardVisual node to animate.
## [param new_parent]: The parent to reparent the card to (typically scene root).
## [param target_position]: Where the card should land (world space).
## [param stack_height]: Y-offset for stacking on table.
## [param tween_owner]: Node to create the tween from.
## [param duration]: Animation duration in seconds.
static func throw_card(
	card_node: CardVisual,
	new_parent: Node,
	target_position: Vector3,
	stack_height: float,
	tween_owner: Node,
	duration: float = TrucoConstants.CARD_THROW_DURATION
) -> void:
	if not card_node.visible: return

	# Reparent to scene root
	if new_parent:
		card_node.reparent(new_parent, true)
		card_node.scale = Vector3.ONE

	# Add subtle scatter within the slot for a natural feel
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var target_pos := target_position
	var scatter: float = TrucoConstants.SLOT_SCATTER
	target_pos += Vector3(rng.randf_range(-scatter, scatter), 0, rng.randf_range(-scatter, scatter))
	target_pos.y += stack_height

	# Animate movement and rotation
	var tween: Tween = tween_owner.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(card_node, "global_position", target_pos, duration)

	# Small random Y-axis rotation so cards land nearly aligned but with natural variation
	var rot_range: float = TrucoConstants.SLOT_ROTATION_RANGE
	var random_rot_y: float = rng.randf_range(-rot_range, rot_range)
	var final_rotation := Vector3(0, deg_to_rad(random_rot_y), 0)
	tween.tween_property(card_node, "global_rotation", final_rotation, duration * 0.8)


## Plays a random card placement sound from the provided array.
## [param audio_player]: The AudioStreamPlayer3D to use.
## [param sounds]: Array of AudioStream sounds to pick from.
## [param volume_linear]: Volume scale (0.0 to 1.0).
static func play_random_card_sound(
	audio_player: AudioStreamPlayer3D,
	sounds: Array[AudioStream],
	volume_linear: float = 1.0
) -> void:
	if sounds.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	audio_player.stream = sounds[rng.randi_range(0, sounds.size() - 1)]
	audio_player.volume_db = linear_to_db(volume_linear)
	audio_player.play()


## Plays a suit-specific sound if available.
## [param audio_player]: The AudioStreamPlayer3D to use (should be separate from card placement player).
## [param suit_sounds]: Dictionary mapping Card.Suit enum values to AudioStream resources.
## [param suit]: The suit of the card being played.
## [param volume_linear]: Volume scale (0.0 to 1.0).
static func play_suit_sound(
	audio_player: AudioStreamPlayer3D,
	suit_sounds: Dictionary,
	suit: int,
	volume_linear: float = 1.0
) -> void:
	if not audio_player or suit_sounds.is_empty(): return
	
	if suit_sounds.has(suit):
		audio_player.stream = suit_sounds[suit]
		audio_player.volume_db = linear_to_db(volume_linear)
		audio_player.play()
