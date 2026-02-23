extends BaseHand

## Human player's hand visualization.
## Handles card interaction (hover, click), collision setup, and envido display.
## Extends BaseHand for shared card management logic.

var cards_in_hand: Array[Card] = []
var hover_tweens: Dictionary = {}

# Reference to TrucoManager for accessing Player data
@onready var _truco_manager: TrucoManager = $"../TrucoManager"

signal envido_calculated(score: int)
signal card_selected(card: Card, card_node: MeshInstance3D)

var can_interact: bool = false


func _get_player_index() -> int:
	return TrucoConstants.PLAYER_HUMAN


func _ready() -> void:
	_setup_card_placeholders()
	
	# Emit signals deferredly to ensure UI is ready and connected
	call_deferred("_emit_initial_signals")
	
	# Connect to SignalBus
	_connect_base_signals()
	TrucoSignalBus.on_card_dealt.connect(_on_card_dealt)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)
	TrucoSignalBus.on_turn_started.connect(_on_turn_started)
	TrucoSignalBus.on_card_played.connect(_on_card_played)


func _on_turn_started(player_index: int) -> void:
	if player_index == TrucoConstants.PLAYER_HUMAN:
		enable_interaction()
	else:
		disable_interaction()

func _on_card_played(player_index: int, card: Card) -> void:
	if player_index == TrucoConstants.PLAYER_HUMAN:
		disable_interaction()
		
		# Find the card node corresponding to this card
		var card_idx: int = -1
		for i in range(cards_in_hand.size()):
			if cards_in_hand[i] == card:
				card_idx = i
				break
		
		if card_idx != -1:
			if card_idx < card_nodes.size():
				var node = card_nodes[card_idx]
				_remove_card_collision(node)
				_throw_card_to_table(node, card)
		else:
			printerr("Hand: Played card not found in hand!")

func _on_hand_started(_hand_number: int) -> void:
	deal_new_hand()

func _on_card_dealt(player_index: int, card: Card) -> void:
	if player_index == TrucoConstants.PLAYER_HUMAN:
		cards_in_hand.append(card)
		var idx: int = cards_in_hand.size() - 1
		
		if idx < card_nodes.size():
			var card_node = card_nodes[idx]
			
			# Ensure it's back in hand (just in case)
			if card_node.get_parent() != self:
				card_node.reparent(self, false)
			
			if idx < initial_transforms.size():
				card_node.visible = true
				if _truco_manager and _truco_manager.visual_deck:
					card_node.global_transform = _truco_manager.visual_deck.global_transform
				
				var tween = create_tween()
				tween.set_ease(Tween.EASE_OUT)
				tween.set_trans(Tween.TRANS_CUBIC)
				tween.tween_property(card_node, "transform", initial_transforms[idx], 0.2)
				
				# Play deal sound using existing helper
				CardThrowHelper.play_random_card_sound(card_sounds_player, card_sounds)
			
			_update_card_visuals(card_node, card)
			
			# Add collision
			_add_collision_to_card(card_node)
			
			# If this is the 3rd card, we can emit signals
			if cards_in_hand.size() == 3:
				envido_calculated.emit(get_envido_points())


func _emit_initial_signals() -> void:
	envido_calculated.emit(get_envido_points())


# --- COLLISION ---

func _add_collision_to_card(card_node: CardVisual) -> void:
	if card_node.has_node("StaticBody3D"):
		return

	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "StaticBody3D"
	card_node.add_child(static_body)
	
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(0.06, 0.01, 0.1)
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	
	static_body.input_event.connect(_on_card_input_event.bind(card_node))
	static_body.mouse_entered.connect(_on_card_mouse_entered.bind(card_node))
	static_body.mouse_exited.connect(_on_card_mouse_exited.bind(card_node))


func _remove_card_collision(card_node: CardVisual) -> void:
	# Kill any active hover tween
	if hover_tweens.has(card_node) and hover_tweens[card_node]:
		hover_tweens[card_node].kill()
	
	var static_body: Node = card_node.get_node_or_null("StaticBody3D")
	if static_body:
		static_body.queue_free()


# --- INPUT ---

func _on_card_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, card_node: CardVisual) -> void:
	if not can_interact:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var idx: int = card_nodes.find(card_node)
		
		if idx != -1 and idx < cards_in_hand.size():
			var card: Card = cards_in_hand[idx]
			TrucoSignalBus.on_user_input_card_selected.emit(card)
			card_selected.emit(card, card_node)


func enable_interaction() -> void:
	can_interact = true


func disable_interaction() -> void:
	can_interact = false


# --- HOVER EFFECTS ---

func _on_card_mouse_entered(card_node: CardVisual) -> void:
	if card_node.get_parent() != self: return
	
	var idx: int = card_nodes.find(card_node)
	
	if idx != -1:
		if hover_tweens.has(card_node) and hover_tweens[card_node]:
			hover_tweens[card_node].kill()
			
		var target_y: float = initial_transforms[idx].origin.y + 0.025
		var tween: Tween = create_tween()
		hover_tweens[card_node] = tween
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card_node, "position:y", target_y, 0.2)

func _on_card_mouse_exited(card_node: CardVisual) -> void:
	if card_node.get_parent() != self: return
	
	var idx: int = card_nodes.find(card_node)
	
	if idx != -1:
		if hover_tweens.has(card_node) and hover_tweens[card_node]:
			hover_tweens[card_node].kill()
			
		var target_y: float = initial_transforms[idx].origin.y
		var tween: Tween = create_tween()
		hover_tweens[card_node] = tween
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(card_node, "position:y", target_y, 0.2)


# --- HAND MANAGEMENT ---

func deal_new_hand() -> void:
	cards_in_hand.clear()
	_reset_card_nodes(false)


## Returns envido points by delegating to the Player entity.
func get_envido_points() -> int:
	if _truco_manager and _truco_manager.players.size() > TrucoConstants.PLAYER_HUMAN:
		return _truco_manager.players[TrucoConstants.PLAYER_HUMAN].get_envido_points()
	push_warning("Hand: TrucoManager not available for envido calculation")
	return 0

## Returns true if player has flor by delegating to the Player entity.
func has_flor() -> bool:
	if _truco_manager and _truco_manager.players.size() > TrucoConstants.PLAYER_HUMAN:
		return _truco_manager.players[TrucoConstants.PLAYER_HUMAN].has_flor()
	push_warning("Hand: TrucoManager not available for flor check")
	return false
