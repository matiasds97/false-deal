class_name DialogueMessage
extends Resource

## Mensaje individual dentro de un diálogo.
## Si choices está vacío, el jugador avanza con input.
## Si tiene choices, se muestran botones de opción.
## @param speaker: Nombre del hablante.
## @param text: Contenido del mensaje.
## @param choices: Opciones de respuesta del jugador.

@export var speaker: String = ""
@export_multiline var text: String = ""
@export var choices: Array[DialogueChoice] = []
