extends Node

# Emitted when a card is dealt to a player
# player_index: 0 for Human, 1 for CPU
# card: The card data (Resource)
signal on_card_dealt(player_index: int, card: Card)

# Emitted when a new hand starts (clears table, resets deck)
signal on_hand_started(hand_number: int)

# Emitted when a turn starts
signal on_turn_started(player_index: int)

# Emitted when a player plays a card
# player_index: Who played it
# card: The card played
signal on_card_played(player_index: int, card: Card)

# Emitted when a baza is resolved (winner determined)
signal on_baza_resolved(winner_index: int)

# Emitted when the user selects a card in the UI
signal on_user_input_card_selected(card: Card)
