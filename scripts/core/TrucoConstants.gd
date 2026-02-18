class_name TrucoConstants
extends RefCounted

## Centralized constants for the Truco game.
## Use these instead of magic numbers throughout the codebase.

# --- PLAYER INDICES ---
## Index for the human player
const PLAYER_HUMAN: int = 0
## Index for the CPU player
const PLAYER_CPU: int = 1

# --- GAME CONFIGURATION ---
## Maximum score to win the match
const MAX_SCORE: int = 30
## Score threshold for "buenas" (affects Falta Envido calculation)
const THRESHOLD_BUENAS: int = 16

# --- TIMING ---
## Duration of the card throw animation in seconds
const CARD_THROW_DURATION: float = 0.5
## Default delay before CPU makes a decision
const CPU_DECISION_DELAY: float = 0.4
## Delay before starting a new hand after round ends
const NEW_HAND_DELAY: float = 2.0

# --- ENVIDO TYPES ---
enum EnvidoType {
	ENVIDO,
	REAL_ENVIDO,
	FALTA_ENVIDO
}

# --- FLOR TYPES ---
enum FlorType {
	FLOR,
	CONTRA_FLOR,
	CONTRA_FLOR_AL_RESTO
}

# --- RESPONSE ACTIONS ---
enum ResponseAction {
	NONE,
	ENVIDO,
	TRUCO,
	FLOR
}
