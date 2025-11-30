class_name TrucoPlayerController
extends Node

signal card_played(card: Card)
signal envido_called
signal truco_called
signal fold

var player: Player

func initialize(p_player: Player) -> void:
	player = p_player

func start_turn() -> void:
	print("%s start_turn (Base)" % player.name)

func end_turn() -> void:
	pass
