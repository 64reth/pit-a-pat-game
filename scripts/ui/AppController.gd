extends Node

const GameTableScene := preload("res://scenes/main/Main.tscn")

const PLAYER_NAMES := ["You", "Bot 1", "Bot 2", "Bot 3"]
const LENGTH_OPTIONS := [5, 10, 15, 20, 25, 30]
const CHIP_OPTIONS := [500, 1000, 2500, 5000]
const MODE_QUICK_PLAY := "quick_play"
const MODE_GRAND_PRIX := "grand_prix"

var selected_length_index := 0
var selected_chips_index := 1
var current_table: Node
var current_hand_focus: Node
var last_hand_result := {}

var ui_layer: CanvasLayer
var main_menu: Control
var grand_prix_setup: Control
var between_hands: Control
var grand_prix_complete: Control

var setup_length_label: Label
var setup_chips_label: Label
var between_title_label: Label
var between_body_label: Label
var complete_title_label: Label
var complete_body_label: Label


func _ready() -> void:
	_build_ui()
	_show_main_menu()


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "Screens"
	add_child(ui_layer)

	main_menu = _build_main_menu()
	grand_prix_setup = _build_grand_prix_setup()
	between_hands = _build_between_hands()
	grand_prix_complete = _build_grand_prix_complete()

	ui_layer.add_child(main_menu)
	ui_layer.add_child(grand_prix_setup)
	ui_layer.add_child(between_hands)
	ui_layer.add_child(grand_prix_complete)


func _build_main_menu() -> Control:
	var screen := _make_screen("MainMenu")
	var panel := _make_panel(Vector2(390, 170), Vector2(500, 360))
	screen.add_child(panel)

	var title := _make_label("PIT-A-PAT", Vector2(40, 36), Vector2(420, 84), 44, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(title)

	var quick_play_button := _make_button("QuickPlayButton", "QUICK PLAY", Vector2(150, 140), Vector2(200, 42))
	quick_play_button.pressed.connect(_start_quick_play)
	panel.add_child(quick_play_button)

	var grand_prix_button := _make_button("GrandPrixButton", "GRAND PRIX", Vector2(150, 198), Vector2(200, 42))
	grand_prix_button.pressed.connect(_show_grand_prix_setup)
	panel.add_child(grand_prix_button)

	return screen


func _build_grand_prix_setup() -> Control:
	var screen := _make_screen("GrandPrixSetup")
	var panel := _make_panel(Vector2(310, 74), Vector2(660, 560))
	screen.add_child(panel)

	var title := _make_label("GRAND PRIX SETUP", Vector2(40, 26), Vector2(580, 44), 32, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(title)

	panel.add_child(_make_label("CHAMPIONSHIP LENGTH", Vector2(120, 100), Vector2(420, 26), 18, HORIZONTAL_ALIGNMENT_CENTER))
	var length_left := _make_button("LengthLeftButton", "<", Vector2(150, 138), Vector2(52, 38))
	length_left.pressed.connect(func() -> void: _cycle_length(-1))
	panel.add_child(length_left)
	setup_length_label = _make_label("", Vector2(212, 136), Vector2(236, 42), 24, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(setup_length_label)
	var length_right := _make_button("LengthRightButton", ">", Vector2(458, 138), Vector2(52, 38))
	length_right.pressed.connect(func() -> void: _cycle_length(1))
	panel.add_child(length_right)

	panel.add_child(_make_label("STARTING CHIPS", Vector2(120, 214), Vector2(420, 26), 18, HORIZONTAL_ALIGNMENT_CENTER))
	var chips_left := _make_button("ChipsLeftButton", "<", Vector2(150, 252), Vector2(52, 38))
	chips_left.pressed.connect(func() -> void: _cycle_chips(-1))
	panel.add_child(chips_left)
	setup_chips_label = _make_label("", Vector2(212, 250), Vector2(236, 42), 24, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(setup_chips_label)
	var chips_right := _make_button("ChipsRightButton", ">", Vector2(458, 252), Vector2(52, 38))
	chips_right.pressed.connect(func() -> void: _cycle_chips(1))
	panel.add_child(chips_right)

	var info := _make_label(
		"Ante rules: placeholder ante of £1 per player.\nPlayers: You, Bot 1, Bot 2, Bot 3.\nStandings are shown between hands so the table stays focused on play.",
		Vector2(70, 326),
		Vector2(520, 92),
		18,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(info)

	var start_button := _make_button("StartGrandPrixButton", "START CHAMPIONSHIP", Vector2(210, 452), Vector2(240, 42))
	start_button.pressed.connect(_start_grand_prix)
	panel.add_child(start_button)

	var back_button := _make_button("SetupBackButton", "MAIN MENU", Vector2(250, 504), Vector2(160, 34))
	back_button.pressed.connect(_show_main_menu)
	panel.add_child(back_button)

	_update_setup_labels()
	return screen


func _build_between_hands() -> Control:
	var screen := _make_screen("GrandPrixBetweenHands")
	var panel := _make_panel(Vector2(290, 70), Vector2(700, 575))
	screen.add_child(panel)

	between_title_label = _make_label("HAND OVER", Vector2(40, 28), Vector2(620, 42), 32, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(between_title_label)

	between_body_label = _make_label("", Vector2(70, 92), Vector2(560, 380), 20, HORIZONTAL_ALIGNMENT_LEFT)
	between_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(between_body_label)

	var next_button := _make_button("BeginNextHandButton", "BEGIN NEXT HAND", Vector2(230, 492), Vector2(240, 42))
	next_button.pressed.connect(_begin_next_grand_prix_hand)
	panel.add_child(next_button)

	return screen


func _build_grand_prix_complete() -> Control:
	var screen := _make_screen("GrandPrixComplete")
	var panel := _make_panel(Vector2(260, 58), Vector2(760, 604))
	screen.add_child(panel)

	complete_title_label = _make_label("CHAMPIONSHIP COMPLETE", Vector2(40, 26), Vector2(680, 42), 32, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(complete_title_label)

	complete_body_label = _make_label("", Vector2(70, 88), Vector2(620, 400), 20, HORIZONTAL_ALIGNMENT_LEFT)
	complete_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(complete_body_label)

	var menu_button := _make_button("CompleteMainMenuButton", "MAIN MENU", Vector2(180, 514), Vector2(180, 42))
	menu_button.pressed.connect(_show_main_menu)
	panel.add_child(menu_button)

	var new_grand_prix_button := _make_button("CompleteNewGrandPrixButton", "NEW GRAND PRIX", Vector2(400, 514), Vector2(180, 42))
	new_grand_prix_button.pressed.connect(_show_grand_prix_setup)
	panel.add_child(new_grand_prix_button)

	return screen


func _make_screen(screen_name: String) -> Control:
	var screen := Control.new()
	screen.name = screen_name
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.offset_left = 0.0
	screen.offset_top = 0.0
	screen.offset_right = 0.0
	screen.offset_bottom = 0.0

	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.02, 0.035, 0.035, 1.0)
	screen.add_child(background)
	return screen


func _make_panel(position: Vector2, size: Vector2) -> ColorRect:
	var panel := ColorRect.new()
	panel.name = "Panel"
	panel.position = position
	panel.size = size
	panel.color = Color(0.04, 0.06, 0.07, 0.96)
	return panel


func _make_label(text: String, position: Vector2, size: Vector2, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_button(button_name: String, text: String, position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.name = button_name
	button.position = position
	button.size = size
	button.text = text
	return button


func _show_only(screen: Control) -> void:
	for child in ui_layer.get_children():
		if child is Control:
			child.visible = child == screen


func _show_main_menu() -> void:
	_clear_current_table()
	_show_only(main_menu)


func _show_grand_prix_setup() -> void:
	_clear_current_table()
	_update_setup_labels()
	_show_only(grand_prix_setup)


func _start_quick_play() -> void:
	_start_table_session({
		"mode": MODE_QUICK_PLAY,
		"total_hands": 1,
		"starting_chips": 0,
		"external_results": false,
	})


func _start_grand_prix() -> void:
	_start_table_session({
		"mode": MODE_GRAND_PRIX,
		"total_hands": LENGTH_OPTIONS[selected_length_index],
		"starting_chips": CHIP_OPTIONS[selected_chips_index],
		"external_results": true,
	})


func _start_table_session(config: Dictionary) -> void:
	_clear_current_table()
	_hide_all_screens()

	current_table = GameTableScene.instantiate()
	current_hand_focus = current_table.get_node_or_null("PlayerHand")
	if current_hand_focus:
		current_hand_focus.set("auto_start", false)
	add_child(current_table)
	move_child(current_table, 0)

	current_hand_focus = current_table.get_node_or_null("PlayerHand")
	if not current_hand_focus:
		push_error("GameTable is missing PlayerHand.")
		_show_main_menu()
		return

	if current_hand_focus.has_signal("hand_finished"):
		current_hand_focus.connect("hand_finished", Callable(self, "_on_table_hand_finished"))

	current_hand_focus.start_session(config)


func _hide_all_screens() -> void:
	for child in ui_layer.get_children():
		if child is Control:
			child.visible = false


func _clear_current_table() -> void:
	if is_instance_valid(current_table):
		current_table.queue_free()

	current_table = null
	current_hand_focus = null
	last_hand_result = {}


func _cycle_length(direction: int) -> void:
	selected_length_index = wrapi(selected_length_index + direction, 0, LENGTH_OPTIONS.size())
	_update_setup_labels()


func _cycle_chips(direction: int) -> void:
	selected_chips_index = wrapi(selected_chips_index + direction, 0, CHIP_OPTIONS.size())
	_update_setup_labels()


func _update_setup_labels() -> void:
	if setup_length_label:
		setup_length_label.text = "%d HANDS" % LENGTH_OPTIONS[selected_length_index]

	if setup_chips_label:
		setup_chips_label.text = "£%d" % CHIP_OPTIONS[selected_chips_index]


func _on_table_hand_finished(result: Dictionary) -> void:
	if str(result.get("mode", MODE_QUICK_PLAY)) != MODE_GRAND_PRIX:
		return

	last_hand_result = result.duplicate(true)
	if is_instance_valid(current_table):
		current_table.visible = false

	if bool(result.get("championship_complete", false)):
		_show_grand_prix_complete(result)
	else:
		_show_between_hands(result)


func _show_between_hands(result: Dictionary) -> void:
	_update_between_hands(result)
	_show_only(between_hands)


func _update_between_hands(result: Dictionary) -> void:
	var hand_number := int(result.get("hand_number", 1))
	var total_hands := int(result.get("total_hands", 1))
	var winner := str(result.get("winner", "Stalemate"))
	var points_gained := int(result.get("points_gained", 0))
	var chips_gained := int(result.get("chips_gained", 0))
	between_title_label.text = "HAND %d / %d" % [hand_number, total_hands]

	var lines: Array[String] = []
	lines.append("Winner: %s" % (winner if not winner.is_empty() else "Stalemate"))
	lines.append("Points gained: %d" % points_gained)
	lines.append("Chips gained: £%d" % chips_gained)
	lines.append("")
	lines.append("Remaining Cards")
	lines.append_array(_format_remaining_cards(result))
	lines.append("")
	lines.append("Championship Standings")
	lines.append_array(_format_ranked_players(result))
	lines.append("")
	lines.append("Next: Hand %d / %d" % [hand_number + 1, total_hands])
	between_body_label.text = "\n".join(lines)


func _show_grand_prix_complete(result: Dictionary) -> void:
	_update_grand_prix_complete(result)
	_show_only(grand_prix_complete)


func _update_grand_prix_complete(result: Dictionary) -> void:
	var champion := str(result.get("champion", ""))
	if champion.is_empty():
		champion = "Undecided"

	var lines: Array[String] = []
	lines.append("CHAMPION:")
	lines.append(champion)
	lines.append("")
	lines.append("Final Standings")
	lines.append_array(_format_ranked_players(result, true))
	complete_body_label.text = "\n".join(lines)


func _begin_next_grand_prix_hand() -> void:
	if not is_instance_valid(current_table) or not current_hand_focus:
		_show_grand_prix_setup()
		return

	_hide_all_screens()
	current_table.visible = true
	current_hand_focus.start_next_grand_prix_hand()


func _format_remaining_cards(result: Dictionary) -> Array[String]:
	var remaining = result.get("remaining_cards", {})
	var lines: Array[String] = []
	for player_name in PLAYER_NAMES:
		lines.append("%s: %d cards" % [player_name, int(remaining.get(player_name, 0))])

	return lines


func _format_ranked_players(result: Dictionary, include_ordinal: bool = false) -> Array[String]:
	var ranked_players: Array = result.get("ranked_players", [])
	var lines: Array[String] = []
	for index in range(ranked_players.size()):
		var player: Dictionary = ranked_players[index]
		var prefix := "%s " % _get_ordinal(index + 1) if include_ordinal else ""
		lines.append("%s%s: %d pts, £%d" % [
			prefix,
			player.get("name", ""),
			int(player.get("points", 0)),
			int(player.get("chips", 0)),
		])

	return lines


func _get_ordinal(number: int) -> String:
	match number:
		1:
			return "1st"
		2:
			return "2nd"
		3:
			return "3rd"
		_:
			return "%dth" % number
