class_name RivalHand
extends Node3D

@onready var card_1: MeshInstance3D = $Card1
@onready var card_2: MeshInstance3D = $Card2
@onready var card_3: MeshInstance3D = $Card3
@onready var table_center: Marker3D = $"../Table/TableCenter" # Adjust path if needed
@onready var card_sounds_player: AudioStreamPlayer3D = $CardSoundsPlayer

var card_sounds: Array[AudioStream] = [
	load("res://audio/sounds/card-place-1.ogg"),
	load("res://audio/sounds/card-place-2.ogg"),
	load("res://audio/sounds/card-place-3.ogg")
]

var cards: Array[MeshInstance3D] = []
var initial_transforms: Array[Transform3D] = []

@export var table: Table

func _ready() -> void:
	cards = [card_1, card_2, card_3]
	for c in cards:
		initial_transforms.append(c.transform)
	
	for c in cards:
		initial_transforms.append(c.transform)
	
	reset_hand()
	
	# Connect to SignalBus
	TrucoSignalBus.on_card_played.connect(_on_card_played)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)

func _on_hand_started(_hand_number: int) -> void:
	reset_hand()

func _on_card_played(player_index: int, card: Card) -> void:
	# Assuming CPU is player 1
	if player_index == 1:
		play_card(card)

func reset_hand() -> void:
	for i in range(cards.size()):
		var c = cards[i]
		
		# Reparent if it was thrown
		if c.get_parent() != self:
			c.reparent(self, false)
		
		c.visible = true
		c.transform = initial_transforms[i]
		# TODO: Set to face-down texture if you have one
		# For now they'll show the last card texture

func play_card(card_data: Card) -> void:
	# Find the first visible card to "throw"
	var card_node: MeshInstance3D = null
	for c in cards:
		if c.visible and c.get_parent() == self:
			card_node = c
			break
	
	if not card_node:
		printerr("Rival has no cards to throw!")
		return

	# Apply texture so we see what card it is
	card_node.set_surface_override_material(0, card_data.material)
	card_node.get_surface_override_material(0).albedo_texture = card_data.image
	
	# Reparent to scene root
	var new_parent = get_parent()
	if new_parent:
		card_node.reparent(new_parent, true)
	
	var target_pos = table_center.global_position
	# Add randomness
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var random_offset = Vector3(rng.randf_range(-0.009, 0.009), 0, rng.randf_range(-0.009, 0.009))
	target_pos += random_offset
	
	# Stack height from Table
	if table:
		var stack_height = table.get_stack_height()
		print("[RivalHand] Table has %d cards, stack height: %.4f" % [table.cards_on_table.size(), stack_height])
		target_pos.y += stack_height
	else:
		printerr("Table not assigned to RivalHand!")
	
	play_card_throw_sound()
	
	# Animate
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(card_node, "global_position", target_pos, 0.7)
	
	# Rotate to face up (assuming Y rotation is yaw, and X/Z is flip)
	# We want it flat on table, face up.
	var random_rot_y = rng.randf_range(0, 360)
	var final_rotation = Vector3(0, deg_to_rad(random_rot_y), 0)
	tween.tween_property(card_node, "global_rotation", final_rotation, 0.6)

func play_card_throw_sound() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	card_sounds_player.stream = card_sounds[rng.randi_range(0, card_sounds.size() - 1)]
	card_sounds_player.play()
