class_name CardVisual
extends Node3D

## Visual wrapper for the 3D Card Prefab.
## Handles setting textures on the specific materials of the distinct surfaces.
## Assumes the mesh has 3 surfaces: 0=Front, 1=Back, 2=Border.

@export var mesh_path: NodePath = "Card"
@onready var mesh: MeshInstance3D = get_node(mesh_path)

const DEFAULT_BACK_TEXTURE = preload("res://assets/textures/cards_back/card_reverse.jpg")

func _ready() -> void:
	if mesh:
		mesh.scale = Vector3(0.5, 0.5, 0.5)
	# Set default back texture
	set_back_texture(DEFAULT_BACK_TEXTURE)

func set_front_texture(texture: Texture2D) -> void:
	_set_surface_texture(0, texture)

func set_back_texture(texture: Texture2D) -> void:
	_set_surface_texture(1, texture)

func set_front_material(material: Material) -> void:
	if not mesh: return
	mesh.set_surface_override_material(0, material)

func _set_surface_texture(surface_idx: int, texture: Texture2D) -> void:
	if not mesh: return
	
	# Get the Override Material (it should be a StandardMaterial3D based on the prefab)
	var mat: Material = mesh.get_surface_override_material(surface_idx)
	
	if mat is StandardMaterial3D:
		# We need to duplicate it to ensure we don't change all cards sharing this material
		# However, if we already made it unique for this instance, we are good.
		# Ideally, the spawner should handle uniqueness, or we do it lazily here.
		# Check if the material is shared (resource_local_to_scene might not be on)
		# For safety in this specific use case where every card is different:
		# We check if we have already duplicated it? 
		# Actually, simply setting it is fine IF the prefab instantiation created a copy?
		# No, resources are shared by default.
		# Let's simple duplicate it if it's the first time we touch it, 
		# but `duplicate()` on a material returns a new resource.
		# We just set it back.
		# Optimization: Store if we have unique-fied it? 
		# Or just always set albedo. If we change albedo on a shared material, ALL cards change.
		# So we MUST ensure it's unique.
		# But wait! The prefab has sub_resources for materials. 
		# When we instantiate the scene, do those sub_resources get duplicated?
		# Yes, for sub_resources in the scene file, they are usually unique per instance IF "Local to Scene" is checked?
		# In the tscn provided: `[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_ach1a"]`
		# These are subresources of the SCENE. Instantiating the scene usually Clones these resources?
		# Actually in Godot 4, sub-resources in a tscn are shared across instances unless "Local to Scene" is ON.
		# The tscn text didn't show "resource_local_to_scene = true".
		# So they are SHARED. We MUST duplicate.
		if mat.resource_name != "UniqueCardMat": # Hacky check or just duplicate
			var new_mat = mat.duplicate()
			new_mat.resource_name = "UniqueCardMat"
			new_mat.albedo_texture = texture
			mesh.set_surface_override_material(surface_idx, new_mat)
		else:
			mat.albedo_texture = texture

	elif mat is ShaderMaterial:
		# If user switches to Shader later
		mat.set_shader_parameter("albedo_texture", texture)
