class_name RivalHand
extends Node3D

@export var card_prefab: PackedScene = preload("res://scenes/prefabs/card.tscn")
@onready var card_sounds_player: AudioStreamPlayer3D = $CardSoundsPlayer

var card_sounds: Array[AudioStream] = [
	load("res://assets/audio/sounds/card-place-1.ogg"),
	load("res://assets/audio/sounds/card-place-2.ogg"),
	load("res://assets/audio/sounds/card-place-3.ogg")
]

var cards: Array[CardVisual] = []
var initial_transforms: Array[Transform3D] = []

# Cached placement info from Table via SignalBus
var cached_target_position: Vector3 = Vector3.ZERO
var cached_stack_height: float = 0.0

func _ready() -> void:
	var placeholders = [$Card1, $Card2, $Card3]
	
	for i in range(placeholders.size()):
		var p = placeholders[i]
		if p:
			initial_transforms.append(p.transform)
			p.visible = false
			
			var visual = card_prefab.instantiate() as CardVisual
			add_child(visual)
			visual.transform = p.transform
			visual.visible = false # start hidden until dealt/reset
			cards.append(visual)
			
			p.queue_free()
	
	reset_hand()
	
	# Connect to SignalBus
	TrucoSignalBus.on_card_played.connect(_on_card_played)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)
	TrucoSignalBus.card_placement_info.connect(_on_card_placement_info)

func _on_hand_started(_hand_number: int) -> void:
	reset_hand()

func _on_card_played(player_index: int, card: Card) -> void:
	# CPU is player 1
	if player_index == TrucoConstants.PLAYER_CPU:
		play_card(card)

func _on_card_placement_info(target_position: Vector3, stack_height: float) -> void:
	cached_target_position = target_position
	cached_stack_height = stack_height

func reset_hand() -> void:
	for i in range(cards.size()):
		var c: CardVisual = cards[i]
		
		# Reparent if it was thrown
		if c.get_parent() != self:
			c.reparent(self, false)
		
		c.visible = true
		c.transform = initial_transforms[i]
		# TODO: Set to face-down texture if you have one
		# For now they'll show the last card texture

func play_card(card_data: Card) -> void:
	# Find the first visible card to "throw"
	var card_node: CardVisual = null
	for c in cards:
		if c.visible and c.get_parent() == self:
			card_node = c
			break
	
	if not card_node:
		printerr("Rival has no cards to throw!")
		return

	# Apply texture/material
	if card_data.custom_material:
		card_node.set_front_material(card_data.custom_material)
	else:
		card_node.set_front_texture(card_data.image)
	# card_node.set_back_texture(...) # handled by CardVisual default
	
	# Reparent to scene root
	var new_parent: Node = get_parent()
	if new_parent:
		card_node.reparent(new_parent, true)
	
	# Use cached placement info from Table (via SignalBus)
	var target_pos: Vector3 = cached_target_position
	# Add randomness
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var random_offset: Vector3 = Vector3(rng.randf_range(-0.009, 0.009), 0, rng.randf_range(-0.009, 0.009))
	target_pos += random_offset
	
	# Apply stack height from cached info
	target_pos.y += cached_stack_height
	
	play_card_throw_sound()
	
	# Animate
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(card_node, "global_position", target_pos, TrucoManager.CARD_THROW_DURATION)
	
	# Rotate to face up (assuming Y rotation is yaw, and X/Z is flip)
	# We want it flat on table, face up.
	var random_rot_y: float = rng.randf_range(0, 360)
	var final_rotation: Vector3 = Vector3(0, deg_to_rad(random_rot_y), 0)
	tween.tween_property(card_node, "global_rotation", final_rotation, 0.6)

func play_card_throw_sound() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	card_sounds_player.stream = card_sounds[rng.randi_range(0, card_sounds.size() - 1)]
	card_sounds_player.play()
