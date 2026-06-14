@tool
extends Node2D

signal hover_started(card: Node2D)
signal hover_ended(card: Node2D)
signal card_clicked(card: Node2D)
signal selected_started(card: Node2D)
signal selected_ended(card: Node2D)

@export var rank: String = "A":
	set(value):
		rank = value
		_update_card_visual()
@export var suit: String = "HEART":
	set(value):
		suit = value
		_update_card_visual()
@export var rank_cell_size := Vector2(16, 16):
	set(value):
		rank_cell_size = value
		_update_card_visual()
@export var suit_cell_size := Vector2(16, 16):
	set(value):
		suit_cell_size = value
		_update_card_visual()
@export_file("*.png") var rank_atlas_path: String = "res://assets/cards/fronts/rank_atlas.png":
	set(value):
		rank_atlas_path = value
		_update_card_visual()
@export_file("*.png") var suit_atlas_path: String = "res://assets/cards/fronts/suit_atlas.png":
	set(value):
		suit_atlas_path = value
		_update_card_visual()
@export var hover_lift_pixels: float = 10.0
@export var selected_lift_pixels: float = 18.0
@export var hover_scale_multiplier: float = 1.06
@export var selected_scale_multiplier: float = 1.09
@export var hover_duration: float = 0.08
@export var hover_z_index_boost: int = 100
@export var selected_z_index_boost: int = 120
@export var shadow_idle_position := Vector2(4, 4)
@export var shadow_hover_position := Vector2(6, 6)
@export var shadow_idle_scale := Vector2.ONE
@export var shadow_hover_scale := Vector2(1.08, 1.08)
@export var shadow_idle_alpha: float = 0.25
@export var shadow_hover_alpha: float = 0.30
@export var pip_scale := Vector2.ONE:
	set(value):
		pip_scale = value
		_update_card_visual()
@export var pip_offset_adjustment := Vector2.ZERO:
	set(value):
		pip_offset_adjustment = value
		_update_card_visual()

var original_position: Vector2
var original_scale: Vector2
var original_rotation: float
var original_z_index: int
var original_shadow_color := Color.BLACK

var hand_focus_offset := Vector2.ZERO
var tween: Tween
var is_hovering := false
var is_selected := false
var is_hand_controlled := false

@onready var shadow: Sprite2D = $Shadow
@onready var rank_top: Sprite2D = $RankTop
@onready var rank_bottom: Sprite2D = $RankBottom
@onready var suit_sprites: Array[Sprite2D] = [$SuitTop, $SuitBottom]
@onready var pip_container: Node2D = $PipContainer

const RANK_ORDER := [
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

const SUPPORTED_SUIT_INDICES := {
	"HEART": 0,
	"DIAMOND": 1,
	"SPADE": 2,
	"CLUB": 3,
}

const PIP_LAYOUTS := {
	"A": [Vector2(0, 0)],
	"2": [Vector2(0, -22), Vector2(0, 22)],
	"3": [Vector2(0, -24), Vector2(0, 0), Vector2(0, 24)],
	"4": [Vector2(-12, -24), Vector2(12, -24), Vector2(-12, 24), Vector2(12, 24)],
	"5": [Vector2(-12, -26), Vector2(12, -26), Vector2(0, 0), Vector2(-12, 26), Vector2(12, 26)],
	"6": [Vector2(-12, -28), Vector2(12, -28), Vector2(-12, 0), Vector2(12, 0), Vector2(-12, 28), Vector2(12, 28)],
	"7": [Vector2(-12, -30), Vector2(12, -30), Vector2(0, -16), Vector2(-12, 4), Vector2(12, 4), Vector2(-12, 30), Vector2(12, 30)],
	"8": [Vector2(-12, -32), Vector2(12, -32), Vector2(0, -18), Vector2(-12, 2), Vector2(12, 2), Vector2(0, 18), Vector2(-12, 32), Vector2(12, 32)],
	"9": [Vector2(-12, -34), Vector2(12, -34), Vector2(-12, -18), Vector2(12, -18), Vector2(0, 0), Vector2(-12, 18), Vector2(12, 18), Vector2(-12, 34), Vector2(12, 34)],
	"10": [Vector2(-12, -36), Vector2(12, -36), Vector2(-12, -22), Vector2(12, -22), Vector2(0, -8), Vector2(0, 8), Vector2(-12, 22), Vector2(12, 22), Vector2(-12, 36), Vector2(12, 36)],
}


func _ready() -> void:
	_update_card_visual()

	if Engine.is_editor_hint():
		return

	original_position = position
	original_scale = scale
	original_rotation = rotation
	original_z_index = z_index
	original_shadow_color = shadow.modulate
	shadow.position = shadow_idle_position
	shadow.scale = shadow_idle_scale
	shadow.modulate = Color(0, 0, 0, shadow_idle_alpha)
	shadow.z_index = -1


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if is_hand_controlled:
		return

	set_hover_active(is_mouse_over_card())


func is_mouse_over_card() -> bool:
	return is_global_point_over_card(get_global_mouse_position())


func is_global_point_over_card(global_point: Vector2) -> bool:
	var local_mouse := to_local(global_point)
	var is_inside := Rect2(Vector2(-32, -48), Vector2(64, 96)).has_point(local_mouse)
	return is_inside


func set_hand_controlled(hand_controlled: bool) -> void:
	is_hand_controlled = hand_controlled


func set_hover_active(hovering: bool) -> void:
	if hovering == is_hovering:
		return

	is_hovering = hovering

	if is_hovering:
		hover_started.emit(self)
	else:
		hover_ended.emit(self)

	_tween_to_current_state()


func click() -> void:
	card_clicked.emit(self)


func set_selected_active(selected: bool) -> void:
	if selected == is_selected:
		return

	is_selected = selected

	if is_selected:
		selected_started.emit(self)
	else:
		selected_ended.emit(self)

	_tween_to_current_state()


func set_hand_focus_offset(offset: Vector2, duration: float = -1.0) -> void:
	hand_focus_offset = offset
	_tween_to_current_state(duration if duration >= 0.0 else hover_duration)


func _tween_to_current_state(duration: float = -1.0) -> void:
	if tween:
		tween.kill()

	if is_selected:
		z_index = original_z_index + selected_z_index_boost
	elif is_hovering:
		z_index = original_z_index + hover_z_index_boost
	else:
		z_index = original_z_index

	var target_position := original_position + hand_focus_offset
	var target_scale := original_scale
	var target_shadow_position := shadow_idle_position
	var target_shadow_scale := shadow_idle_scale
	var target_shadow_alpha := shadow_idle_alpha

	if is_selected:
		target_position += Vector2(0, -selected_lift_pixels)
		target_scale = original_scale * selected_scale_multiplier
		target_shadow_position = shadow_hover_position
		target_shadow_scale = shadow_hover_scale
		target_shadow_alpha = shadow_hover_alpha
	elif is_hovering:
		target_position += Vector2(0, -hover_lift_pixels)
		target_scale = original_scale * hover_scale_multiplier
		target_shadow_position = shadow_hover_position
		target_shadow_scale = shadow_hover_scale
		target_shadow_alpha = shadow_hover_alpha

	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_position, duration if duration >= 0.0 else hover_duration)
	tween.tween_property(self, "scale", target_scale, duration if duration >= 0.0 else hover_duration)
	tween.tween_property(shadow, "position", target_shadow_position, duration if duration >= 0.0 else hover_duration)
	tween.tween_property(shadow, "scale", target_shadow_scale, duration if duration >= 0.0 else hover_duration)
	tween.tween_property(shadow, "modulate:a", target_shadow_alpha, duration if duration >= 0.0 else hover_duration)


func _update_card_visual() -> void:
	if not is_inside_tree():
		return

	var normalized_rank := rank.strip_edges().to_upper()
	var normalized_suit := suit.strip_edges().to_upper()
	var rank_index := RANK_ORDER.find(normalized_rank)

	if rank_index == -1:
		normalized_rank = "A"
		rank_index = 0

	if not SUPPORTED_SUIT_INDICES.has(normalized_suit):
		normalized_suit = "HEART"

	var rank_texture := load(rank_atlas_path) as Texture2D
	var suit_texture := load(suit_atlas_path) as Texture2D
	var suit_region := _get_suit_region(normalized_suit)
	var suit_color := get_suit_color(normalized_suit)
	var rank_top_region := _get_rank_top_region(rank_index)
	var rank_bottom_region := _get_rank_bottom_region(rank_index)
	print("Rank:", normalized_rank, " Index:", rank_index, " Top:", rank_top_region, " Bottom:", rank_bottom_region)

	var top_sprite := _get_rank_top_sprite()
	if top_sprite:
		top_sprite.texture = _create_atlas_texture(rank_texture, rank_top_region)
		top_sprite.modulate = suit_color

	var bottom_sprite := _get_rank_bottom_sprite()
	if bottom_sprite:
		bottom_sprite.texture = _create_atlas_texture(rank_texture, rank_bottom_region)
		bottom_sprite.modulate = suit_color

	for suit_sprite in _get_suit_sprites():
		suit_sprite.texture = _create_atlas_texture(suit_texture, suit_region)
		suit_sprite.modulate = suit_color

	_generate_pips(normalized_rank, suit_texture, suit_region, suit_color)


func _get_rank_top_sprite() -> Sprite2D:
	if rank_top:
		return rank_top

	return get_node_or_null("RankTop") as Sprite2D


func _get_rank_bottom_sprite() -> Sprite2D:
	if rank_bottom:
		return rank_bottom

	return get_node_or_null("RankBottom") as Sprite2D


func _get_suit_sprites() -> Array[Sprite2D]:
	if suit_sprites.is_empty():
		return [
			get_node_or_null("SuitTop") as Sprite2D,
			get_node_or_null("SuitBottom") as Sprite2D,
		].filter(func(sprite: Sprite2D) -> bool: return sprite != null)

	return suit_sprites


func _get_rank_top_region(rank_index: int) -> Rect2:
	return Rect2(0, rank_index * rank_cell_size.y, rank_cell_size.x, rank_cell_size.y)


func _get_rank_bottom_region(rank_index: int) -> Rect2:
	return Rect2(rank_cell_size.x, rank_index * rank_cell_size.y, rank_cell_size.x, rank_cell_size.y)


func _get_suit_region(card_suit: String) -> Rect2:
	var suit_index: int = SUPPORTED_SUIT_INDICES[card_suit]
	return Rect2(Vector2(0, suit_index * suit_cell_size.y), suit_cell_size)


func get_suit_color(suit_name: String) -> Color:
	var normalized_suit := suit_name.strip_edges().to_upper()
	if normalized_suit == "SPADE" or normalized_suit == "CLUB":
		return Color.BLACK

	return Color(0.75, 0.20, 0.20)


func _generate_pips(card_rank: String, suit_texture: Texture2D, suit_region: Rect2, suit_color: Color) -> void:
	var container := _get_pip_container()
	if not container:
		return

	for child in container.get_children():
		child.free()

	var pip_positions: Array = PIP_LAYOUTS.get(card_rank, [Vector2(0, 0)])

	for index in range(pip_positions.size()):
		var pip := Sprite2D.new()
		pip.name = "Pip%d" % (index + 1)
		pip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pip.texture = _create_atlas_texture(suit_texture, suit_region)
		pip.position = pip_positions[index] + pip_offset_adjustment
		pip.scale = pip_scale
		pip.z_index = 1
		pip.z_as_relative = true
		pip.modulate = suit_color
		container.add_child(pip)


func _get_pip_container() -> Node2D:
	if pip_container:
		return pip_container

	return get_node_or_null("PipContainer") as Node2D


func _create_atlas_texture(source_texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = source_texture
	atlas_texture.region = region
	return atlas_texture
