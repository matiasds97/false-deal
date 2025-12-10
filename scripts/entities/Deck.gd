extends Node
class_name Deck

var cards: Array[Card] = []
var all_cards: Array[Card] = []

const CARD_PATH = "res://resources/cards/"

func _ready() -> void:
	var card_resources: Array[Card] = []
	if not DirAccess.dir_exists_absolute(CARD_PATH):
		printerr("Card resources directory does not exist!")
		return
	var dir: DirAccess = DirAccess.open(CARD_PATH)
	print_debug(dir)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() == false and file_name.ends_with(".tres"):
				var card_path: String = CARD_PATH + file_name
				var card_resource: Resource = ResourceLoader.load(card_path)
				if card_resource is Card:
					card_resources.append(card_resource)
			file_name = dir.get_next()
		dir.list_dir_end()
		cards = card_resources.duplicate()
		all_cards = card_resources.duplicate()

func reset() -> void:
	cards = all_cards.duplicate()

func draw_card() -> Card:
	if cards.size() == 0:
		return null
	var random_index: int = randi() % cards.size()
	var drawn_card: Card = cards[random_index]
	cards.remove_at(random_index)

	return drawn_card
