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

# --- TABLE LAYOUT (2×3 slot grid) ---
## X-positions for the 3 card columns: baza 1 (left), baza 2 (center), baza 3 (right)
const TABLE_SLOT_X := [-0.08, 0.0, 0.08]
## Z-offset for human player's row (closer to camera)
const HUMAN_ROW_Z: float = 0.05
## Z-offset for CPU player's row (farther from camera)
const CPU_ROW_Z: float = -0.05
## Small random scatter within each slot for natural feel
const SLOT_SCATTER: float = 0.005
## Small random rotation range (degrees) when a card is placed in a slot
const SLOT_ROTATION_RANGE: float = 10.0
## Y-height increment per stacked card on the same slot
const CARD_STACK_HEIGHT: float = 0.002

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
