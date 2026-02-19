class_name TrucoMatchStart
extends Control

## Splash screen shown at the start of a match.
## Displays "Truco Match Start!", holds briefly, then fades out.

signal finished

@onready var label: Label = %MatchStartLabel

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

## Duration the splash stays fully visible before fading.
@export var hold_duration: float = 1.0
## Duration of the fade-out animation.
@export var fade_duration: float = 0.8

## Plays the splash: holds, fades out, then emits finished.
func play() -> void:
	visible = true
	modulate.a = 1.0
	audio.play()
	get_tree().create_timer(hold_duration).timeout.connect(_fade_out)

func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		visible = false
		finished.emit()
	)
