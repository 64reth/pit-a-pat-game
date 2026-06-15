extends RefCounted
class_name Deck

const CardDataScript := preload("res://scripts/cards/CardData.gd")

const RANKS := [
	"A",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"10",
	"J",
	"Q",
	"K",
]

const SUITS := [
	"HEART",
	"DIAMOND",
	"SPADE",
	"CLUB",
]

var cards: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	cards.clear()

	for suit in SUITS:
		for rank in RANKS:
			cards.append(CardDataScript.new(rank, suit))


func shuffle() -> void:
	cards.shuffle()


func deal(count: int) -> Array:
	var dealt_cards: Array = []
	var deal_count: int = min(count, cards.size())

	for index in range(deal_count):
		dealt_cards.append(cards.pop_front())

	return dealt_cards
