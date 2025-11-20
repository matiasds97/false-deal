extends Control

@onready var envido_value_label: Label = %EnvidoValueLabel
@onready var flor_container: PanelContainer = %FlorContainer
@onready var deal_button: Button = $MarginContainer2/PanelContainer/HBoxContainer/DealButton
@onready var hand: Marker3D = $"../Hand"

func _ready() -> void:
	# Connect to Hand signals
	if hand:
		hand.envido_calculated.connect(_on_envido_calculated)
		hand.flor_detected.connect(_on_flor_detected)
		
		# Connect Deal Button to Hand
		deal_button.pressed.connect(hand.deal_new_hand)

func _on_envido_calculated(score: int) -> void:
	if envido_value_label:
		envido_value_label.text = str(score)

func _on_flor_detected(has_flor: bool) -> void:
	if flor_container:
		flor_container.visible = has_flor
