class_name CPUMood
extends RefCounted

## Tracks the CPU's dynamic emotional state during a match.
## Modifiers are applied on top of CPUPersonality params through CPUBrain.
##
## The mood shifts based on in-game events: losing streaks, bluff discoveries,
## big score swings, etc. This makes the same personality feel different
## depending on how the match is going.

## Frustration from losses, discovered bluffs. Increases aggression, decreases control.
## Range: 0.0 (calm) to 1.0 (fully tilted).
var tilt_level: float = 0.0

## Self-assurance from winning streaks and good hands.
## Range: 0.0 (insecure) to 1.0 (overconfident).
var confidence: float = 0.5

## Pressure from score difference and proximity to max score.
## Range: -1.0 (comfortable lead) to 1.0 (desperate, far behind).
var score_pressure: float = 0.0

## Desire for payback after losing a big bet. Decays over time.
## Range: 0.0 (neutral) to 1.0 (wants revenge badly).
var revenge_factor: float = 0.0

## Internal tracking
var _consecutive_wins: int = 0
var _consecutive_losses: int = 0
var _personality: CPUPersonality


func _init(personality: CPUPersonality) -> void:
	_personality = personality
	reset()


## Resets mood to neutral starting state.
func reset() -> void:
	tilt_level = 0.0
	confidence = 0.5
	score_pressure = 0.0
	revenge_factor = 0.0
	_consecutive_wins = 0
	_consecutive_losses = 0


## Called when the CPU wins a round.
func on_round_won() -> void:
	_consecutive_wins += 1
	_consecutive_losses = 0

	confidence = clampf(confidence + 0.1, 0.0, 1.0)
	tilt_level = clampf(tilt_level - 0.15, 0.0, 1.0)
	revenge_factor = clampf(revenge_factor - 0.1, 0.0, 1.0)


## Called when the CPU loses a round.
func on_round_lost() -> void:
	_consecutive_losses += 1
	_consecutive_wins = 0

	tilt_level = clampf(tilt_level + 0.1 + _consecutive_losses * 0.05, 0.0, 1.0)
	confidence = clampf(confidence - 0.1, 0.0, 1.0)


## Called when the CPU loses a big bet (envido, truco with high stakes).
func on_big_bet_lost(points_lost: int) -> void:
	var impact: float = clampf(points_lost / 10.0, 0.0, 0.5)
	tilt_level = clampf(tilt_level + impact, 0.0, 1.0)
	revenge_factor = clampf(revenge_factor + impact * 1.5, 0.0, 1.0)
	confidence = clampf(confidence - impact * 0.5, 0.0, 1.0)


## Called when the CPU's bluff gets called/discovered.
func on_bluff_discovered() -> void:
	tilt_level = clampf(tilt_level + 0.15, 0.0, 1.0)
	confidence = clampf(confidence - 0.2, 0.0, 1.0)


## Called when the CPU successfully bluffs the opponent.
func on_bluff_succeeded() -> void:
	confidence = clampf(confidence + 0.15, 0.0, 1.0)
	tilt_level = clampf(tilt_level - 0.05, 0.0, 1.0)


## Updates score_pressure based on current scores.
func update_score_pressure(my_score: int, opponent_score: int) -> void:
	var diff: float = float(opponent_score - my_score) / TrucoConstants.MAX_SCORE
	score_pressure = clampf(diff, -1.0, 1.0)


## Natural decay — call at the start of each new hand.
## Mood gradually drifts back toward neutral over time.
func decay() -> void:
	tilt_level = clampf(tilt_level * 0.85, 0.0, 1.0)
	revenge_factor = clampf(revenge_factor * 0.8, 0.0, 1.0)
	# Confidence drifts toward 0.5 (personality baseline)
	confidence = lerpf(confidence, 0.5, 0.1)
