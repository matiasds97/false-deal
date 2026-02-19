class_name CPUCardPlayStrategy
extends RefCounted

## CPU strategy for choosing which card to play.
## Uses game context (opponent's played card, vuelta results) to make
## situational decisions, modified by personality style and skill noise.

var _player: Player
var _brain: CPUBrain
var _manager: TrucoManager

func _init(player: Player, brain: CPUBrain, manager: TrucoManager) -> void:
	_player = player
	_brain = brain
	_manager = manager


## Selects a card to play from the CPU's hand.
## Returns the selected Card, or null if no cards are available.
func select_card() -> Card:
	if _player.hand.is_empty():
		return null

	if _player.hand.size() == 1:
		return _player.hand[0]

	var params: CPUBrain.EffectiveParams = _brain.get_effective_params()

	# Decision noise: random card sometimes (simulates mistakes)
	if randf() < params.decision_noise * 0.25:
		return _player.hand[randi() % _player.hand.size()]

	# Get game context
	var game: TrucoGame = _manager.game
	var opponent_card: Card = _get_opponent_card_in_current_vuelta(game)
	var vuelta_number: int = game.vuelta_results.size() # 0 = first, 1 = second, 2 = third
	var cpu_vueltas_won: int = _count_vueltas_won(game, TrucoConstants.PLAYER_CPU)
	var human_vueltas_won: int = _count_vueltas_won(game, TrucoConstants.PLAYER_HUMAN)

	# --- SITUATIONAL LOGIC ---

	# If opponent already played a card in this vuelta, react to it
	if opponent_card:
		return _react_to_opponent_card(opponent_card, params, cpu_vueltas_won, human_vueltas_won)

	# CPU plays first — use personality style + situation
	return _play_first(params, vuelta_number, cpu_vueltas_won, human_vueltas_won)


## When reacting to the opponent's already-played card.
func _react_to_opponent_card(
	opponent_card: Card,
	params: CPUBrain.EffectiveParams,
	cpu_won: int,
	human_won: int
) -> Card:
	# Find the cheapest card that beats the opponent's card
	var cheapest_winner: Card = _get_cheapest_winner(opponent_card)

	# If we already won a vuelta, we just need to win this one
	if cpu_won >= 1 and cheapest_winner:
		return cheapest_winner

	# If opponent won a vuelta — we MUST win this one or lose the round
	if human_won >= 1:
		if cheapest_winner:
			return cheapest_winner
		# Can't beat it — play the weakest card (save the good one for tie-breaker or next vuelta)
		return _select_lowest()

	# First vuelta, no pressure yet — style-dependent
	if cheapest_winner:
		match params.card_play_style:
			CPUPersonality.CardPlayStyle.CONSERVATIVE:
				# Use the cheapest winner — save better cards
				return cheapest_winner
			CPUPersonality.CardPlayStyle.AGGRESSIVE:
				# Dominate — play the strongest card we have
				return _select_highest()
			CPUPersonality.CardPlayStyle.BALANCED:
				return cheapest_winner
	else:
		# Can't beat it — sacrifice the weakest card
		return _select_lowest()

	return cheapest_winner


## When the CPU plays first in a vuelta.
func _play_first(
	params: CPUBrain.EffectiveParams,
	vuelta_number: int,
	cpu_won: int,
	human_won: int
) -> Card:
	# If we already won a vuelta, play conservatively (just need one more win or tie)
	if cpu_won >= 1:
		return _select_lowest()

	# If opponent won a vuelta, we're under pressure — play strong
	if human_won >= 1:
		return _select_highest()

	# First vuelta, playing first — personality-driven
	match params.card_play_style:
		CPUPersonality.CardPlayStyle.CONSERVATIVE:
			return _select_lowest()
		CPUPersonality.CardPlayStyle.AGGRESSIVE:
			return _select_highest()
		CPUPersonality.CardPlayStyle.BALANCED:
			return _select_balanced()

	return _player.hand[0]


# --- CARD SELECTION HELPERS ---

## Returns the weakest card that still beats the opponent's card, or null.
func _get_cheapest_winner(opponent_card: Card) -> Card:
	var winners: Array[Card] = []
	for card in _player.hand:
		if card.compare(opponent_card) > 0:
			winners.append(card)

	if winners.is_empty():
		return null

	# Sort ascending by truco value, pick the lowest winner
	winners.sort_custom(func(a: Card, b: Card) -> bool: return a.compare(b) < 0)
	return winners[0]


## Conservative: play the weakest card first, save the best for later.
func _select_lowest() -> Card:
	var lowest: Card = _player.hand[0]
	for card in _player.hand:
		if card.compare(lowest) < 0:
			lowest = card
	return lowest


## Aggressive: lead with the strongest card.
func _select_highest() -> Card:
	var highest: Card = _player.hand[0]
	for card in _player.hand:
		if card.compare(highest) > 0:
			highest = card
	return highest


## Balanced: play a mid-strength card — not the best, not the worst.
## If only 2 cards remain, plays the weaker one (save best for last).
func _select_balanced() -> Card:
	if _player.hand.size() == 2:
		return _select_lowest()

	# With 3 cards: sort and pick the middle one
	var sorted_hand: Array[Card] = _player.hand.duplicate()
	sorted_hand.sort_custom(func(a: Card, b: Card) -> bool: return a.compare(b) < 0)
	return sorted_hand[1]


# --- GAME CONTEXT HELPERS ---

## Gets the opponent's card in the current vuelta, if they already played.
func _get_opponent_card_in_current_vuelta(game: TrucoGame) -> Card:
	for entry in game.cards_played_current_vuelta:
		if entry["player_index"] != TrucoConstants.PLAYER_CPU:
			return entry["card"] as Card
	return null


## Counts how many vueltas a player has won so far.
func _count_vueltas_won(game: TrucoGame, player_index: int) -> int:
	var count: int = 0
	for result in game.vuelta_results:
		if result == player_index:
			count += 1
	return count
