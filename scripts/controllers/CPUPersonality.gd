class_name CPUPersonality
extends Resource

## Defines the CPU's play style — WHO they are as a player.
## This is the static "DNA" of a story mode character.
##
## Independent from skill: a high-bluff personality can be
## executed poorly (low skill) or masterfully (high skill).

## How the CPU selects which card to play from its hand.
enum CardPlayStyle {
	CONSERVATIVE, ## Saves strong cards for later vueltas
	BALANCED, ## Mix of strategies depending on context
	AGGRESSIVE ## Leads with strongest cards
}

## Display name for UI / story mode.
@export var display_name: String = "CPU"

## How aggressive when calling/raising bets.
## 0.0 = passive, rarely calls. 1.0 = hyper-aggressive, always calls.
@export_range(0.0, 1.0) var aggression: float = 0.5

## How often they bluff (call/raise with a weak hand).
## 0.0 = only calls with strong hands. 1.0 = bluffs constantly.
@export_range(0.0, 1.0) var bluff_tendency: float = 0.2

## Threshold for envido decisions (maps to point requirements).
## 0.0 = calls envido with anything. 1.0 = only with 33.
@export_range(0.0, 1.0) var envido_threshold: float = 0.5

## Base probability of calling truco proactively.
## 0.0 = never starts truco. 1.0 = calls truco every turn.
@export_range(0.0, 1.0) var truco_call_rate: float = 0.15

## How reluctant to fold (irse al mazo).
## 0.0 = folds easily. 1.0 = never gives up.
@export_range(0.0, 1.0) var fold_resistance: float = 0.5

## Card selection strategy.
@export var card_play_style: CardPlayStyle = CardPlayStyle.BALANCED

## Tendency to raise instead of accepting a bet.
## 0.0 = always accepts. 1.0 = always tries to raise.
@export_range(0.0, 1.0) var raise_tendency: float = 0.4

## Risk tolerance under pressure.
## Different from aggression — can be aggressive but cautious when ahead.
## 0.0 = avoids risk when stakes are high. 1.0 = embraces high stakes.
@export_range(0.0, 1.0) var risk_tolerance: float = 0.5

## How much the CPU waits for information before acting.
## 0.0 = acts immediately (calls truco on first card).
## 1.0 = waits to see opponent's play before deciding.
@export_range(0.0, 1.0) var info_seeking: float = 0.3

## Taunting/talking tendency (for future dialogue system).
## 0.0 = silent. 1.0 = talks constantly.
@export_range(0.0, 1.0) var taunting: float = 0.2


## Creates a default balanced personality.
static func create_default() -> CPUPersonality:
	var p := CPUPersonality.new()
	p.display_name = "CPU"
	# All defaults are already balanced.
	return p
