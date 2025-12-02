class_name TrucoPlayerController
extends Node

##  This class is the base class for all player controllers.
##  It handles the logic for the player's turn. This class is used
##  as a template for all player controllers, including the Human
##  and AI controllers.

signal card_played(card: Card)
signal envido_called
signal truco_called
signal fold

var player: Player

func initialize(p_player: Player) -> void:
	player = p_player

func start_turn() -> void:
	pass

func end_turn() -> void:
	pass
