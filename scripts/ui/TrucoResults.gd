class_name TrucoResults
extends Control

## Results screen shown when the match ends.
## Displays "Victory" or "Defeat" and offers Replay/Exit buttons.

signal replay_requested
signal exit_requested

@onready var result_label: Label = %ResultLabel
@onready var replay_button: Button = %ReplayButton
@onready var exit_button: Button = %ExitButton

func _ready() -> void:
	replay_button.pressed.connect(func(): replay_requested.emit())
	exit_button.pressed.connect(func(): exit_requested.emit())

## Shows the results screen with the appropriate message, fading in.
func show_result(player_won: bool) -> void:
	if player_won:
		result_label.text = "Victory"
	else:
		result_label.text = "Defeat"
	modulate.a = 0.0
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_IN)
