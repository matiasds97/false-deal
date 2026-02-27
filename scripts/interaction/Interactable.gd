class_name Interactable
extends Area3D

## Componente que convierte cualquier nodo en un objeto interactuable.
## Se agrega como hijo de un objeto en la escena.
## Emite señales que el nodo padre puede conectar para ejecutar lógica custom.

# ─── Señales ──────────────────────────────────────────────────────────────────

## Emitida cuando el jugador interactúa con este objeto.
signal interacted()

## Emitida al finalizar el diálogo completo.
signal dialogue_ended()

## Emitida cuando el jugador elige una opción con action_id.
## @param action_id: Identificador de la acción a ejecutar.
signal action_requested(action_id: String)

# ─── Exports ─────────────────────────────────────────────────────────────────

## Nombre de la interacción mostrado en el prompt (por ejemplo "Examinar", "Hablar").
@export var interaction_name: String = "Examinar"

## Recurso con la secuencia de diálogo.
@export var dialogue_data: DialogueData

## Escena 3D que se muestra rotando al inspeccionar (estilo Silent Hill PS1).
@export var inspect_scene: PackedScene

## Si es true, solo se puede interactuar una vez.
@export var one_shot: bool = false

# ─── Variables Privadas ──────────────────────────────────────────────────────

var _has_been_used: bool = false
var _dialogue_ui: Node = null
var _object_inspector: Node = null


# ─── Funciones Públicas ─────────────────────────────────────────────────────

## Retorna si este interactable puede ser usado actualmente.
func can_interact() -> bool:
	if one_shot and _has_been_used:
		return false
	return true


## Ejecuta la interacción. Llamado por InteractionRayCast.
func interact() -> void:
	if not can_interact():
		return

	_has_been_used = true
	interacted.emit()

	# Buscar componentes de UI en el árbol
	_dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	_object_inspector = get_tree().get_first_node_in_group("object_inspector")

	# Mostrar inspector de objeto 3D si hay escena configurada
	if inspect_scene and _object_inspector:
		_object_inspector.show_object(inspect_scene)

	# Iniciar diálogo si hay datos configurados
	if dialogue_data and _dialogue_ui:
		if not _dialogue_ui.choice_selected.is_connected(_on_choice_selected):
			_dialogue_ui.choice_selected.connect(_on_choice_selected)
		if not _dialogue_ui.dialogue_finished.is_connected(_on_dialogue_finished):
			_dialogue_ui.dialogue_finished.connect(_on_dialogue_finished)
		_dialogue_ui.start_dialogue(dialogue_data)


# ─── Funciones Privadas ─────────────────────────────────────────────────────

func _on_dialogue_finished() -> void:
	if _dialogue_ui:
		if _dialogue_ui.choice_selected.is_connected(_on_choice_selected):
			_dialogue_ui.choice_selected.disconnect(_on_choice_selected)
		if _dialogue_ui.dialogue_finished.is_connected(_on_dialogue_finished):
			_dialogue_ui.dialogue_finished.disconnect(_on_dialogue_finished)

	# Cerrar inspector de objeto si estaba abierto
	if _object_inspector and _object_inspector.is_showing():
		_object_inspector.hide_object()

	dialogue_ended.emit()


func _on_choice_selected(action_id: String) -> void:
	if action_id != "":
		action_requested.emit(action_id)
