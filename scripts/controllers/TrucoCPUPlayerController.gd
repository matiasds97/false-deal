class_name TrucoCPUPlayerController
extends TrucoPlayerController
## Controls the AI opponent's actions by delegating decisions to strategy classes.
## Handles turn scheduling, response coordination, and strategy orchestration.
##
## Assign a CPUPersonality and CPUSkill resource in the editor (or via code)
## to define this opponent's play style and difficulty.
## If not assigned, balanced defaults are used.

@onready var truco_manager: TrucoManager = $"../TrucoManager"
@onready var calling_audio_player: AudioStreamPlayer3D = $CallingAudioPlayer

## Personality resource — defines play style (exported, assignable in editor).
@export var personality: CPUPersonality

## Skill resource — defines difficulty/competence (exported, assignable in editor).
@export var skill: CPUSkill

## Whether we are waiting for a response from the opponent.
var _waiting_for_response: bool = false
var _match_over: bool = false

## Token used to prevent race conditions by invalidating old scheduled
## decisions if a new one is made.
var _decision_token: int = 0

# --- BRAIN + MOOD ---
var _brain: CPUBrain
var _mood: CPUMood

# --- AUDIO ---
var _voice_lines: Dictionary = {
	"envido": preload("res://assets/audio/sounds/calls/envido.mp3"),
	"real_envido": preload("res://assets/audio/sounds/calls/real_envido.mp3"),
	"falta_envido": preload("res://assets/audio/sounds/calls/falta_envido.mp3"),
	"truco": preload("res://assets/audio/sounds/calls/truco.mp3"),
	"retruco": preload("res://assets/audio/sounds/calls/retruco.mp3"),
	"vale_4": preload("res://assets/audio/sounds/calls/vale_4.mp3"),
	"quiero": preload("res://assets/audio/sounds/calls/quiero.mp3"),
	"no_quiero": preload("res://assets/audio/sounds/calls/no_quiero.mp3"),
	"flor": preload("res://assets/audio/sounds/calls/flor.mp3"),
	"contra_flor": preload("res://assets/audio/sounds/calls/contraflor.mp3"),
	"quiero_retruco": preload("res://assets/audio/sounds/calls/quiero_retruco.mp3"),
	"quiero_vale4": preload("res://assets/audio/sounds/calls/quiero_vale4.mp3"),
}

# --- STRATEGIES ---
var _envido_strategy: CPUEnvidoStrategy
var _truco_strategy: CPUTrucoStrategy
var _flor_strategy: CPUFlorStrategy
var _card_strategy: CPUCardPlayStrategy

func _ready() -> void:
	# Create defaults if not assigned in editor
	if not personality:
		personality = CPUPersonality.create_default()
	if not skill:
		skill = CPUSkill.create_default()

	_mood = CPUMood.new(personality)
	_brain = CPUBrain.new(skill, personality, _mood)

	_init_strategies()
	_connect_signals()

func _init_strategies() -> void:
	_envido_strategy = CPUEnvidoStrategy.new(truco_manager, player, _brain)
	_truco_strategy = CPUTrucoStrategy.new(truco_manager, player, _brain)
	_flor_strategy = CPUFlorStrategy.new(truco_manager, player, _brain)
	_card_strategy = CPUCardPlayStrategy.new(player, _brain, truco_manager)

	# Connect Voice Signals
	if _envido_strategy.has_signal("voice_required"):
		_envido_strategy.voice_required.connect(_play_voice)
	if _truco_strategy.has_signal("voice_required"):
		_truco_strategy.voice_required.connect(_play_voice)
	if _flor_strategy.has_signal("voice_required"):
		_flor_strategy.voice_required.connect(_play_voice)

func _connect_signals() -> void:
	TrucoSignalBus.on_match_ended.connect(func(_w): _match_over = true)
	TrucoSignalBus.on_hand_started.connect(_on_hand_started)
	TrucoSignalBus.on_envido_resolved.connect(_on_envido_resolved)
	TrucoSignalBus.on_truco_resolved.connect(_on_truco_resolved)
	TrucoSignalBus.on_envido_called.connect(_on_envido_called)
	TrucoSignalBus.on_truco_called.connect(_on_truco_called_by_opponent)
	TrucoSignalBus.on_flor_called.connect(_on_flor_called_by_opponent)
	TrucoSignalBus.on_flor_resolved.connect(_on_flor_resolved)
	TrucoSignalBus.on_score_updated.connect(_on_score_updated)

# --- TURN MANAGEMENT ---

func start_turn() -> void:
	if _match_over: return
	super.start_turn()
	_waiting_for_response = false
	_schedule_decision(TrucoConstants.CPU_DECISION_DELAY)

## Schedules a decision to be made after a delay,
## invalidating any previous pending decisions.
func _schedule_decision(delay: float) -> void:
	_decision_token += 1
	var current_token: int = _decision_token
	get_tree().create_timer(delay).timeout.connect(_make_decision.bind(current_token))

func _make_decision(token: int) -> void:
	if token != _decision_token: return
	if _waiting_for_response: return
	if _match_over: return

	if truco_manager.current_turn_index != TrucoConstants.PLAYER_CPU:
		return

	if truco_manager.pending_response_action != TrucoConstants.ResponseAction.NONE:
		print_debug("CPU tried to decide but Manager is waiting for response. Rescheduling...")
		_schedule_decision(TrucoConstants.CPU_DECISION_DELAY)
		return

	var my_index: int = TrucoConstants.PLAYER_CPU

	# Priority: Flor > Envido > Truco > Play Card
	if _flor_strategy.try_call(my_index):
		_waiting_for_response = true
		return

	if _envido_strategy.try_call(my_index):
		_waiting_for_response = true
		return

	if _truco_strategy.try_call(my_index):
		_waiting_for_response = true
		return

	_play_card()

func _play_card() -> void:
	var card = _card_strategy.select_card()
	if card:
		card_played.emit(card)

func _play_voice(voice_key: String) -> void:
	if _voice_lines.has(voice_key):
		# print_debug("CPU Playing Voice: %s" % voice_key)
		calling_audio_player.stream = _voice_lines[voice_key]
		calling_audio_player.play()
	else:
		print_debug("CPU Voice Missing for key: %s" % voice_key)

# --- INCOMING CALL HANDLERS ---

func _on_envido_called(caller_index: int, _type: int) -> void:
	if _caller_was_CPU(caller_index): return
	_waiting_for_response = true
	_schedule_thought(func(): _envido_strategy.decide_response(TrucoConstants.PLAYER_CPU))

func _on_truco_called_by_opponent(caller_index: int, _level: int) -> void:
	if _caller_was_CPU(caller_index): return
	_waiting_for_response = true
	_schedule_thought(func(): _truco_strategy.decide_response(TrucoConstants.PLAYER_CPU))

func _on_flor_called_by_opponent(caller_index: int, type: int) -> void:
	if _caller_was_CPU(caller_index): return
	_waiting_for_response = true
	_schedule_thought(func(): _flor_strategy.decide_response(TrucoConstants.PLAYER_CPU, type))

func _caller_was_CPU(caller_index: int) -> bool:
	return caller_index == TrucoConstants.PLAYER_CPU

## Simulates thinking time before executing a callback.
func _schedule_thought(callback: Callable) -> void:
	get_tree().create_timer(1.0 + randf()).timeout.connect(callback)

# --- RESOLUTION HANDLERS ---

func _on_hand_started(_hand_num: int) -> void:
	_match_over = false
	_mood.decay()

func _on_envido_resolved(accepted: bool, winner_index: int, points: int) -> void:
	if _waiting_for_response:
		_waiting_for_response = false
		_schedule_decision(1.5)

	# Update mood based on envido result
	if winner_index == TrucoConstants.PLAYER_CPU:
		_mood.on_round_won()
	elif accepted:
		_mood.on_big_bet_lost(points)

func _on_truco_resolved(accepted: bool, _player_index: int, _current_level: int) -> void:
	if accepted:
		_waiting_for_response = false
		_schedule_decision(1.5)

func _on_flor_resolved(_accepted: bool, winner_index: int, points: int) -> void:
	_waiting_for_response = false
	_schedule_decision(1.5)

	# Update mood
	if winner_index == TrucoConstants.PLAYER_CPU:
		_mood.on_round_won()
	elif points > 0:
		_mood.on_big_bet_lost(points)

func _on_score_updated(human_score: int, cpu_score: int) -> void:
	_mood.update_score_pressure(cpu_score, human_score)
