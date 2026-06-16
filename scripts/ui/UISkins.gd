extends RefCounted

const ATLAS := preload("res://assets/ui/panels/ui_panel_atlas_v01.png")
const UI_FONT := preload("res://assets/fonts/pixel_operator/PixelOperator.ttf")
const InfoPanel := preload("res://scripts/ui/InfoPanel.gd")
const CELL_SIZE := 32

const ROW_INFO := 0
const ROW_PASS_NORMAL := 1
const ROW_TAP_NORMAL := 2
const ROW_PLAY_NORMAL := 3
const ROW_PASS_PRESSED := 4
const ROW_TAP_PRESSED := 5
const ROW_PLAY_PRESSED := 6
const ROW_PASS_HOVER := 7
const ROW_TAP_HOVER := 8
const ROW_PLAY_HOVER := 9
const ROW_UTILITY := 10

const ACTION_CONTENT_MARGIN := 8.0
const PANEL_CONTENT_MARGIN := 14.0
const TEXT_OUTLINE_SIZE := 1
const TEXT_OUTLINE_COLOR := Color(0.05, 0.035, 0.025, 1.0)
const TEXT_COLOR := Color(0.98, 0.93, 0.82, 1.0)
const TEXT_DISABLED_COLOR := Color(0.45, 0.42, 0.38, 1.0)
const INFO_PANEL_FALLBACK_COLOR := Color(0.025, 0.09, 0.07, 0.92)

static var _nine_slice_cache := {}
static var _three_slice_cache := {}


static func apply_ui_font_tree(node: Node) -> void:
	if not node:
		return

	if node is Control:
		apply_ui_font(node as Control)

	for child in node.get_children():
		apply_ui_font_tree(child)


static func apply_ui_font(control: Control) -> void:
	if not control:
		return

	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	control.add_theme_font_override("font", UI_FONT)
	control.add_theme_constant_override("outline_size", TEXT_OUTLINE_SIZE)
	control.add_theme_color_override("font_outline_color", TEXT_OUTLINE_COLOR)

	if control is Label:
		control.add_theme_color_override("font_color", TEXT_COLOR)

	if control is Button:
		control.add_theme_color_override("font_color", TEXT_COLOR)
		control.add_theme_color_override("font_hover_color", TEXT_COLOR)
		control.add_theme_color_override("font_pressed_color", TEXT_COLOR)
		control.add_theme_color_override("font_focus_color", TEXT_COLOR)
		control.add_theme_color_override("font_disabled_color", TEXT_DISABLED_COLOR)


static func apply_info_panel(control: Control) -> void:
	apply_ui_font(control)
	_apply_panel_skin(control, _make_nine_slice_style(ROW_INFO, PANEL_CONTENT_MARGIN))


static func apply_pass_button(button: Button) -> void:
	_apply_action_button(button, ROW_PASS_NORMAL, ROW_PASS_HOVER, ROW_PASS_PRESSED)


static func apply_tap_button(button: Button) -> void:
	_apply_action_button(button, ROW_TAP_NORMAL, ROW_TAP_HOVER, ROW_TAP_PRESSED)


static func apply_play_button(button: Button) -> void:
	_apply_action_button(button, ROW_PLAY_NORMAL, ROW_PLAY_HOVER, ROW_PLAY_PRESSED)


static func apply_utility_button(button: Button) -> void:
	if not button:
		return

	apply_ui_font(button)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_button_style(button, "normal", _make_utility_slice_style(0))
	_apply_button_style(button, "hover", _make_utility_slice_style(3))
	_apply_button_style(button, "pressed", _make_utility_slice_style(6))
	_apply_button_style(button, "disabled", _make_utility_slice_style(9))
	_apply_button_style(button, "focus", _make_utility_slice_style(3))


static func _apply_action_button(button: Button, normal_row: int, hover_row: int, pressed_row: int) -> void:
	if not button:
		return

	apply_ui_font(button)
	_apply_button_style(button, "normal", _make_nine_slice_style(normal_row, ACTION_CONTENT_MARGIN))
	_apply_button_style(button, "hover", _make_nine_slice_style(hover_row, ACTION_CONTENT_MARGIN))
	_apply_button_style(button, "pressed", _make_nine_slice_style(pressed_row, ACTION_CONTENT_MARGIN))
	_apply_button_style(button, "disabled", _make_nine_slice_style(normal_row, ACTION_CONTENT_MARGIN))
	_apply_button_style(button, "focus", _make_nine_slice_style(hover_row, ACTION_CONTENT_MARGIN))


static func _apply_button_style(button: Button, state: String, style: StyleBoxTexture) -> void:
	button.add_theme_stylebox_override(state, style)


static func _apply_panel_skin(control: Control, style: StyleBoxTexture) -> void:
	if not control:
		return

	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if control is Panel:
		(control as Panel).add_theme_stylebox_override("panel", style)
		return

	var skin := control.get_node_or_null("AtlasSkin") as InfoPanel
	if not skin:
		skin = InfoPanel.new()
		skin.name = "AtlasSkin"
		control.add_child(skin)
		control.move_child(skin, 0)

	skin.set_anchors_preset(Control.PRESET_FULL_RECT)
	skin.offset_left = 0.0
	skin.offset_top = 0.0
	skin.offset_right = 0.0
	skin.offset_bottom = 0.0
	skin.apply_info_skin()
	_raise_control_labels(control)

	if control is ColorRect:
		(control as ColorRect).color = INFO_PANEL_FALLBACK_COLOR


static func _raise_control_labels(control: Control) -> void:
	for child in control.get_children():
		if child is Label:
			var label := child as Label
			label.visible = true
			label.z_index = 1
			apply_ui_font(label)


static func _make_nine_slice_style(row: int, content_margin: float) -> StyleBoxTexture:
	if not _nine_slice_cache.has(row):
		var texture := ImageTexture.create_from_image(_make_nine_slice_image(row))
		_nine_slice_cache[row] = _make_stylebox(texture, CELL_SIZE, CELL_SIZE, CELL_SIZE, CELL_SIZE, content_margin)

	return (_nine_slice_cache[row] as StyleBoxTexture).duplicate()


static func _make_three_slice_style(left_column: int, middle_column: int, right_column: int) -> StyleBoxTexture:
	var key := "%d:%d:%d" % [left_column, middle_column, right_column]
	if not _three_slice_cache.has(key):
		var texture := ImageTexture.create_from_image(_make_three_slice_image(left_column, middle_column, right_column))
		_three_slice_cache[key] = _make_horizontal_stylebox(texture)

	return (_three_slice_cache[key] as StyleBoxTexture).duplicate()


static func _make_utility_slice_style(left_column: int) -> StyleBoxTexture:
	return _make_three_slice_style(left_column, left_column + 1, left_column + 2)


static func _make_horizontal_stylebox(texture: Texture2D) -> StyleBoxTexture:
	var style := _make_stylebox(texture, CELL_SIZE, 0, CELL_SIZE, 0, ACTION_CONTENT_MARGIN)
	style.region_rect = Rect2(Vector2.ZERO, Vector2(CELL_SIZE * 3, CELL_SIZE))
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return style


static func _make_stylebox(texture: Texture2D, left: int, top: int, right: int, bottom: int, content_margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = left
	style.texture_margin_top = top
	style.texture_margin_right = right
	style.texture_margin_bottom = bottom
	style.content_margin_left = content_margin
	style.content_margin_top = 0.0
	style.content_margin_right = content_margin
	style.content_margin_bottom = 0.0
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return style


static func _make_nine_slice_image(row: int) -> Image:
	var atlas_image := ATLAS.get_image()
	var image := Image.create(CELL_SIZE * 3, CELL_SIZE * 3, false, atlas_image.get_format())
	for index in range(9):
		var source := Rect2i(index * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		var destination := Vector2i((index % 3) * CELL_SIZE, int(index / 3) * CELL_SIZE)
		image.blit_rect(atlas_image, source, destination)

	return image


static func _make_three_slice_image(left_column: int, middle_column: int, right_column: int) -> Image:
	var atlas_image := ATLAS.get_image()
	var image := Image.create(CELL_SIZE * 3, CELL_SIZE, false, atlas_image.get_format())
	var columns := [left_column, middle_column, right_column]
	for index in range(columns.size()):
		var source := Rect2i(int(columns[index]) * CELL_SIZE, ROW_UTILITY * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		var destination := Vector2i(index * CELL_SIZE, 0)
		image.blit_rect(atlas_image, source, destination)

	return image
