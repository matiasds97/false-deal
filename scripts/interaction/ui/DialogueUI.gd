extends CanvasLayer

## UI de diálogo estilo PS1 — caja oscura semitransparente en la parte inferior.
## Muestra speaker, texto con efecto typewriter, y botones de opciones.
## Se debe agregar al grupo "dialogue_ui" en el editor o por código.

# ─── Señales ──────────────────────────────────────────────────────────────────

## Emitida al iniciar un diálogo.
signal dialogue_started()

## Emitida al terminar todo el diálogo.
signal dialogue_finished()

## Emitida al seleccionar una opción con action_id.
signal choice_selected(action_id: String)

# ─── Exports ─────────────────────────────────────────────────────────────────

## Velocidad del efecto typewriter (caracteres por segundo).
@export var typewriter_speed: float = 40.0

## Frecuencia base del blip de diálogo (Hz). Valores más altos = tono más agudo.
@export var blip_frequency: float = 440.0

## Volumen del blip en dB.
@export var blip_volume_db: float = -18.0

# ─── Variables Privadas ──────────────────────────────────────────────────────

var _dialogue_data: DialogueData = null
var _current_message_index: int = 0
var _is_typing: bool = false
var _is_active: bool = false
var _full_text: String = ""
var _displayed_chars: int = 0
var _typewriter_timer: float = 0.0
var _player_controller: Node = null
var _blip_player: AudioStreamPlayer = null
var _blip_stream: AudioStreamWAV = null
var _float_tween: Tween = null

@onready var _panel: PanelContainer = $DialoguePanel
@onready var _speaker_label: Label = $DialoguePanel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var _text_label: RichTextLabel = $DialoguePanel/MarginContainer/VBoxContainer/TextLabel
@onready var _choices_container: VBoxContainer = $DialoguePanel/MarginContainer/VBoxContainer/ChoicesContainer
@onready var _continue_indicator: Label = $ContinueIndicator


# ─── Funciones Built-in ──────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("dialogue_ui")
	_panel.visible = false
	_continue_indicator.visible = false
	layer = 20
	_create_blip_sound()


func _process(delta: float) -> void:
	if not _is_active:
		return

	if _is_typing:
		_typewriter_timer += delta
		var chars_to_show: int = int(_typewriter_timer * typewriter_speed)
		if chars_to_show > _displayed_chars:
			var old_chars: int = _displayed_chars
			_displayed_chars = chars_to_show
			_text_label.visible_characters = _displayed_chars
			# Reproducir blip por cada nuevo carácter visible (ignorar espacios)
			if old_chars < _full_text.length():
				var new_char: String = _full_text[mini(old_chars, _full_text.length() - 1)]
				if new_char != " " and new_char != "\n":
					_play_blip()
			if _displayed_chars >= _full_text.length():
				_is_typing = false
				_on_typing_complete()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if _is_typing:
			# Mostrar todo el texto inmediatamente
			_is_typing = false
			_displayed_chars = _full_text.length()
			_text_label.visible_characters = -1
			_on_typing_complete()
		elif _choices_container.get_child_count() == 0:
			# Avanzar al siguiente mensaje
			_advance_dialogue()
		get_viewport().set_input_as_handled()


# ─── Funciones Públicas ─────────────────────────────────────────────────────

## Inicia un diálogo completo.
func start_dialogue(data: DialogueData) -> void:
	_dialogue_data = data
	_current_message_index = 0
	_is_active = true
	_panel.visible = true

	# Bloquear al jugador
	_player_controller = get_tree().get_first_node_in_group("first_person_player")
	if _player_controller and _player_controller.has_method("set_interacting"):
		_player_controller.set_interacting(true)

	dialogue_started.emit()
	_show_message(_current_message_index)


## Retorna si el diálogo está activo.
func is_active() -> bool:
	return _is_active


# ─── Funciones Privadas ─────────────────────────────────────────────────────

## Muestra un mensaje específico por índice.
func _show_message(index: int) -> void:
	if not _dialogue_data or index < 0 or index >= _dialogue_data.messages.size():
		_end_dialogue()
		return

	var message: DialogueMessage = _dialogue_data.messages[index]
	_current_message_index = index

	# Configurar speaker
	if message.speaker != "":
		_speaker_label.text = message.speaker
		_speaker_label.visible = true
	else:
		_speaker_label.visible = false

	# Iniciar typewriter
	_full_text = message.text
	_text_label.text = _full_text

	# Si el texto está vacío, saltar el typewriter
	if _full_text.is_empty():
		_text_label.visible_characters = -1
		_is_typing = false
		_on_typing_complete()
	else:
		_text_label.visible_characters = 0
		_displayed_chars = 0
		_typewriter_timer = 0.0
		_is_typing = true

	# Limpiar opciones previas
	_clear_choices()
	_hide_continue_indicator()


## Ejecuta al terminar el efecto typewriter.
func _on_typing_complete() -> void:
	var message: DialogueMessage = _dialogue_data.messages[_current_message_index]

	if message.choices.size() > 0:
		_show_choices(message.choices)
	else:
		_show_continue_indicator()


## Avanza al siguiente mensaje (sin opciones).
func _advance_dialogue() -> void:
	_hide_continue_indicator()
	var next_index: int = _current_message_index + 1
	_show_message(next_index)


## Muestra los botones de opciones.
func _show_choices(choices: Array[DialogueChoice]) -> void:
	_clear_choices()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	for i: int in range(choices.size()):
		var choice: DialogueChoice = choices[i]
		var button: Button = Button.new()
		button.text = choice.text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", _create_choice_style(false))
		button.add_theme_stylebox_override("hover", _create_choice_style(true))
		button.add_theme_stylebox_override("pressed", _create_choice_style(true))
		button.pressed.connect(_on_choice_pressed.bind(choice))
		_choices_container.add_child(button)


## Procesa la selección de una opción.
func _on_choice_pressed(choice: DialogueChoice) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_clear_choices()

	if choice.action_id != "":
		choice_selected.emit(choice.action_id)

	if choice.next_message_index >= 0:
		_show_message(choice.next_message_index)
	else:
		_end_dialogue()


## Limpia los botones de opciones.
func _clear_choices() -> void:
	for child: Node in _choices_container.get_children():
		child.queue_free()


## Finaliza el diálogo y libera al jugador.
func _end_dialogue() -> void:
	_is_active = false
	_panel.visible = false
	_hide_continue_indicator()
	_clear_choices()

	# Desbloquear al jugador
	if _player_controller and _player_controller.has_method("set_interacting"):
		_player_controller.set_interacting(false)
	_player_controller = null

	dialogue_finished.emit()


## Crea un StyleBoxFlat para los botones de opciones.
func _create_choice_style(highlighted: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if highlighted:
		style.bg_color = Color(1, 1, 1, 0.15)
	else:
		style.bg_color = Color(0, 0, 0, 0)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	return style


## Genera un sonido de blip corto proceduralmente (onda senoidal).
func _create_blip_sound() -> void:
	var sample_rate: int = 22050
	var duration: float = 0.03 # 30ms
	var num_samples: int = int(sample_rate * duration)

	var audio: AudioStreamWAV = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples)

	for i: int in range(num_samples):
		var t: float = float(i) / sample_rate
		# Onda senoidal con envolvente de fade-out para evitar clicks
		var envelope: float = 1.0 - (float(i) / num_samples)
		var sample: float = sin(t * blip_frequency * TAU) * envelope
		# Convertir a 8-bit unsigned (0-255, centro en 128)
		data[i] = int(sample * 80 + 128)

	audio.data = data
	_blip_stream = audio

	_blip_player = AudioStreamPlayer.new()
	_blip_player.stream = _blip_stream
	_blip_player.volume_db = blip_volume_db
	_blip_player.bus = "Master"
	add_child(_blip_player)


## Reproduce el blip con pitch ligeramente aleatorio.
func _play_blip() -> void:
	if _blip_player:
		_blip_player.pitch_scale = randf_range(0.9, 1.15)
		_blip_player.play()


## Muestra el indicador de continuar con animación de pulso.
func _show_continue_indicator() -> void:
	if _float_tween:
		_float_tween.kill()

	_continue_indicator.visible = true
	_continue_indicator.modulate.a = 1.0

	_float_tween = create_tween().set_loops()
	_float_tween.tween_property(_continue_indicator, "modulate:a", 0.3, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(_continue_indicator, "modulate:a", 1.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Oculta el indicador de continuar y detiene la animación.
func _hide_continue_indicator() -> void:
	_continue_indicator.visible = false
	_continue_indicator.modulate.a = 1.0
	_continue_indicator.offset_top = -30.0
	if _float_tween:
		_float_tween.kill()
		_float_tween = null
