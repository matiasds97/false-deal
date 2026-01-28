class_name TrucoNotificationDisplay
extends VBoxContainer

## Handles displaying in-game notifications (Rival calls, results).

@export var rival_calls_label: Label
@export var result_label: Label

func show_call(text: String) -> void:
	if rival_calls_label:
		rival_calls_label.text = text
		rival_calls_label.visible = true

func hide_call() -> void:
	if rival_calls_label:
		rival_calls_label.visible = false

func show_result(text: String, color: Color = Color.WHITE) -> void:
	if result_label:
		result_label.text = text
		result_label.add_theme_color_override("font_color", color)
		# Auto clear after some time? TrucoUI managed state reset on hand start.

func clear_result() -> void:
	if result_label:
		result_label.text = ""
		result_label.remove_theme_color_override("font_color")

func on_envido_resolved(accepted: bool, winner_index: int, points: int, p0_score: int, p1_score: int) -> void:
	hide_call()
	
	if accepted:
		if winner_index == TrucoConstants.PLAYER_HUMAN:
			show_result("You won the envido! (Yours: %d vs CPU: %d)" % [p0_score, p1_score], Color.GREEN)
		else:
			show_result("CPU won the envido. (CPU: %d vs Yours: %d)" % [p1_score, p0_score], Color.RED)
	else:
		if winner_index == TrucoConstants.PLAYER_HUMAN:
			show_result("CPU rejected the envido")
		else:
			show_result("You rejected the envido")

func on_truco_resolved(accepted: bool, player_index: int, level: int) -> void:
	hide_call()
	clear_result() # Reset color
	
	var level_name = "truco"
	match level:
		1: level_name = "truco"
		2: level_name = "retruco"
		3: level_name = "vale 4"
	
	if accepted:
		if player_index == TrucoConstants.PLAYER_CPU:
			show_result("CPU accepted the %s" % level_name)
		else:
			show_result("You accepted the %s" % level_name)
	else:
		if player_index == TrucoConstants.PLAYER_CPU:
			show_result("CPU rejected the %s" % level_name)
		else:
			show_result("You rejected the %s" % level_name)

func on_flor_resolved(accepted: bool, winner_index: int, points: int) -> void:
	hide_call()
	
	if accepted:
		if winner_index == TrucoConstants.PLAYER_HUMAN:
			show_result("You won the Flor! (+%d)" % points, Color.GREEN)
		else:
			show_result("CPU won the Flor. (+%d)" % points, Color.RED)
	else:
		if winner_index == TrucoConstants.PLAYER_HUMAN:
			show_result("CPU achicó (folded)")
		else:
			show_result("Te achicaste")
