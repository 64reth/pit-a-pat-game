extends Node2D

signal hover_started(card: Node2D)
signal hover_ended(card: Node2D)
signal card_clicked(card: Node2D)
signal selected_started(card: Node2D)
signal selected_ended(card: Node2D)

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


func _ready() -> void:
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
