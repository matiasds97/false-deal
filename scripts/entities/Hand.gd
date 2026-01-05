extends Marker3D

@onready var card_1: MeshInstance3D = $Card1
@onready var card_2: MeshInstance3D = $Card2
@onready var card_3: MeshInstance3D = $Card3
@onready var card_sounds_player: AudioStreamPlayer3D = $CardSoundsPlayer

var card_sounds: Array[AudioStream] = [
	load("res://assets/audio/sounds/card-place-1.ogg"),
	load("res://assets/audio/sounds/card-place-2.ogg"),
	load("res://assets/audio/sounds/card-place-3.ogg")
]

var cards_in_hand: Array[Card] = []
var initial_transforms: Array[Transform3D] = []
var hover_tweens: Dictionary = {}

# Cached placement info from Table via SignalBus
var cached_target_position: Vector3 = Vector3.ZERO
var cached_stack_height: float = 0.0

signal envido_calculated(score: int)
signal flor_detected(has_flor: bool)
signal card_selected(card: Card, card_node: MeshInstance3D)

var can_interact: bool = false


func _ready() -> void:
	# Store initial transforms
	initial_transforms.append(card_1.transform)
	initial_transforms.append(card_2.transform)
	initial_transforms.append(card_3.transform)
	
	# Emit signals deferredly to ensure UI is ready and connected
	call_deferred("_emit_initial_signals")
	
	# Connect to SignalBus
	TrucoSignalBus.on_card_dealt.connect(_on_card_dealt)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)
	TrucoSignalBus.on_turn_started.connect(_on_turn_started)
	TrucoSignalBus.on_card_played.connect(_on_card_played)
	TrucoSignalBus.card_placement_info.connect(_on_card_placement_info)

func _on_turn_started(player_index: int) -> void:
	if player_index == 0: # Human
		enable_interaction()
	else:
		disable_interaction()

func _on_card_played(player_index: int, card: Card) -> void:
	if player_index == 0: # Human
		disable_interaction()
		
		# Find the card node corresponding to this card
		var card_idx: int = -1
		for i in range(cards_in_hand.size()):
			if cards_in_hand[i] == card: # Assuming Card resource equality works (same instance)
				card_idx = i
				break
		
		if card_idx != -1:
			var card_nodes: Array[Variant] = [card_1, card_2, card_3]
			if card_idx < card_nodes.size():
				var node = card_nodes[card_idx]
				play_card_throw_sound()
				throw_card(node)
		else:
			printerr("Hand: Played card not found in hand!")

func _on_hand_started(_hand_number: int) -> void:
	deal_new_hand()

func _on_card_dealt(player_index: int, card: Card) -> void:
	if player_index == 0: # Human
		cards_in_hand.append(card)
		var idx: int = cards_in_hand.size() - 1
		var card_nodes: Array[Variant] = [card_1, card_2, card_3]
		
		if idx < card_nodes.size():
			var card_node = card_nodes[idx]
			
			# Ensure it's back in hand (just in case)
			if card_node.get_parent() != self:
				card_node.reparent(self, false)
			
			# Reset transform
			if idx < initial_transforms.size():
				card_node.transform = initial_transforms[idx]
			
			_update_card_visuals(card_node, card)
			card_node.visible = true
			
			# Add collision
			_add_collision_to_card(card_node)
			
			# If this is the 3rd card, we can emit signals
			if cards_in_hand.size() == 3:
				emit_signal("envido_calculated", get_envido_points())
				emit_signal("flor_detected", has_flor())

func _on_card_placement_info(target_position: Vector3, stack_height: float) -> void:
	cached_target_position = target_position
	cached_stack_height = stack_height

func _emit_initial_signals() -> void:
	emit_signal("envido_calculated", get_envido_points())
	emit_signal("flor_detected", has_flor())

func _add_collision_to_card(card_node: MeshInstance3D) -> void:
	if card_node.has_node("StaticBody3D"):
		return

	# Create StaticBody3D
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "StaticBody3D"
	card_node.add_child(static_body)
	
	# Create CollisionShape3D
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	# Card mesh size is approx 0.06 x 0.1 based on PlaneMesh in scene
	box_shape.size = Vector3(0.06, 0.01, 0.1)
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	
	# Connect input event
	static_body.input_event.connect(_on_card_input_event.bind(card_node))
	# Connect hover signals
	static_body.mouse_entered.connect(_on_card_mouse_entered.bind(card_node))
	static_body.mouse_exited.connect(_on_card_mouse_exited.bind(card_node))

func _on_card_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, card_node: MeshInstance3D) -> void:
	if not can_interact:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Find the Card resource associated with this node
		var idx: int = -1
		if card_node == card_1: idx = 0
		elif card_node == card_2: idx = 1
		elif card_node == card_3: idx = 2
		
		if idx != -1 and idx < cards_in_hand.size():
			var card: Card = cards_in_hand[idx]
			# Emit via SignalBus
			TrucoSignalBus.emit_signal("on_user_input_card_selected", card)
			emit_signal("card_selected", card, card_node) # Keep local for compatibility if needed
			# We don't throw immediately, we wait for the controller to tell us (or we could do optimistic, but let's be strict for now)
			# play_card_throw_sound()
			# throw_card(card_node)

func enable_interaction() -> void:
	can_interact = true
	# Optional: Visual cue like highlighting cards

func disable_interaction() -> void:
	can_interact = false


func _on_card_mouse_entered(card_node: MeshInstance3D) -> void:
	# Only apply effect if card is still in hand
	if card_node.get_parent() != self: return
	
	var idx: int = -1
	if card_node == card_1: idx = 0
	elif card_node == card_2: idx = 1
	elif card_node == card_3: idx = 2
	
	if idx != -1:
		# Kill previous tween if exists
		if hover_tweens.has(card_node) and hover_tweens[card_node]:
			hover_tweens[card_node].kill()
			
		# Pop up slightly (local Y)
		var target_y: float = initial_transforms[idx].origin.y + 0.025
		var tween: Tween = create_tween()
		hover_tweens[card_node] = tween
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card_node, "position:y", target_y, 0.2)

func _on_card_mouse_exited(card_node: MeshInstance3D) -> void:
	# Only apply effect if card is still in hand
	if card_node.get_parent() != self: return
	
	var idx: int = -1
	if card_node == card_1: idx = 0
	elif card_node == card_2: idx = 1
	elif card_node == card_3: idx = 2
	
	if idx != -1:
		# Kill previous tween if exists
		if hover_tweens.has(card_node) and hover_tweens[card_node]:
			hover_tweens[card_node].kill()
			
		# Return to original position
		var target_y: float = initial_transforms[idx].origin.y
		var tween: Tween = create_tween()
		hover_tweens[card_node] = tween
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card_node, "position:y", target_y, 0.2)

func throw_card(card_node: MeshInstance3D) -> void:
	if not card_node.visible: return
	
	# Kill any active hover tween to prevent it from messing with position after reparenting
	if hover_tweens.has(card_node) and hover_tweens[card_node]:
		hover_tweens[card_node].kill()
	
	var static_body: Node = card_node.get_node_or_null("StaticBody3D")
	if static_body:
		static_body.queue_free() # Remove collision so it can't be clicked again
	
	# Reparent to scene root (Hand's parent) to avoid inheriting Hand transforms
	# Using get_parent() (TrucoRoom) is safer than current_scene in case of nested instantiation
	var new_parent: Node = get_parent()
	if new_parent:
		card_node.reparent(new_parent, true)
		
		# Force scale reset to avoid any skew/scale artifacts from reparenting
		card_node.scale = Vector3.ONE
	else:
		printerr("Hand has no parent!")
	
	# Use cached placement info from Table (via SignalBus)
	var target_pos: Vector3 = cached_target_position
	# Add some randomness to the target position ("messy" pile)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var random_offset: Vector3 = Vector3(rng.randf_range(-0.009, 0.009), 0, rng.randf_range(-0.009, 0.009))
	target_pos += random_offset
	
	# Apply stack height from cached info
	target_pos.y += cached_stack_height
	
	# Animation
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	# Move to target (global position)
	var flight_time: float = 0.7
	tween.tween_property(card_node, "global_position", target_pos, flight_time)
	
	# Random rotation only on Y axis (yaw) so it lands flat on the table
	var random_rot_y: float = rng.randf_range(0, 360)
	
	var final_rotation: Vector3 = Vector3(0, deg_to_rad(random_rot_y), 0)
	
	tween.tween_property(card_node, "global_rotation", final_rotation, flight_time * 0.8)

func play_card_throw_sound() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	card_sounds_player.stream = card_sounds[rng.randi_range(0, card_sounds.size() - 1)]
	card_sounds_player.play()

func deal_new_hand() -> void:
	cards_in_hand.clear()
	
	# Clean up any thrown cards still in the scene
	var card_nodes: Array[MeshInstance3D] = [card_1, card_2, card_3]
	for card_node in card_nodes:
		# If card was thrown (reparented), bring it back
		if card_node.get_parent() != self:
			card_node.reparent(self, false)
		
		# Hide until dealt
		card_node.visible = false

	# Signals will be emitted when cards are received in _on_card_dealt

func _update_card_visuals(card_node: MeshInstance3D, card: Card) -> void:
	# Check if we already have a unique override that is a ShaderMaterial
	var override_mat: Material = card_node.get_surface_override_material(0)
	
	if override_mat is ShaderMaterial:
		override_mat.set_shader_parameter("main_tex", card.image)
		return

	# If no override, check the active material (from mesh or material_override)
	var active_mat: Material = card_node.get_active_material(0)
	
	if active_mat is ShaderMaterial:
		# We found a shader material. Duplicate it to create a unique instance for this card
		# so we can set a unique texture without affecting others.
		var new_mat: Resource = active_mat.duplicate()
		new_mat.set_shader_parameter("main_tex", card.image)
		card_node.set_surface_override_material(0, new_mat)
	else:
		# Fallback: use the card's default material logic
		card_node.set_surface_override_material(0, card.material)
		card_node.get_surface_override_material(0).albedo_texture = card.image

## If there are at least two cards of the same suit, envido = 20 + sum of the two
## highest envido values in that suit (cards 10/11/12 count as 0).
## Otherwise return the highest single envido card value.
func get_envido_points() -> int:
	var suits_cards: Dictionary[Variant, Variant] = {}
	for card in cards_in_hand:
		if not suits_cards.has(card.suit):
			suits_cards[card.suit] = []
		suits_cards[card.suit].append(card)

	var best_pair_envido: int = 0
	for suit in suits_cards.keys():
		var cards_of_suit = suits_cards[suit]
		if cards_of_suit.size() < 2:
			continue

		var vals: Array[Variant] = []
		for c in cards_of_suit:
			vals.append(c.get_envido_value())
		vals.sort_custom(func(a, b): return a > b)
		var pair_sum = vals[0] + vals[1]
		var suit_envido = 20 + pair_sum
		if suit_envido > best_pair_envido:
			best_pair_envido = suit_envido

	if best_pair_envido > 0:
		return best_pair_envido

	# Fallback: highest single envido card value
	var best_single: int = 0
	for c in cards_in_hand:
		best_single = max(best_single, c.get_envido_value())
	return best_single

## If all three cards are of the same suit, return true.
## Otherwise return false.
func has_flor() -> bool:
	if cards_in_hand.size() < 3:
		return false
	var first_suit: Card.Suit = cards_in_hand[0].suit
	for i in range(1, cards_in_hand.size()):
		if cards_in_hand[i].suit != first_suit:
			return false
	return true
