class_name DialogueChoice
extends Resource

## Opción de respuesta del jugador dentro de un diálogo.
## @param text: Texto visible de la opción.
## @param next_message_index: Índice del siguiente mensaje (-1 = terminar diálogo).
## @param action_id: Identificador para disparar acciones custom en la escena.

@export var text: String = ""
@export var next_message_index: int = -1
@export var action_id: String = ""
