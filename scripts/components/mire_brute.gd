extends Node3D
## Model presentation only. Movement and combat can drive the exported Lumber clip.

@export var vapor_enabled := true:
	set(value):
		vapor_enabled = value
		if is_node_ready():
			$ToxicVapor.emitting = value

func _ready() -> void:
	$ToxicVapor.emitting = vapor_enabled
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		for clip in player.get_animation_list():
			if clip.ends_with("Idle") or clip.ends_with("Lumber"):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			if clip.ends_with("Idle"):
				player.play(clip)
