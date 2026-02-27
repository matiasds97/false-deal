extends CanvasLayer

## Inspector de objetos 3D estilo Silent Hill PS1.
## Muestra un modelo 3D rotando sobre su eje con fondo oscurecido.
## Se debe agregar al grupo "object_inspector" en el editor o por código.

# ─── Exports ─────────────────────────────────────────────────────────────────

## Velocidad de rotación del objeto (grados por segundo).
@export var rotation_speed: float = 45.0

# ─── Variables Privadas ──────────────────────────────────────────────────────

var _is_showing: bool = false
var _current_instance: Node3D = null

@onready var _background: ColorRect = $Background
@onready var _viewport_container: SubViewportContainer = $SubViewportContainer
@onready var _viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var _pivot: Node3D = $SubViewportContainer/SubViewport/ObjectPivot
@onready var _camera: Camera3D = $SubViewportContainer/SubViewport/InspectCamera
@onready var _light: DirectionalLight3D = $SubViewportContainer/SubViewport/DirectionalLight3D


# ─── Funciones Built-in ──────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("object_inspector")
	layer = 15
	_background.visible = false
	_viewport_container.visible = false


func _process(delta: float) -> void:
	if not _is_showing or not _current_instance:
		return
	_pivot.rotate_y(deg_to_rad(rotation_speed * delta))


# ─── Funciones Públicas ─────────────────────────────────────────────────────

## Muestra un objeto 3D rotando.
## @param scene: PackedScene del objeto a inspeccionar.
func show_object(scene: PackedScene) -> void:
	hide_object()

	_current_instance = scene.instantiate() as Node3D
	if not _current_instance:
		return

	_pivot.add_child(_current_instance)
	_center_object()

	_background.visible = true
	_viewport_container.visible = true
	_is_showing = true


## Oculta el inspector y libera el objeto.
func hide_object() -> void:
	if _current_instance:
		_current_instance.queue_free()
		_current_instance = null

	_background.visible = false
	_viewport_container.visible = false
	_is_showing = false


## Retorna si el inspector está mostrando un objeto.
func is_showing() -> bool:
	return _is_showing


# ─── Funciones Privadas ─────────────────────────────────────────────────────

## Centra el objeto en el viewport calculando su AABB.
func _center_object() -> void:
	if not _current_instance:
		return

	# Buscar un MeshInstance3D para obtener el AABB
	var aabb: AABB = AABB()
	var found_mesh: bool = false

	for child: Node in _current_instance.get_children():
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			if not found_mesh:
				aabb = mesh_instance.get_aabb()
				found_mesh = true
			else:
				aabb = aabb.merge(mesh_instance.get_aabb())

	if _current_instance is MeshInstance3D:
		aabb = (_current_instance as MeshInstance3D).get_aabb()
		found_mesh = true

	if found_mesh:
		# Centrar el objeto
		var center: Vector3 = aabb.get_center()
		_current_instance.position = - center

		# Ajustar la cámara según el tamaño
		var size: float = aabb.size.length()
		_camera.position.z = size * 1.5
