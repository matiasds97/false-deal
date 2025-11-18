extends Marker3D

@onready var card_1: MeshInstance3D = $Card1
@onready var card_2: MeshInstance3D = $Card2
@onready var card_3: MeshInstance3D = $Card3

@export var deck: Deck

func _ready() -> void:
	var cards_in_hand: Array[Card] = []
	for i in range(3):
		var drawn_card: Card = deck.draw_card()
		if drawn_card:
			cards_in_hand.append(drawn_card)
	var card_nodes: Array[MeshInstance3D] = [card_1, card_2, card_3]
	for j in range(cards_in_hand.size()):
		var card: Card = cards_in_hand[j]
		var card_node: MeshInstance3D = card_nodes[j]
		card_node.set_surface_override_material(0, card.material)
		card_node.get_surface_override_material(0).albedo_texture = card.image
		card_node.visible = true
