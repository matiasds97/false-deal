extends Marker3D

@onready var card_1: MeshInstance3D = $Card1
@onready var card_2: MeshInstance3D = $Card2
@onready var card_3: MeshInstance3D = $Card3

var cards_in_hand: Array[Card] = []

@export var deck: Deck

signal envido_calculated(score: int)
signal flor_detected(has_flor: bool)


func _ready() -> void:
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
	
	emit_signal("envido_calculated", get_envido_points())
	emit_signal("flor_detected", has_flor())

func deal_new_hand() -> void:
	deck.reset()
	cards_in_hand.clear()
	
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
		
		card_node.visible = true
		
	emit_signal("envido_calculated", get_envido_points())
	emit_signal("flor_detected", has_flor())

## If there are at least two cards of the same suit, envido = 20 + sum of the two
## highest envido values in that suit (cards 10/11/12 count as 0).
## Otherwise return the highest single envido card value.
func get_envido_points() -> int:
	var suits_cards = {}
	for card in cards_in_hand:
		if not suits_cards.has(card.suit):
			suits_cards[card.suit] = []
		suits_cards[card.suit].append(card)

	var best_pair_envido = 0
	for suit in suits_cards.keys():
		var cards_of_suit = suits_cards[suit]
		if cards_of_suit.size() < 2:
			continue

		var vals = []
		for c in cards_of_suit:
			vals.append(c.get_envido_value())
		vals.sort_custom(func(a, b): return a > b)
		var pair_sum = vals[0] + vals[1]
		var suit_envido = 20 + pair_sum
		if suit_envido > best_pair_envido:
			best_pair_envido = suit_envido

	if best_pair_envido > 0:
		return best_pair_envido

	# Fallback: highest single envido card value
	var best_single = 0
	for c in cards_in_hand:
		best_single = max(best_single, c.get_envido_value())
	return best_single

## If all three cards are of the same suit, return true.
## Otherwise return false.
func has_flor() -> bool:
	if cards_in_hand.size() < 3:
		return false
	var first_suit = cards_in_hand[0].suit
	for i in range(1, cards_in_hand.size()):
		if cards_in_hand[i].suit != first_suit:
			return false
	return true
