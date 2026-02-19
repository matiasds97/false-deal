class_name CPUBrain
extends RefCounted

## Unifies CPUSkill + CPUPersonality + CPUMood into effective parameters.
## This is the ONLY class that strategies interact with.
##
## The Brain combines:
## - Personality (static style) → base values
## - Mood (dynamic state)      → modifiers applied on top
## - Skill (competence)        → noise/accuracy applied to final decisions
##
## All effective params are clamped to [0.0, 1.0].


## Typed container for all effective parameters.
## Strategies receive this instead of a Dictionary, providing autocomplete and type safety.
class EffectiveParams:
	# --- Personality-derived (mood-modified) ---
	var aggression: float
	var bluff_tendency: float
	var envido_threshold: float
	var truco_call_rate: float
	var fold_resistance: float
	var raise_tendency: float
	var risk_tolerance: float
	var info_seeking: float
	var taunting: float
	var card_play_style: CPUPersonality.CardPlayStyle

	# --- Skill-derived (tilt can affect noise/control) ---
	var hand_evaluation_accuracy: float
	var opponent_read_accuracy: float
	var memory_depth: int
	var decision_noise: float
	var reaction_control: float


var skill: CPUSkill
var personality: CPUPersonality
var mood: CPUMood


func _init(p_skill: CPUSkill, p_personality: CPUPersonality, p_mood: CPUMood) -> void:
	skill = p_skill
	personality = p_personality
	mood = p_mood


## Returns a typed EffectiveParams object with all parameters modified by mood and skill.
## Strategies should call this once per decision and use the returned object.
func get_effective_params() -> EffectiveParams:
	var tilt: float = mood.tilt_level
	var conf: float = mood.confidence
	var pressure: float = mood.score_pressure

	var p := EffectiveParams.new()

	# --- Personality params, modified by mood ---
	p.aggression = _clamp01(personality.aggression + tilt * 0.3 + pressure * 0.15)
	p.bluff_tendency = _clamp01(personality.bluff_tendency + tilt * 0.1 - conf * 0.05)
	p.envido_threshold = _clamp01(personality.envido_threshold - tilt * 0.1)
	p.truco_call_rate = _clamp01(personality.truco_call_rate + tilt * 0.15 + mood.revenge_factor * 0.1)
	p.fold_resistance = _clamp01(personality.fold_resistance + conf * 0.1 - pressure * 0.1)
	p.raise_tendency = _clamp01(personality.raise_tendency + tilt * 0.1 + mood.revenge_factor * 0.15)
	p.risk_tolerance = _clamp01(personality.risk_tolerance - pressure * 0.2 + conf * 0.1)
	p.info_seeking = _clamp01(personality.info_seeking - tilt * 0.15)
	p.taunting = _clamp01(personality.taunting + tilt * 0.2 + conf * 0.1)
	p.card_play_style = personality.card_play_style

	# --- Skill params (tilt degrades noise and control) ---
	p.hand_evaluation_accuracy = skill.hand_evaluation_accuracy
	p.opponent_read_accuracy = skill.opponent_read_accuracy
	p.memory_depth = skill.memory_depth
	p.decision_noise = _clamp01(skill.decision_noise + tilt * 0.1)
	p.reaction_control = _clamp01(skill.reaction_control - tilt * 0.15)

	return p


## Applies decision noise: may flip a boolean decision randomly.
## Use this to simulate mistakes / imperfect play.
## [param intended]: The decision the CPU "wants" to make.
## Returns the final decision (may be flipped by noise).
func apply_noise(intended: bool) -> bool:
	var noise: float = _clamp01(skill.decision_noise + mood.tilt_level * 0.1)
	if randf() < noise * 0.3:
		return not intended
	return intended


## Returns a noised float value — adds random perturbation to a numeric param.
## Useful for hand evaluation: the CPU may mis-evaluate its hand strength.
## [param value]: The true value.
## [param accuracy]: How accurate the CPU is (from skill). 1.0 = perfect.
func apply_evaluation_noise(value: float, accuracy: float) -> float:
	var error_range: float = (1.0 - accuracy) * 0.4
	var noise: float = randf_range(-error_range, error_range)
	return clampf(value + noise, 0.0, 1.0)


## Convenience: applies evaluation noise to an integer value (e.g., envido points).
## [param points]: The actual points.
## [param accuracy]: How accurately the CPU evaluates these points.
## Returns the perceived points (may be higher or lower than actual).
func perceive_points(points: int, accuracy: float) -> int:
	var error_range: float = (1.0 - accuracy) * 6.0 # Max ±6 points error at 0 accuracy
	var noise_val: float = randf_range(-error_range, error_range)
	return clampi(roundi(float(points) + noise_val), 0, 33)


static func _clamp01(value: float) -> float:
	return clampf(value, 0.0, 1.0)
