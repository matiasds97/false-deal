class_name BaseHand
extends Node3D

## Base class for all hand visualizations (Human and CPU).
## Handles shared logic: card prefab instantiation, placement caching,
## card visual updates, throw animations, and sound effects.

@export var card_prefab: PackedScene = preload("res://scenes/prefabs/card.tscn")
@onready var card_sounds_player: AudioStreamPlayer3D = $CardSoundsPlayer

var card_sounds: Array[AudioStream] = [
	load("res://assets/audio/sounds/card-place-1.ogg"),
	load("res://assets/audio/sounds/card-place-2.ogg"),
	load("res://assets/audio/sounds/card-place-3.ogg")
]

var card_nodes: Array[CardVisual] = []
var initial_transforms: Array[Transform3D] = []

# Cached placement info from Table via SignalBus
var cached_target_position: Vector3 = Vector3.ZERO
var cached_stack_height: float = 0.0


## Instantiates CardVisual nodes from placeholder children ($Card1, $Card2, $Card3).
## Stores initial transforms and frees the original placeholders.
func _setup_card_placeholders() -> void:
	var placeholders = [$Card1, $Card2, $Card3]
	
	for i in range(placeholders.size()):
		var placeholder = placeholders[i]
		if placeholder:
			initial_transforms.append(placeholder.transform)
			placeholder.visible = false
			
			var visual = card_prefab.instantiate() as CardVisual
			add_child(visual)
			visual.transform = placeholder.transform
			visual.visible = false
			card_nodes.append(visual)
			
			placeholder.queue_free()


## Connects the shared signal for card placement info from the Table.
func _connect_base_signals() -> void:
	TrucoSignalBus.card_placement_info.connect(_on_card_placement_info)


## Override in subclass to return the player index this hand represents.
func _get_player_index() -> int:
	push_error("BaseHand._get_player_index() must be overridden!")
	return -1


func _on_card_placement_info(player_index: int, target_position: Vector3, stack_height: float) -> void:
	if player_index != _get_player_index():
		return
	cached_target_position = target_position
	cached_stack_height = stack_height


## Applies the correct texture or custom material to a CardVisual node.
func _update_card_visuals(card_node: CardVisual, card: Card) -> void:
	if card_node:
		if card.custom_material:
			card_node.set_front_material(card.custom_material)
		else:
			card_node.set_front_texture(card.image)


## Resets all card nodes back to their initial state (reparented, hidden or visible).
## [param make_visible]: If true, cards are shown after reset (CPU hand). If false, hidden (human hand).
func _reset_card_nodes(make_visible: bool = false) -> void:
	for i in range(card_nodes.size()):
		var card_node: CardVisual = card_nodes[i]
		
		# Reparent if it was thrown to the table
		if card_node.get_parent() != self:
			card_node.reparent(self, false)
		
		card_node.visible = make_visible
		if i < initial_transforms.size():
			card_node.transform = initial_transforms[i]


## Throws a card node toward the table using CardThrowHelper.
func _throw_card_to_table(card_node: CardVisual) -> void:
	if not card_node.visible: return
	
	CardThrowHelper.play_random_card_sound(card_sounds_player, card_sounds)
	CardThrowHelper.throw_card(
		card_node, get_parent(),
		cached_target_position, cached_stack_height, self
	)
