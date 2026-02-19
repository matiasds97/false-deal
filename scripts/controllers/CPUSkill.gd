class_name CPUSkill
extends Resource

## Defines the CPU's competence level — how WELL it plays, regardless of style.
## This controls the "difficulty" of the opponent.
##
## Low skill = makes mistakes, misreads situations, forgets patterns.
## High skill = plays optimally within its personality constraints.

## How accurately the CPU evaluates its own hand strength.
## Low = may overestimate or underestimate its cards.
## High = knows exactly how strong its hand is.
@export_range(0.0, 1.0) var hand_evaluation_accuracy: float = 0.7

## How well the CPU reads the opponent's intentions from their actions.
## Low = ignores opponent signals (fast calls, hesitation, etc).
## High = adjusts play based on opponent behavior.
@export_range(0.0, 1.0) var opponent_read_accuracy: float = 0.5

## How many previous rounds the CPU remembers to adjust its strategy.
## 0 = no memory (each round is independent).
## Higher = tracks patterns like "opponent always bluffs envido".
@export_range(0, 10) var memory_depth: int = 3

## Probability of making random errors in decisions.
## 0.0 = plays perfectly within its personality.
## 1.0 = chaotic, constantly makes wrong calls.
## This is the PRIMARY difficulty control.
@export_range(0.0, 1.0) var decision_noise: float = 0.1

## How well the CPU controls its own tells/reactions.
## Low = its response timing and behavior reveal hand strength.
## High = poker face, consistent timing regardless of hand.
@export_range(0.0, 1.0) var reaction_control: float = 0.5


## Creates a default balanced skill profile (medium difficulty).
static func create_default() -> CPUSkill:
	var s := CPUSkill.new()
	s.hand_evaluation_accuracy = 0.7
	s.opponent_read_accuracy = 0.5
	s.memory_depth = 3
	s.decision_noise = 0.1
	s.reaction_control = 0.5
	return s


## Creates a low-skill profile (easy opponent).
static func create_easy() -> CPUSkill:
	var s := CPUSkill.new()
	s.hand_evaluation_accuracy = 0.4
	s.opponent_read_accuracy = 0.2
	s.memory_depth = 1
	s.decision_noise = 0.35
	s.reaction_control = 0.2
	return s


## Creates a high-skill profile (hard opponent).
static func create_hard() -> CPUSkill:
	var s := CPUSkill.new()
	s.hand_evaluation_accuracy = 0.95
	s.opponent_read_accuracy = 0.85
	s.memory_depth = 8
	s.decision_noise = 0.03
	s.reaction_control = 0.9
	return s
