class_name TrucoCPUPlayerController
extends TrucoPlayerController
## Controls the AI opponent's actions by delegating decisions to strategy classes.
## Handles turn scheduling, response coordination, and strategy orchestration.

@onready var truco_manager: TrucoManager = $"../TrucoManager"
@onready var calling_audio_player: AudioStreamPlayer3D = $CallingAudioPlayer

## Whether we are waiting for a response from the opponent.
var _waiting_for_response: bool = false

## Simple bluff factor for this hand (could be randomized per hand start).
## In the future it should be parameterized for every different opponent.
var _bluff_factor: float = 0.0

## Token used to prevent race conditions by invalidating old scheduled
## decisions if a new one is made.
var _decision_token: int = 0

# --- STRATEGIES ---
var _envido_strategy: CPUEnvidoStrategy
var _truco_strategy: CPUTrucoStrategy
var _flor_strategy: CPUFlorStrategy
var _card_strategy: CPUCardPlayStrategy

func _ready() -> void:
	_bluff_factor = randf()
	_init_strategies()
	_connect_signals()

func _init_strategies() -> void:
	_envido_strategy = CPUEnvidoStrategy.new(truco_manager, player, _bluff_factor)
	_truco_strategy = CPUTrucoStrategy.new(truco_manager, player, _bluff_factor)
	_flor_strategy = CPUFlorStrategy.new(truco_manager, player)
	_card_strategy = CPUCardPlayStrategy.new(player)

func _connect_signals() -> void:
	TrucoSignalBus.on_envido_resolved.connect(_on_envido_resolved)
	TrucoSignalBus.on_truco_resolved.connect(_on_truco_resolved)
	TrucoSignalBus.on_envido_called.connect(_on_envido_called)
	TrucoSignalBus.on_truco_called.connect(_on_truco_called_by_opponent)
	TrucoSignalBus.on_flor_called.connect(_on_flor_called_by_opponent)
	TrucoSignalBus.on_flor_resolved.connect(_on_flor_resolved)

# --- TURN MANAGEMENT ---

func start_turn() -> void:
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

func _on_envido_resolved(_accepted: bool, _winner_index: int, _points: int) -> void:
	if _waiting_for_response:
		_waiting_for_response = false
		_schedule_decision(1.5)

func _on_truco_resolved(accepted: bool, _player_index: int, _current_level: int) -> void:
	if accepted:
		_waiting_for_response = false
		_schedule_decision(1.5)

func _on_flor_resolved(_accepted: bool, _winner_index: int, _points: int) -> void:
	_waiting_for_response = false
	_schedule_decision(1.5)
