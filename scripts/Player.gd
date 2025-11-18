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
	# Calculate the best envido possible with the cards in hand
	var suits_cards = {}
	
	# Group ALL cards by suit, not just envido cards
	for card in hand:
		if not suits_cards.has(card.suit):
			suits_cards[card.suit] = []
		suits_cards[card.suit].append(card)
	
	var max_envido = 0
	
	# Calculate best envido for each suit
	for suit in suits_cards.keys():
		var cards_of_suit = suits_cards[suit]
		
		# Separate envido and non-envido cards
		var envido_cards = []
		var non_envido_cards = []
		
		for card in cards_of_suit:
			if card.is_envido_card():
				envido_cards.append(card)
			else:
				non_envido_cards.append(card)
		
		# Calculate possible envido scores for this suit
		var suit_envido = 0
		
		# Option 1: Two or more envido cards in the suit (20 + two highest envido values)
		if envido_cards.size() >= 2:
			# Sort envido cards by their envido value in descending order
			envido_cards.sort_custom(func(a, b): return a.get_envido_value() > b.get_envido_value())
			# Take the two highest envido cards
			var envido_score = 20 + envido_cards[0].get_envido_value() + envido_cards[1].get_envido_value()
			suit_envido = max(suit_envido, envido_score)
		
		# Option 2: Two or more non-envido cards in the suit (worth 20 points)
		if non_envido_cards.size() >= 2:
			suit_envido = max(suit_envido, 20)
		
		# Option 3: One envido card + one or more non-envido cards in the suit (20 + highest envido card value)
		if envido_cards.size() >= 1 and non_envido_cards.size() >= 1:
			# Find the highest envido value among envido cards 
			var highest_envido_value = 0
			for card in envido_cards:
				if card.get_envido_value() > highest_envido_value:
					highest_envido_value = card.get_envido_value()

			var mixed_envido = 20 + highest_envido_value
			suit_envido = max(suit_envido, mixed_envido)
		
		# Option 4: Just one envido card (no envido possible with just one card in suit)
		# Only if there are no other options
		if envido_cards.size() == 1 and non_envido_cards.size() == 0 and suit_envido == 0:
			# With just one envido card in the suit, you can't form envido
			# So this doesn't contribute to the score
			pass
		
		max_envido = max(max_envido, suit_envido)
	
	# If no envido possible, return 0
	return max_envido

func _to_string() -> String:
	var result = "Player: %s\n" % name
	result += "Hand:\n"
	for i in range(hand.size()):
		result += "  %d: %s\n" % [i, hand[i]]
	return result
