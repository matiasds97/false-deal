extends Node
@warning_ignore_start("UNUSED_SIGNAL")
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

# Emitted by Table to provide card placement information
# player_index: Which player is placing the card
# target_position: Global position where cards should be placed
# stack_height: Y offset for stacking cards
signal card_placement_info(player_index: int, target_position: Vector3, stack_height: float)

# Emitted when the score is updated
# human_score: The current score of the human player
# cpu_score: The current score of the CPU player
signal on_score_updated(human_score: int, cpu_score: int)

# Emitted when Envido is called
# player_index: Who called it
# type: The type of Envido called (EnvidoType enum)
signal on_envido_called(player_index: int, type: int)

# Emitted when Envido is resolved (accepted/rejected)
# accepted: true if "Quiero", false if "No Quiero"
# points: points awarded (for now just for the winner, logic might need refinement later for who won)
# winner_index: who takes the points (or who showed the best points)
signal on_envido_resolved(accepted: bool, winner_index: int, points: int)

# Emitted when Truco is called
# player_index: Who called it
# level: The level called (1=Truco, 2=Retruco, 3=Vale 4)
signal on_truco_called(player_index: int, level: int)

# Emitted when Truco is resolved
# accepted: true if accepted (stakes increase), false if rejected (round ends)
# player_index: Who responded (useful for logging)
# current_level: The new current level if accepted, or the level that was proposed if rejected (context dependent but useful)
signal on_truco_resolved(accepted: bool, player_index: int, current_level: int)

# Emitted when Flor is called
# player_index: Who called it
signal on_flor_called(player_index: int, type: int)

# Emitted when Flor is resolved (usually just points awarded, as flor is rarely 'rejected' in the same way, but Contraflor can be)
# accepted: if the contraflor was accepted or not? Actually Flor itself is declaration. 
# But for ContraFlor interactions:
signal on_flor_resolved(accepted: bool, winner_index: int, points: int)

# Emitted when the match ends (a player reached the winning score)
# winner_index: The player who won the match
signal on_match_ended(winner_index: int)
