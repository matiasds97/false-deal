class_name TrucoResults
extends Control

## Results screen shown when the match ends.
## Displays "Victory" or "Defeat" and offers Replay/Exit buttons.

signal replay_requested
signal exit_requested

@onready var result_label: Label = %ResultLabel
@onready var replay_button: Button = %ReplayButton
@onready var exit_button: Button = %ExitButton
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

var _win_sting: AudioStream = preload("res://assets/audio/sounds/game_win.mp3")
var _lose_sting: AudioStream = preload("res://assets/audio/sounds/game_lose.mp3")

func _ready() -> void:
	replay_button.pressed.connect(func(): replay_requested.emit())
	exit_button.pressed.connect(func(): exit_requested.emit())

## Shows the results screen with the appropriate message, fading in.
func show_result(player_won: bool) -> void:
	if player_won:
		audio.set_stream(_win_sting)
		result_label.text = "Victory"
		result_label.add_theme_color_override("font_color", Color("#038f3b"))
	else:
		audio.set_stream(_lose_sting)
		result_label.text = "Defeat"
		result_label.add_theme_color_override("font_color", Color("#8f0303"))
	audio.play()
	modulate.a = 0.0
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_IN)
