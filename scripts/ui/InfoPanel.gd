extends NinePatchRect

const ATLAS := preload("res://assets/ui/panels/ui_panel_atlas_v01.png")
const CELL_SIZE := 32

static var _info_texture: Texture2D


func _ready() -> void:
	apply_info_skin()


func apply_info_skin() -> void:
	visible = true
	z_index = 0
	z_as_relative = true
	self_modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture = _get_info_texture()
	region_rect = Rect2(Vector2.ZERO, Vector2(CELL_SIZE * 3, CELL_SIZE * 3))
	patch_margin_left = CELL_SIZE
	patch_margin_top = CELL_SIZE
	patch_margin_right = CELL_SIZE
	patch_margin_bottom = CELL_SIZE
	draw_center = true


static func _get_info_texture() -> Texture2D:
	if not _info_texture:
		_info_texture = ImageTexture.create_from_image(_make_info_image())

	return _info_texture


static func _make_info_image() -> Image:
	var atlas_image := ATLAS.get_image()
	var image := Image.create(CELL_SIZE * 3, CELL_SIZE * 3, false, atlas_image.get_format())
	var row_regions := [
		Rect2i(0, 0, CELL_SIZE, CELL_SIZE),
		Rect2i(32, 0, CELL_SIZE, CELL_SIZE),
		Rect2i(64, 0, CELL_SIZE, CELL_SIZE),
		Rect2i(96, 0, CELL_SIZE, CELL_SIZE),
		Rect2i(128, 0, CELL_SIZE, CELL_SIZE),
		Rect2i(160, 0, CELL_SIZE, CELL_SIZE),
		Rect2i(192, 0, CELL_SIZE, CELL_SIZE),
		Rect2i(224, 0, CELL_SIZE, CELL_SIZE),
		Rect2i(256, 0, CELL_SIZE, CELL_SIZE),
	]
	for index in range(row_regions.size()):
		var source: Rect2i = row_regions[index]
		var destination := Vector2i((index % 3) * CELL_SIZE, int(index / 3) * CELL_SIZE)
		image.blit_rect(atlas_image, source, destination)

	return image
