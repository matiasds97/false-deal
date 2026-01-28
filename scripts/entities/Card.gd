class_name Card
extends Resource

enum Suit {
	CLUB,
	CUP,
	GOLD,
	SWORD
}

enum CardValue {
	ONE = 1,
	TWO = 2,
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
	SIX = 6,
	SEVEN = 7,
	TEN = 10,
	ELEVEN = 11,
	TWELVE = 12
}

## Defines the value of the card from 1 to 12.
@export var value: CardValue = CardValue.ONE

## Defines the suit of the card.
@export var suit: Suit

## Defines the truco value of the card.
var truco_value: int:
	get:
		return _calculate_truco_value()

## Defines the illustration that corresponds to this card.
@export var image: Texture2D

## Optional custom material to override the default texturing (e.g. for foils/shiny cards)
@export var custom_material: Material

var material: BaseMaterial3D = StandardMaterial3D.new()

func _init() -> void:
	material.albedo_texture = image

func _calculate_truco_value() -> int:
	match [suit, value]:
		[Suit.SWORD, CardValue.ONE]:
			return 14
		[Suit.CLUB, CardValue.ONE]:
			return 13
		[Suit.SWORD, CardValue.SEVEN]:
			return 12
		[Suit.GOLD, CardValue.SEVEN]:
			return 11
		[_, CardValue.THREE]:
			return 10
		[_, CardValue.TWO]:
			return 9
		[Suit.CUP, CardValue.ONE]:
			return 8
		[Suit.GOLD, CardValue.ONE]:
			return 8
		[_, CardValue.TWELVE]:
			return 7
		[_, CardValue.ELEVEN]:
			return 6
		[_, CardValue.TEN]:
			return 5
		[Suit.CLUB, CardValue.SEVEN]:
			return 4
		[Suit.CUP, CardValue.SEVEN]:
			return 4
		[_, CardValue.SIX]:
			return 3
		[_, CardValue.FIVE]:
			return 2
		[_, CardValue.FOUR]:
			return 1
		[_, _]:
			return 0
		_:
			return 0

## Compares the card with another card based on their truco values.[br][br]
## [param other_card]: The card to compare with.[br][br]
## Returns a positive integer if this card is higher,
## a negative integer if lower, and zero if equal.
func compare(other_card: Card) -> int:
	return truco_value - other_card.truco_value

## Checks if the card applies for envido. That means that the card
## is not a 10, 11 or 12.[br][br]
## Returns true if the card applies for envido. False otherwise.
func _is_envido_card() -> bool:
	return value >= CardValue.ONE and value <= CardValue.SEVEN

## Gets the value of this card for envido.[br][br]
## Returns the envido value of this card, or zero 
## if the card does not apply for envido.
func get_envido_value() -> int:
	if _is_envido_card():
		if value > CardValue.SEVEN:
			return 0
		else:
			return value
	return 0

# Override str() to return a string representation of the card.
func _to_string() -> String:
	var suit_name: String
	match suit:
		Suit.CLUB:
			suit_name = "Club"
		Suit.CUP:
			suit_name = "Cup"
		Suit.GOLD:
			suit_name = "Gold"
		Suit.SWORD:
			suit_name = "Sword"
	return "%s of %s" % [value, suit_name]
