extends Node2D

@export var separation_pixels: float = 16.0
@export var separation_duration: float = 0.1
@export var hovered_z_index_boost: int = 100

var cards: Array[Node2D] = []
var focused_card: Node2D
var selected_card: Node2D
var original_states := {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	for child in get_children():
		if child is Node2D:
			var card := child as Node2D
			cards.append(card)
			original_states[card] = {
				"position": card.position,
				"rotation": card.rotation,
				"scale": card.scale,
				"z_index": card.z_index,
			}

			if card.has_method("set_hand_controlled"):
				card.set_hand_controlled(true)

			card.set("hover_z_index_boost", hovered_z_index_boost)

			if card.has_signal("hover_started"):
				card.hover_started.connect(_on_card_hover_started)

			if card.has_signal("hover_ended"):
				card.hover_ended.connect(_on_card_hover_ended)

			if card.has_signal("card_clicked"):
				card.card_clicked.connect(_on_card_clicked)


func _process(_delta: float) -> void:
	_set_focused_card(_find_hovered_card_at(get_global_mouse_position()))


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var clicked_card := _find_hovered_card_at(get_global_mouse_position())
	if not is_instance_valid(clicked_card):
		return

	if clicked_card.has_method("click"):
		clicked_card.click()
		get_viewport().set_input_as_handled()


func _find_hovered_card_at(global_point: Vector2) -> Node2D:
	var best_card: Node2D = null
	var best_z_index := -2147483648
	var best_child_index := -1

	for index in range(cards.size()):
		var card := cards[index]
		if not card.has_method("is_global_point_over_card"):
			continue

		if not card.is_global_point_over_card(global_point):
			continue

		if card.z_index > best_z_index or (card.z_index == best_z_index and index > best_child_index):
			best_card = card
			best_z_index = card.z_index
			best_child_index = index

	return best_card


func _set_focused_card(card: Node2D) -> void:
	if card == focused_card:
		return

	if is_instance_valid(focused_card) and focused_card.has_method("set_hover_active"):
		focused_card.set_hover_active(false)

	if is_instance_valid(card) and card.has_method("set_hover_active"):
		card.set_hover_active(true)


func _on_card_hover_started(card: Node2D) -> void:
	focused_card = card
	_apply_focus_offsets(_get_focus_anchor_card())


func _on_card_hover_ended(card: Node2D) -> void:
	if card != focused_card:
		return

	focused_card = null
	_apply_focus_offsets(_get_focus_anchor_card())


func _on_card_clicked(card: Node2D) -> void:
	if card == selected_card:
		_set_selected_card(null)
	else:
		_set_selected_card(card)


func _set_selected_card(card: Node2D) -> void:
	if card == selected_card:
		return

	if is_instance_valid(selected_card) and selected_card.has_method("set_selected_active"):
		selected_card.set_selected_active(false)

	selected_card = card

	if is_instance_valid(selected_card) and selected_card.has_method("set_selected_active"):
		selected_card.set_selected_active(true)

	_apply_focus_offsets(_get_focus_anchor_card())


func _get_focus_anchor_card() -> Node2D:
	if is_instance_valid(selected_card):
		return selected_card

	return focused_card


func _apply_focus_offsets(card: Node2D) -> void:
	var focused_index := cards.find(card)

	for index in range(cards.size()):
		var current_card := cards[index]
		var offset := Vector2.ZERO

		if focused_index != -1:
			if index < focused_index:
				offset.x = -separation_pixels
			elif index > focused_index:
				offset.x = separation_pixels

		if current_card.has_method("set_hand_focus_offset"):
			current_card.set_hand_focus_offset(offset, separation_duration)
