class_name InteractionRayCast
extends RayCast3D

## RayCast que detecta objetos interactuables y gestiona el prompt visual.
## Se agrega como hijo de la Camera3D del jugador.

# ─── Señales ──────────────────────────────────────────────────────────────────

## Emitida cuando el objetivo interactuable cambia (puede ser null).
signal target_changed(interactable: Interactable)

# ─── Exports ─────────────────────────────────────────────────────────────────

## Distancia máxima de interacción en metros.
@export var interaction_distance: float = 3.0

# ─── Variables Privadas ──────────────────────────────────────────────────────

var _current_target: Interactable = null
var _prompt_label: Label = null


# ─── Funciones Built-in ──────────────────────────────────────────────────────

func _ready() -> void:
	target_position = Vector3(0, 0, -interaction_distance)
	collide_with_areas = true
	collide_with_bodies = true
	enabled = true
	_setup_prompt_label()


func _physics_process(_delta: float) -> void:
	var new_target: Interactable = _detect_interactable()

	if new_target != _current_target:
		_current_target = new_target
		target_changed.emit(_current_target)
		_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current_target:
		if _current_target.can_interact():
			_current_target.interact()
			get_viewport().set_input_as_handled()


# ─── Funciones Privadas ─────────────────────────────────────────────────────

## Detecta si el raycast está apuntando a un Interactable.
func _detect_interactable() -> Interactable:
	if not is_colliding():
		return null

	var collider: Object = get_collider()
	if not collider:
		return null

	# El collider mismo podría ser un Interactable
	if collider is Interactable:
		return collider as Interactable

	# Buscar un Interactable en el collider, sus hermanos, o ancestros cercanos
	if collider is Node:
		var node: Node = collider as Node
		# Buscar entre los hijos del collider
		var result: Interactable = _find_interactable_in_children(node)
		if result:
			return result
		# Buscar entre los hermanos (hijos del padre)
		if node.get_parent():
			result = _find_interactable_in_children(node.get_parent())
			if result:
				return result

	return null


## Busca un Interactable entre los hijos directos de un nodo.
func _find_interactable_in_children(node: Node) -> Interactable:
	for child: Node in node.get_children():
		if child is Interactable:
			return child as Interactable
	return null


## Crea el label de prompt en un CanvasLayer propio.
func _setup_prompt_label() -> void:
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Anclar al centro-abajo del viewport
	_prompt_label.anchor_left = 0.3
	_prompt_label.anchor_right = 0.7
	_prompt_label.anchor_top = 0.85
	_prompt_label.anchor_bottom = 0.9
	_prompt_label.offset_left = 0
	_prompt_label.offset_right = 0
	_prompt_label.offset_top = 0
	_prompt_label.offset_bottom = 0
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	_prompt_label.visible = false
	canvas_layer.add_child(_prompt_label)


## Actualiza la visibilidad y texto del prompt.
func _update_prompt() -> void:
	if not _prompt_label:
		return

	if _current_target and _current_target.can_interact():
		_prompt_label.text = "[E] " + _current_target.interaction_name
		_prompt_label.visible = true
	else:
		_prompt_label.visible = false
