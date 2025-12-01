class_name Player
extends Resource

var name: String
var hand: Array[Card] = []
var is_human: bool = false
var partner: Player = null
var team: int = 0  # 0 or 1 for two teams in 2v2 game

func _init(p_name: String, p_is_human: bool = false, p_team: int = 0):
	name = p_name
	is_human = p_is_human
	team = p_team

func receive_card(card: Card) -> void:
	hand.append(card)

func play_card(card_index: int) -> Card:
	if card_index >= 0 and card_index < hand.size():
		var card = hand[card_index]
		hand.remove_at(card_index)
		return card
	else:
		push_warning("Invalid card index: %d" % card_index)
		return null

func play_specific_card(card: Card) -> bool:
	var index = hand.find(card)
	if index != -1:
		hand.remove_at(index)
		return true
	else:
		push_warning("Card not found in hand: %s" % card)
		return false

func has_card(card: Card) -> bool:
	return hand.has(card)

func get_hand_size() -> int:
	return hand.size()

func can_play_card(card: Card) -> bool:
	# Basic check - player can play any card from their hand
	return hand.has(card)

# Get the highest card in hand according to Truco hierarchy
func get_highest_card() -> Card:
	if hand.is_empty():
		return null
	
	var highest_card = hand[0]
	for card in hand:
		if card.compare(highest_card) > 0:
			highest_card = card
	
	return highest_card

# Sort hand according to Truco hierarchy (highest first)
func sort_hand() -> void:
	hand.sort_custom(func(a, b): return a.compare(b) > 0)

func get_envido_points() -> int:
	# Envido: if there are at least two cards of the same suit,
	# take the two cards with the highest envido values (10/11/12 count as 0)
	# and return 20 + sum_of_those_two. If no two-cards same suit exist,
	# return the highest single envido card value (or 0).

	var suits_cards = {}
	for card in hand:
		if not suits_cards.has(card.suit):
			suits_cards[card.suit] = []
		suits_cards[card.suit].append(card)

	var max_envido = 0
	# Check each suit for at least two cards and compute best pair
	for suit in suits_cards.keys():
		var cards_of_suit = suits_cards[suit]
		if cards_of_suit.size() < 2:
			continue

		# compute envido values for cards in this suit (10/11/12 -> 0)
		var vals = []
		for c in cards_of_suit:
			vals.append(c.get_envido_value())
		# sort descending
		vals.sort_custom(func(a, b): return a > b)
		var pair_sum = vals[0] + vals[1]
		var suit_envido = 20 + pair_sum
		if suit_envido > max_envido:
			max_envido = suit_envido

	if max_envido > 0:
		return max_envido

	# Fallback: no pair of same suit -> best single envido card (0..7)
	var best_single = 0
	for c in hand:
		best_single = max(best_single, c.get_envido_value())
	return best_single

func _to_string() -> String:
	var result = "Player: %s\n" % name
	result += "Hand:\n"
	for i in range(hand.size()):
		result += "  %d: %s\n" % [i, hand[i]]
	return result
