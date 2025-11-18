extends OmniLight3D

# Simple intermittent light for an OmniLight3D node.
# Behavior: energy toggles between `min_energy` and `max_energy` at `frequency` Hz.
# Use `duty` to control how long the light stays at max per period (0..1).
# If `smooth` is true the transition uses a short lerp controlled by `rise_time`.

@export_range(0.0, 60.0, 0.1) var frequency: float = 4.0
@export_range(0.0, 1.0, 0.01) var duty: float = 0.15 # fraction of period at high energy
@export_range(0.0, 10.0, 0.01) var min_energy: float = 0.0
@export_range(0.0, 10.0, 0.01) var max_energy: float = 1.0
@export var smooth: bool = true
@export_range(0.001, 0.5, 0.001) var rise_time: float = 0.02 # seconds to ease toward target

var _time: float = 0.0
var _current_energy: float = 0.0
var _target_energy: float = 0.0
var _transition_t: float = 0.0

func _ready() -> void:
	# Initialize current energy from the node's property if present
	if _has_prop("energy"):
		_current_energy = get("energy")
	elif _has_prop("light_energy"):
		_current_energy = get("light_energy")
	else:
		_current_energy = min_energy
	_target_energy = _current_energy
	_apply_energy(_current_energy)

func _process(delta: float) -> void:
	if frequency <= 0.0:
		return

	_time += delta
	var phase = (_time * frequency) - floor(_time * frequency) # 0..1
	var high = phase < clamp(duty, 0.0, 1.0)
	var desired = max_energy if high else min_energy

	if desired != _target_energy:
		_target_energy = desired
		_transition_t = 0.0

	if smooth and abs(_current_energy - _target_energy) > 0.0001:
		_transition_t += delta / max(rise_time, 0.00001)
		var t = clamp(_transition_t, 0.0, 1.0)
		_current_energy = lerp(_current_energy, _target_energy, t)
	else:
		_current_energy = _target_energy

	_apply_energy(_current_energy)

func _apply_energy(v: float) -> void:
	# Try common light properties (Godot 4 property names may differ by node)
	if _has_prop("energy"):
		set("energy", v)
	elif _has_prop("light_energy"):
		set("light_energy", v)
	else:
		# Best-effort fallback using `set` so script doesn't error
		set("energy", v)

func _has_prop(prop_name: String) -> bool:
	for p in get_property_list():
		if p.has("name") and p["name"] == prop_name:
			return true
	return false

func set_frequency(hz: float) -> void:
	frequency = max(0.0, hz)
