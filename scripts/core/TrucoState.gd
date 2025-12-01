class_name TrucoState

enum {
	WAITING_FOR_START,
	DEALING,
	PLAYER_TURN,
	RIVAL_TURN,
	CHALLENGE_PENDING, # Envido or Truco proposed.
	RESOLVING_TRICK, # End of a "mano".
	RESOLVING_HAND, # End of a round.
	MATCH_ENDED
}
