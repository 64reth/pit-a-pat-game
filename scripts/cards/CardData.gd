extends Resource
class_name CardData

@export var rank: String = "A"
@export var suit: String = "HEART"


func _init(card_rank: String = "A", card_suit: String = "HEART") -> void:
	rank = card_rank
	suit = card_suit
