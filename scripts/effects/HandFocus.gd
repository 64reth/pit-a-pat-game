extends Node2D

const DeckScript := preload("res://scripts/cards/Deck.gd")
const CardScene := preload("res://scenes/cards/Card.tscn")

@export var separation_pixels: float = 16.0
@export var separation_duration: float = 0.1
@export var hovered_z_index_boost: int = 100
@export var drag_start_pixels: float = 4.0
@export var play_zone_path: NodePath = ^"../PlayZone"
@export var active_card_node_path: NodePath = ^"../ActiveCard"
@export var deck_count_label_path: NodePath = ^"../DeckArea/DeckCountLabel"
@export var opponent_info_label_path: NodePath = ^"../OpponentInfo"
@export var turn_label_path: NodePath = ^"../TurnBanner"
@export var feedback_label_path: NodePath = ^"../CommentaryPanel/MessagesLabel"
@export var play_button_path: NodePath = ^"../ActionButtons/PlayButton"
@export var pass_button_path: NodePath = ^"../ActionButtons/PassButton"
@export var tap_button_path: NodePath = ^"../ActionButtons/TapButton"
@export var end_turn_button_path: NodePath = ^"../ActionButtons/EndTurnButton"
@export var new_hand_button_path: NodePath = ^"../ActionButtons/NewHandButton"
@export var rank_choice_container_path: NodePath = ^"../RankChoiceButtons"
@export var max_feedback_messages: int = 4
@export var ante_amount: int = 1
@export var max_auto_actions_per_hand: int = 100

const PLAYER_NAMES := ["You", "Bot 1", "Bot 2", "Bot 3"]
const PHASE_DEALING := "DEALING"
const PHASE_PLAYER_TURN := "PLAYER_TURN"
const PHASE_PLAYER_DISCARD_CHOICE := "PLAYER_DISCARD_CHOICE"
const PHASE_BOT_TURN := "BOT_TURN"
const PHASE_HAND_OVER := "HAND_OVER"

var cards: Array[Node2D] = []
var focused_card: Node2D
var selected_card: Node2D
var selected_cards: Array = []
var pending_drag_card: Node2D
var dragged_card: Node2D
var dragged_stack: Array = []
var drag_stack_offsets := {}
var drag_start_global_position := Vector2.ZERO
var drag_card_global_offset := Vector2.ZERO
var deck: RefCounted
var active_card_data
var original_states := {}
var feedback_messages: Array[String] = []
var hands: Array = [[], [], [], []]
var dealer_index := 2
var current_player_index := 0
var pot := 0
var consecutive_passes := 0
var auto_turn_action_count := 0
var game_phase := PHASE_HAND_OVER
var hand_over := false
var waiting_for_bot := false
var player_has_tapped := false


func _ready() -> void:
	print("DEBUG: _ready start")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	deck = DeckScript.new()

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

	var active_card := _get_active_card_node()
	if active_card:
		active_card.visible = false
		if active_card.has_method("set_hand_controlled"):
			active_card.set_hand_controlled(true)

	_connect_action_buttons()
	start_new_hand()
	print("DEBUG: _ready end")


func start_new_hand() -> void:
	print("DEBUG: start_new_hand start")
	_set_phase(PHASE_DEALING)
	hand_over = false
	waiting_for_bot = false
	pending_drag_card = null
	dragged_card = null
	dragged_stack.clear()
	drag_stack_offsets.clear()
	selected_card = null
	_clear_selected_cards()
	focused_card = null
	player_has_tapped = false
	consecutive_passes = 0
	auto_turn_action_count = 0
	_clear_rank_choice_buttons()
	pot = PLAYER_NAMES.size() * ante_amount
	dealer_index = (dealer_index + 1) % PLAYER_NAMES.size()
	current_player_index = (dealer_index + 1) % PLAYER_NAMES.size()

	if not deck:
		_log_error_and_end_hand("Missing deck.")
		return

	deck.reset()
	deck.shuffle()
	print("DEBUG: deck reset/shuffle count=%d" % deck.cards.size())

	for index in range(hands.size()):
		hands[index] = deck.deal(5)
		print("DEBUG: dealt player=%d count=%d deck=%d" % [index, hands[index].size(), deck.cards.size()])

	var drawn_active_cards: Array = deck.deal(1)
	if not drawn_active_cards.is_empty():
		_set_active_card(drawn_active_cards[0])
		print("DEBUG: active card dealt %s %s deck=%d" % [active_card_data.rank, active_card_data.suit, deck.cards.size()])

	_render_player_hand()
	_set_feedback("Cards dealt.")
	_set_feedback("Active card drawn.")
	_begin_current_turn()
	print("DEBUG: start_new_hand end phase=%s current_player=%d" % [game_phase, current_player_index])


func deal_player_hand() -> void:
	start_new_hand()


func _set_phase(next_phase: String) -> void:
	if game_phase == next_phase:
		return

	var old_phase := game_phase
	game_phase = next_phase
	print("PHASE: %s -> %s" % [old_phase, game_phase])

	_clear_rank_choice_buttons()


func _begin_current_turn() -> void:
	if hand_over or game_phase == PHASE_HAND_OVER:
		return

	print("TURN: %d / %s" % [current_player_index, PLAYER_NAMES[current_player_index]])

	if current_player_index == 0:
		auto_turn_action_count = 0
		waiting_for_bot = false
		_set_phase(PHASE_PLAYER_TURN)
		_set_turn_feedback()
		_update_table_ui()
		print("DEBUG: automatic processing stopped at PLAYER_TURN")
		return

	_set_phase(PHASE_BOT_TURN)
	_set_turn_feedback()
	_update_table_ui()
	call_deferred("_run_bot_turns")


func _log_error_and_end_hand(message: String) -> void:
	push_error(message)
	print(message)
	_set_feedback(message)
	_end_hand_stalemate()


func _apply_card_data(card: Node2D, card_data) -> void:
	card.set("rank", card_data.rank)
	card.set("suit", card_data.suit)


func _set_active_card(card_data) -> void:
	if not card_data:
		_log_error_and_end_hand("Cannot set active card: card data is missing.")
		return

	active_card_data = card_data
	print("DEBUG: set active card %s %s" % [active_card_data.rank, active_card_data.suit])

	var active_card := _get_active_card_node()
	if not active_card:
		push_error("Missing active card node at path: %s" % active_card_node_path)
		print("Missing active card node at path: %s" % active_card_node_path)
		return

	active_card.visible = true
	if active_card.has_method("set_hand_controlled"):
		active_card.set_hand_controlled(true)
	_apply_card_data(active_card, active_card_data)


func _get_active_card_node() -> Node2D:
	return get_node_or_null(active_card_node_path) as Node2D


func _get_active_rank() -> String:
	if active_card_data:
		return active_card_data.rank

	return "A"


func cards_match(card_a, card_b) -> bool:
	return card_a.rank == card_b.rank or card_a.suit == card_b.suit


func _render_player_hand() -> void:
	if hands.is_empty():
		_log_error_and_end_hand("Cannot render player hand: hands are missing.")
		return

	var player_hand: Array = hands[0]
	_ensure_player_card_nodes(player_hand.size())

	for index in range(cards.size()):
		var card := cards[index]
		card.visible = index < player_hand.size()
		card.position = original_states[card]["position"]
		card.rotation = original_states[card]["rotation"]
		card.scale = original_states[card]["scale"]
		card.z_index = original_states[card]["z_index"]
		if card.has_method("snap_to_hand"):
			card.snap_to_hand()

		if index < player_hand.size():
			_apply_card_data(card, player_hand[index])


func _ensure_player_card_nodes(card_count: int) -> void:
	while cards.size() < card_count:
		var card_index := cards.size()
		var base_state := _get_authored_state_for_index(card_index)
		var card := CardScene.instantiate() as Node2D
		card.name = "HandCard%d" % (card_index + 1)
		card.position = base_state["position"]
		card.rotation = base_state["rotation"]
		card.scale = base_state["scale"]
		card.z_index = base_state["z_index"]
		add_child(card)
		_register_hand_card(card, card_index)


func _register_hand_card(card: Node2D, _index: int) -> void:
	cards.append(card)

	if not original_states.has(card):
		original_states[card] = {
			"position": card.position,
			"rotation": card.rotation,
			"scale": card.scale,
			"z_index": card.z_index,
		}

	if card.has_method("set_hand_controlled"):
		card.set_hand_controlled(true)

	card.set("hover_z_index_boost", hovered_z_index_boost)

	if card.has_signal("hover_started") and not card.hover_started.is_connected(_on_card_hover_started):
		card.hover_started.connect(_on_card_hover_started)

	if card.has_signal("hover_ended") and not card.hover_ended.is_connected(_on_card_hover_ended):
		card.hover_ended.connect(_on_card_hover_ended)

	if card.has_signal("card_clicked") and not card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.connect(_on_card_clicked)


func _get_authored_state_for_index(index: int) -> Dictionary:
	if original_states.is_empty():
		return {
			"position": Vector2.ZERO,
			"rotation": 0.0,
			"scale": Vector2.ONE,
			"z_index": index * 10,
		}

	if cards.size() == 1:
		var only_card := cards[0]
		return {
			"position": original_states[only_card]["position"] + Vector2(index * 56.0, 0.0),
			"rotation": original_states[only_card]["rotation"],
			"scale": original_states[only_card]["scale"],
			"z_index": index * 10,
		}

	var last_card := cards[cards.size() - 1]
	var previous_card := cards[cards.size() - 2]
	var last_position: Vector2 = original_states[last_card]["position"]
	var previous_position: Vector2 = original_states[previous_card]["position"]
	var step := last_position - previous_position

	return {
		"position": last_position + step,
		"rotation": original_states[last_card]["rotation"],
		"scale": original_states[last_card]["scale"],
		"z_index": index * 10,
	}


func _process(_delta: float) -> void:
	if hand_over or is_instance_valid(dragged_card):
		return

	_set_focused_card(_find_hovered_card_at(get_global_mouse_position()))


func _input(event: InputEvent) -> void:
	if hand_over or current_player_index != 0:
		return

	if game_phase != PHASE_PLAYER_TURN and game_phase != PHASE_PLAYER_DISCARD_CHOICE:
		return

	if event is InputEventMouseMotion:
		_update_drag_motion()
		return

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_begin_pending_drag()
		return

	_finish_pointer_interaction()


func _find_hovered_card_at(global_point: Vector2) -> Node2D:
	var best_card: Node2D = null
	var best_z_index := -2147483648
	var best_child_index := -1

	for index in range(cards.size()):
		var card := cards[index]
		if not card.visible:
			continue
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


func _begin_pending_drag() -> void:
	if current_player_index != 0:
		return

	if is_instance_valid(dragged_card):
		return

	var hovered_card := _find_hovered_card_at(get_global_mouse_position())
	if not is_instance_valid(hovered_card):
		return

	pending_drag_card = hovered_card
	drag_start_global_position = get_global_mouse_position()
	drag_card_global_offset = pending_drag_card.global_position - drag_start_global_position
	get_viewport().set_input_as_handled()


func _update_drag_motion() -> void:
	if is_instance_valid(dragged_card):
		_set_dragged_stack_global_position(get_global_mouse_position() + drag_card_global_offset)
		get_viewport().set_input_as_handled()
		return

	if not is_instance_valid(pending_drag_card):
		return

	if get_global_mouse_position().distance_to(drag_start_global_position) < drag_start_pixels:
		return

	_start_drag(pending_drag_card)
	_set_dragged_stack_global_position(get_global_mouse_position() + drag_card_global_offset)
	get_viewport().set_input_as_handled()


func _start_drag(card: Node2D) -> void:
	dragged_card = card
	pending_drag_card = null
	dragged_stack = selected_cards.duplicate() if selected_cards.has(card) else [card]
	drag_stack_offsets.clear()

	if is_instance_valid(focused_card) and focused_card != dragged_card and focused_card.has_method("set_hover_active"):
		focused_card.set_hover_active(false)

	focused_card = dragged_card
	for stack_card in dragged_stack:
		drag_stack_offsets[stack_card] = stack_card.global_position - dragged_card.global_position
		if stack_card.has_method("set_hover_active"):
			stack_card.set_hover_active(stack_card == dragged_card)
		if stack_card.has_method("set_drag_active"):
			stack_card.set_drag_active(true)

	_apply_focus_offsets(dragged_card)


func _set_dragged_stack_global_position(anchor_global_position: Vector2) -> void:
	for stack_card in dragged_stack:
		if not is_instance_valid(stack_card):
			continue

		var offset: Vector2 = drag_stack_offsets.get(stack_card, Vector2.ZERO)
		if stack_card.has_method("set_drag_global_position"):
			stack_card.set_drag_global_position(anchor_global_position + offset)


func _finish_pointer_interaction() -> void:
	if is_instance_valid(dragged_card):
		_finish_drag()
		get_viewport().set_input_as_handled()
		return

	if is_instance_valid(pending_drag_card):
		var clicked_card := pending_drag_card
		pending_drag_card = null

		if clicked_card.is_global_point_over_card(get_global_mouse_position()) and clicked_card.has_method("click"):
			clicked_card.click()
			get_viewport().set_input_as_handled()


func _finish_drag() -> void:
	var card := dragged_card
	var stack := dragged_stack.duplicate()
	dragged_card = null
	pending_drag_card = null
	dragged_stack.clear()
	drag_stack_offsets.clear()
	if stack.is_empty() and is_instance_valid(card):
		stack = [card]

	if _is_global_point_in_play_zone(get_global_mouse_position()):
		if selected_cards.has(card):
			_finish_player_chain_drop(stack)
		else:
			_finish_player_card_drop(card)
	else:
		for stack_card in stack:
			if stack_card.has_method("snap_to_hand"):
				stack_card.snap_to_hand()
		if selected_cards.has(card):
			_clear_selected_cards()
		else:
			_set_selected_card(null)

	_set_focused_card(null)
	_apply_focus_offsets(_get_focus_anchor_card())


func _finish_player_chain_drop(stack: Array) -> void:
	if game_phase != PHASE_PLAYER_TURN:
		_snap_cards_to_hand(stack)
		_set_feedback("Chains can only start on your turn.")
		return

	var chain_cards := _get_selected_chain_data()
	if chain_cards.is_empty() or not _validate_card_chain(chain_cards):
		_snap_cards_to_hand(stack)
		_clear_selected_cards()
		_set_feedback("Invalid chain.")
		return

	_play_valid_player_chain(chain_cards)


func _finish_player_card_drop(card: Node2D) -> void:
	var hand_index := cards.find(card)
	if hand_index < 0 or hand_index >= hands[0].size():
		_set_feedback("Invalid play — card is not in your hand.")
		if card.has_method("snap_to_hand"):
			card.snap_to_hand()
		return

	var played_card = hands[0][hand_index]
	if game_phase == PHASE_PLAYER_TURN:
		_play_player_opening_card(card, hand_index, played_card)
		return

	if game_phase == PHASE_PLAYER_DISCARD_CHOICE:
		_play_player_discard_card(card, hand_index, played_card)
		return

	if card.has_method("snap_to_hand"):
		card.snap_to_hand()


func _play_player_opening_card(card: Node2D, hand_index: int, played_card) -> void:
	if not active_card_data or not cards_match(played_card, active_card_data):
		var invalid_message := "Invalid play — match the active card."
		print("Invalid play")
		_set_feedback(invalid_message)
		_set_selected_card(null)
		if card.has_method("snap_to_hand"):
			card.snap_to_hand()
		return

	consecutive_passes = 0
	_remove_card_from_hand(0, hand_index)
	_set_active_card(played_card)
	_set_selected_card(null)
	_set_feedback("Played %s %s." % [played_card.rank, played_card.suit])
	print("Card played: %s %s" % [played_card.rank, played_card.suit])
	_render_player_hand()

	if _check_empty_hand_after_play(0):
		_update_table_ui()
	else:
		_set_phase(PHASE_PLAYER_DISCARD_CHOICE)
		_set_feedback("Discard any card to set the new active card, or end turn.")

	_update_table_ui()


func _play_player_discard_card(card: Node2D, hand_index: int, played_card) -> void:
	_remove_card_from_hand(0, hand_index)
	_set_active_card(played_card)
	_set_selected_card(null)
	_set_feedback("Discarded %s %s." % [played_card.rank, played_card.suit])
	print("Card discarded: %s %s" % [played_card.rank, played_card.suit])
	_render_player_hand()
	if _check_empty_hand_after_play(0):
		return

	_advance_turn()
	_update_table_ui()


func _get_selected_chain_data() -> Array:
	var chain_cards: Array = []
	for card in selected_cards:
		var hand_index := cards.find(card)
		if hand_index < 0 or hand_index >= hands[0].size():
			return []

		chain_cards.append(hands[0][hand_index])

	return chain_cards


func _validate_card_chain(chain_cards: Array) -> bool:
	if chain_cards.is_empty() or not active_card_data:
		return false

	if not cards_match(chain_cards[0], active_card_data):
		return false

	for index in range(1, chain_cards.size()):
		if not cards_match(chain_cards[index], chain_cards[index - 1]):
			return false

	return true


func _play_valid_player_chain(chain_cards: Array) -> void:
	var chain_description := _describe_card_chain(chain_cards)
	var final_card = chain_cards[chain_cards.size() - 1]
	_remove_selected_cards_from_player_hand()
	consecutive_passes = 0
	_set_active_card(final_card)
	_set_feedback("Played chain: %s." % chain_description)
	print("Played chain: %s" % chain_description)
	_clear_selected_cards()
	_render_player_hand()
	if _check_empty_hand_after_play(0):
		return

	_advance_turn()
	_update_table_ui()


func _remove_selected_cards_from_player_hand() -> void:
	var indices: Array[int] = []
	for card in selected_cards:
		var hand_index := cards.find(card)
		if hand_index >= 0 and hand_index < hands[0].size():
			indices.append(hand_index)

	indices.sort()
	indices.reverse()
	for hand_index in indices:
		_remove_card_from_hand(0, hand_index)


func _snap_cards_to_hand(stack: Array) -> void:
	for card in stack:
		if is_instance_valid(card) and card.has_method("snap_to_hand"):
			card.snap_to_hand()


func _get_play_zone() -> CanvasItem:
	var play_zone := get_node_or_null(play_zone_path) as CanvasItem
	if not play_zone:
		push_error("Missing play zone at path: %s" % play_zone_path)
		print("Missing play zone at path: %s" % play_zone_path)

	return play_zone


func _is_global_point_in_play_zone(global_point: Vector2) -> bool:
	var play_zone := _get_play_zone()
	if not play_zone:
		return false

	if play_zone is Control:
		return (play_zone as Control).get_global_rect().has_point(global_point)

	if play_zone is Node2D:
		var node := play_zone as Node2D
		return Rect2(node.global_position - Vector2(110, 90), Vector2(220, 180)).has_point(global_point)

	return false


func _get_play_zone_center() -> Vector2:
	var play_zone := _get_play_zone()
	if play_zone is Control:
		var rect := (play_zone as Control).get_global_rect()
		return rect.position + rect.size * 0.5

	if play_zone is Node2D:
		return (play_zone as Node2D).global_position

	return get_global_mouse_position()


func _update_table_ui() -> void:
	var deck_count_label := get_node_or_null(deck_count_label_path) as Label
	if deck_count_label:
		if deck:
			deck_count_label.text = "COUNT: %d" % deck.cards.size()
		else:
			deck_count_label.text = "COUNT: ?"

	var turn_label := get_node_or_null(turn_label_path) as Label
	if turn_label:
		if hand_over:
			turn_label.text = "HAND OVER"
		elif game_phase == PHASE_PLAYER_DISCARD_CHOICE:
			turn_label.text = "DISCARD"
		else:
			turn_label.text = "%s TURN" % PLAYER_NAMES[current_player_index].to_upper()

	var opponent_info_label := get_node_or_null(opponent_info_label_path) as Label
	if opponent_info_label:
		opponent_info_label.text = "BOT HANDS: %d / %d / %d" % [
			hands[1].size(),
			hands[2].size(),
			hands[3].size(),
		]

	var play_button := get_node_or_null(play_button_path) as Button
	if play_button:
		play_button.disabled = true

	var pass_button := get_node_or_null(pass_button_path) as Button
	if pass_button:
		pass_button.disabled = hand_over or game_phase != PHASE_PLAYER_TURN or current_player_index != 0 or hands[0].is_empty() or _hand_has_match(hands[0], active_card_data)

	var tap_button := get_node_or_null(tap_button_path) as Button
	if tap_button:
		tap_button.disabled = hand_over or game_phase != PHASE_PLAYER_TURN or current_player_index != 0 or hands[0].is_empty() or player_has_tapped

	var end_turn_button := get_node_or_null(end_turn_button_path) as Button
	if end_turn_button:
		end_turn_button.disabled = hand_over or game_phase != PHASE_PLAYER_DISCARD_CHOICE or current_player_index != 0


func _set_feedback(message: String) -> void:
	feedback_messages.push_front(message)
	if feedback_messages.size() > max_feedback_messages:
		feedback_messages.resize(max_feedback_messages)

	var feedback_label := get_node_or_null(feedback_label_path) as Label
	if feedback_label:
		feedback_label.text = "\n".join(feedback_messages)


func _connect_action_buttons() -> void:
	var play_button := get_node_or_null(play_button_path) as Button
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)

	var pass_button := get_node_or_null(pass_button_path) as Button
	if pass_button:
		pass_button.pressed.connect(_on_pass_button_pressed)

	var tap_button := get_node_or_null(tap_button_path) as Button
	if tap_button:
		tap_button.pressed.connect(_on_tap_button_pressed)

	var end_turn_button := get_node_or_null(end_turn_button_path) as Button
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)

	var new_hand_button := get_node_or_null(new_hand_button_path) as Button
	if new_hand_button:
		new_hand_button.pressed.connect(start_new_hand)


func _clear_rank_choice_buttons() -> void:
	var container := get_node_or_null(rank_choice_container_path) as Control
	if not container:
		push_error("Missing rank choice container at path: %s" % rank_choice_container_path)
		print("Missing rank choice container at path: %s" % rank_choice_container_path)
		return

	for child in container.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		child.queue_free()

	container.visible = false


func _on_play_button_pressed() -> void:
	_set_feedback("Drag a matching card to play.")
	_update_table_ui()


func _on_pass_button_pressed() -> void:
	if hand_over or game_phase != PHASE_PLAYER_TURN or current_player_index != 0:
		return

	if _hand_has_match(hands[0], active_card_data):
		_set_feedback("You must play the active card.")
		_update_table_ui()
		return

	_set_feedback("You passed.")
	consecutive_passes += 1
	_advance_turn()
	_update_table_ui()


func _on_tap_button_pressed() -> void:
	if hand_over or game_phase != PHASE_PLAYER_TURN or current_player_index != 0:
		return

	if hands[0].is_empty():
		_update_table_ui()
		return

	player_has_tapped = true
	_set_feedback("TAP called — play out to win.")
	_update_table_ui()


func _on_end_turn_button_pressed() -> void:
	if hand_over or game_phase != PHASE_PLAYER_DISCARD_CHOICE or current_player_index != 0:
		return

	_set_feedback("Turn ended.")
	_advance_turn()
	_update_table_ui()


func _run_bot_turns() -> void:
	print("DEBUG: bot turn loop requested phase=%s player=%d waiting=%s" % [game_phase, current_player_index, waiting_for_bot])
	if waiting_for_bot or hand_over or game_phase != PHASE_BOT_TURN or current_player_index == 0:
		return

	waiting_for_bot = true
	print("DEBUG: bot turn loop start")
	while not hand_over and game_phase == PHASE_BOT_TURN and current_player_index != 0:
		if not _record_auto_turn_action():
			break

		await get_tree().create_timer(0.25).timeout
		if hand_over or game_phase == PHASE_HAND_OVER:
			break

		_take_bot_turn(current_player_index)

	waiting_for_bot = false
	print("DEBUG: bot turn loop end phase=%s player=%d actions=%d" % [game_phase, current_player_index, auto_turn_action_count])
	_update_table_ui()


func _take_bot_turn(player_index: int) -> void:
	if hand_over or game_phase != PHASE_BOT_TURN:
		return

	print("DEBUG: bot turn start player=%d hand=%d active=%s %s" % [player_index, hands[player_index].size(), active_card_data.rank, active_card_data.suit])
	if _hand_has_match(hands[player_index], active_card_data):
		var match_index := _get_first_matching_card_index(hands[player_index], active_card_data)
		var matched_card = _remove_card_from_hand(player_index, match_index)
		consecutive_passes = 0
		_set_active_card(matched_card)
		_set_feedback("%s played %s %s." % [PLAYER_NAMES[player_index], matched_card.rank, matched_card.suit])
		if _check_empty_hand_after_play(player_index):
			return

		var discard_index: int = randi() % hands[player_index].size()
		var discard_card = _remove_card_from_hand(player_index, discard_index)
		_set_active_card(discard_card)
		_set_feedback("%s discarded %s %s." % [PLAYER_NAMES[player_index], discard_card.rank, discard_card.suit])
		if _check_empty_hand_after_play(player_index):
			return
	else:
		_set_feedback("%s passed." % PLAYER_NAMES[player_index])
		consecutive_passes += 1

	print("DEBUG: bot turn end player=%d consecutive_passes=%d" % [player_index, consecutive_passes])
	_advance_turn()
	_update_table_ui()


func _record_auto_turn_action() -> bool:
	auto_turn_action_count += 1
	if auto_turn_action_count <= max_auto_actions_per_hand:
		return true

	var message := "Safety stop: possible infinite turn loop"
	print("SAFETY STOP: auto turn loop")
	_set_feedback(message)
	waiting_for_bot = false
	current_player_index = 0
	_set_phase(PHASE_PLAYER_TURN)
	_set_turn_feedback()
	_update_table_ui()
	return false


func _advance_turn() -> void:
	print("DEBUG: advance_turn from player=%d phase=%s" % [current_player_index, game_phase])
	current_player_index = (current_player_index + 1) % PLAYER_NAMES.size()
	_resolve_pass_cycle_if_needed()
	if hand_over:
		return

	print("DEBUG: advance_turn to player=%d" % current_player_index)
	_begin_current_turn()


func _resolve_pass_cycle_if_needed() -> void:
	if consecutive_passes < _get_active_player_count():
		return

	_set_feedback("Nobody could play. Drawing cards.")
	print("Nobody could play. Drawing cards.")
	print("DEBUG: pass cycle draw start deck=%d" % (deck.cards.size() if deck else -1))

	if not deck:
		_log_error_and_end_hand("Cannot draw cards: deck is missing.")
		return

	if deck.cards.is_empty():
		_set_feedback("Deck is empty.")
		print("Deck is empty.")
		_end_hand_stalemate()
		return

	for player_index in range(hands.size()):
		if deck.cards.is_empty():
			_set_feedback("Deck is empty.")
			print("Deck is empty.")
			_end_hand_stalemate()
			return

		var drawn_cards: Array = deck.deal(1)
		if not drawn_cards.is_empty():
			hands[player_index].append(drawn_cards[0])

	consecutive_passes = 0
	_render_player_hand()
	_update_table_ui()
	print("DEBUG: pass cycle draw end deck=%d" % deck.cards.size())


func _get_active_player_count() -> int:
	return PLAYER_NAMES.size()


func _set_turn_feedback() -> void:
	if current_player_index == 0:
		_set_feedback("Your turn.")
	else:
		_set_feedback("%s's turn." % PLAYER_NAMES[current_player_index])


func _hand_has_match(hand: Array, active_card) -> bool:
	if not active_card:
		return false

	for card_data in hand:
		if cards_match(card_data, active_card):
			return true

	return false


func _get_first_matching_card_index(hand: Array, active_card) -> int:
	if not active_card:
		return -1

	for index in range(hand.size()):
		if cards_match(hand[index], active_card):
			return index

	return -1


func _remove_card_from_hand(player_index: int, card_index: int):
	if player_index < 0 or player_index >= hands.size():
		return null

	if card_index < 0 or card_index >= hands[player_index].size():
		return null

	return hands[player_index].pop_at(card_index)


func _check_empty_hand_after_play(player_index: int) -> bool:
	if player_index < 0 or player_index >= hands.size():
		return false

	if not hands[player_index].is_empty():
		return false

	print("WIN CHECK: %s hand_count=0" % PLAYER_NAMES[player_index])

	if player_index == 0:
		_resolve_player_empty_hand()
		return true

	waiting_for_bot = false
	_end_hand(player_index)
	return true


func _resolve_player_empty_hand() -> void:
	if player_has_tapped:
		player_has_tapped = false
		_end_hand(0)
		return

	player_has_tapped = false
	var penalty_cards: Array = deck.deal(1) if deck else []
	if penalty_cards.is_empty():
		_set_feedback("Forgot to TAP — no penalty card available.")
		_end_hand_stalemate()
		return

	hands[0].append(penalty_cards[0])
	_set_feedback("Forgot to TAP — draw 1.")
	_render_player_hand()
	_set_phase(PHASE_PLAYER_TURN)
	_update_table_ui()


func _end_hand(winner_index: int) -> void:
	hand_over = true
	waiting_for_bot = false
	if winner_index == 0:
		player_has_tapped = false
	_set_phase(PHASE_HAND_OVER)
	current_player_index = winner_index
	if winner_index == 0:
		_set_feedback("You win the pot.")
	else:
		_set_feedback("%s wins the hand." % PLAYER_NAMES[winner_index])

	_update_table_ui()


func _end_hand_stalemate() -> void:
	hand_over = true
	_set_phase(PHASE_HAND_OVER)
	_set_feedback("Hand ends in stalemate.")
	_update_table_ui()


func _describe_played_cards(played_cards: Array) -> String:
	if played_cards.is_empty():
		return "0 cards"

	var rank_name: String = played_cards[0].rank
	var rank_label := _plural_rank(rank_name, played_cards.size())
	return "%d %s" % [played_cards.size(), rank_label]


func _describe_card_chain(chain_cards: Array) -> String:
	if chain_cards.is_empty():
		return "empty"

	var labels: Array[String] = []
	for card_data in chain_cards:
		labels.append("%s %s" % [card_data.rank, card_data.suit])

	return " -> ".join(labels)


func _plural_rank(rank_name: String, count: int) -> String:
	var rank_labels := {
		"A": "Ace",
		"J": "Jack",
		"Q": "Queen",
		"K": "King",
	}
	var label: String = rank_labels.get(rank_name, rank_name)
	if count == 1:
		return label

	if label.ends_with("x"):
		return "%ses" % label

	return "%ss" % label


func _on_card_hover_started(card: Node2D) -> void:
	focused_card = card
	_apply_focus_offsets(_get_focus_anchor_card())


func _on_card_hover_ended(card: Node2D) -> void:
	if card != focused_card:
		return

	focused_card = null
	_apply_focus_offsets(_get_focus_anchor_card())


func _on_card_clicked(card: Node2D) -> void:
	if hand_over or game_phase != PHASE_PLAYER_TURN or current_player_index != 0:
		return

	if selected_cards.has(card):
		_remove_card_from_selection(card)
		return

	_add_card_to_selection(card)


func _add_card_to_selection(card: Node2D) -> void:
	var hand_index := cards.find(card)
	if hand_index < 0 or hand_index >= hands[0].size():
		return

	var card_data = hands[0][hand_index]
	var previous_card_data = active_card_data if selected_cards.is_empty() else _get_card_data_for_node(selected_cards[selected_cards.size() - 1])
	if not previous_card_data or not cards_match(card_data, previous_card_data):
		_set_feedback("That card does not continue the chain.")
		print("Rejected chain card: %s %s" % [card_data.rank, card_data.suit])
		return

	selected_cards.append(card)
	selected_card = card
	if card.has_method("set_selected_active"):
		card.set_selected_active(true)

	var chain_description := _describe_card_chain(_get_selected_chain_data())
	_set_feedback("Selected chain: %s." % chain_description)
	print("Selected chain: %s" % chain_description)
	_apply_focus_offsets(_get_focus_anchor_card())


func _remove_card_from_selection(card: Node2D) -> void:
	var selection_index := selected_cards.find(card)
	if selection_index == -1:
		return

	var removed_cards := selected_cards.slice(selection_index)
	for removed_card in removed_cards:
		if removed_card.has_method("set_selected_active"):
			removed_card.set_selected_active(false)

	selected_cards.resize(selection_index)

	selected_card = selected_cards[selected_cards.size() - 1] if not selected_cards.is_empty() else null
	var chain_description := _describe_card_chain(_get_selected_chain_data())
	print("Selected chain: %s" % chain_description)
	_apply_focus_offsets(_get_focus_anchor_card())


func _clear_selected_cards() -> void:
	for card in selected_cards:
		if is_instance_valid(card) and card.has_method("set_selected_active"):
			card.set_selected_active(false)

	selected_cards.clear()
	selected_card = null


func _get_card_data_for_node(card: Node2D):
	var hand_index := cards.find(card)
	if hand_index < 0 or hand_index >= hands[0].size():
		return null

	return hands[0][hand_index]


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
