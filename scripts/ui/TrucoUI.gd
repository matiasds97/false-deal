extends Control

@onready var envido_value_label: Label = %EnvidoValueLabel
@onready var flor_container: PanelContainer = %FlorContainer
@onready var deal_button: Button = $MarginContainer2/PanelContainer/HBoxContainer/DealButton
@onready var hand: Marker3D = $"../HumanHand"
@onready var cpu_hand: Node3D = $"../CPUHand"
@onready var truco_manager: TrucoManager = $"../TrucoManager"

func _ready() -> void:
	# Connect to Hand signals
	if hand:
		hand.envido_calculated.connect(_on_envido_calculated)
		hand.flor_detected.connect(_on_flor_detected)
		
	# Connect Deal Button to deal new hand
	deal_button.pressed.connect(_on_deal_button_pressed)

func _on_deal_button_pressed() -> void:
	# Reset visual hands
	if hand and hand.has_method("deal_new_hand"):
		hand.deal_new_hand()
	if cpu_hand and cpu_hand.has_method("reset_hand"):
		cpu_hand.reset_hand()
	
	# Start new hand in TrucoManager
	if truco_manager:
		truco_manager.start_new_hand()
	else:
		printerr("TrucoManager not found!")

func _on_envido_calculated(score: int) -> void:
	if envido_value_label:
		envido_value_label.text = str(score)

func _on_flor_detected(has_flor: bool) -> void:
	if flor_container:
		flor_container.visible = has_flor
