class_name DialogueData
extends Resource

## Secuencia completa de diálogo.
## Contiene un array de DialogueMessage que se recorren en orden,
## salvo que un DialogueChoice redirija a otro índice.
## @param messages: Lista ordenada de mensajes del diálogo.

@export var messages: Array[DialogueMessage] = []
