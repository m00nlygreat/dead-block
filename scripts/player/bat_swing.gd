class_name BatSwing
extends Object

const CLIP_NAME := "attack-bat-swing"
const TRACKS := [
	"character-a/root/torso",
	"character-a/root/head",
	"character-a/root/torso/arm-right",
	"character-a/root/torso/arm-left",
]

const TORSO_KEYS := [
	[0.0, Vector3(0, 0, 0)],
	[0.16, Vector3(-0.12, -0.7, 0)],
	[0.3, Vector3(0.08, 0.95, 0.05)],
	[0.44, Vector3(0.0, 0.55, 0)],
	[0.6, Vector3(0, 0, 0)],
]
const HEAD_KEYS := [
	[0.0, Vector3(0, 0, 0)],
	[0.16, Vector3(0.05, 0.45, 0)],
	[0.3, Vector3(-0.05, -0.55, 0)],
	[0.6, Vector3(0, 0, 0)],
]
const ARM_R_KEYS := [
	[0.0, Vector3(0, 0, 0)],
	[0.16, Vector3(-2.6, 0.3, 0.5)],
	[0.28, Vector3(-1.35, 1.1, -0.25)],
	[0.4, Vector3(-1.75, 0.5, -0.45)],
	[0.6, Vector3(0, 0, 0)],
]
const ARM_L_KEYS := [
	[0.0, Vector3(0, 0, 0)],
	[0.16, Vector3(-2.2, -0.15, -0.75)],
	[0.3, Vector3(-1.5, -0.7, -0.5)],
	[0.44, Vector3(-1.7, -0.4, -0.6)],
	[0.6, Vector3(0, 0, 0)],
]


static func register(anim_player: AnimationPlayer) -> bool:
	if anim_player == null:
		return false
	var lib := anim_player.get_animation_library("")
	if lib == null or lib.has_animation(CLIP_NAME):
		return false
	var model_root: Node = anim_player.get_node_or_null(anim_player.root_node)
	if model_root == null:
		return false

	var a := Animation.new()
	a.length = 0.6
	for path in TRACKS:
		var n: Node = model_root.get_node_or_null(NodePath(path))
		if n == null or not n is Node3D:
			continue
		var rest: Quaternion = (n as Node3D).transform.basis.get_rotation_quaternion()
		var idx := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(idx, NodePath(path))
		a.track_set_interpolation_type(idx, Animation.INTERPOLATION_CUBIC)
		for k in _keys_for(path):
			var q: Quaternion = rest * Quaternion.from_euler(k[1])
			a.rotation_track_insert_key(idx, k[0], q)

	if a.get_track_count() == 0:
		return false
	lib.add_animation(CLIP_NAME, a)
	return true


static func _keys_for(path: String) -> Array:
	match path:
		"character-a/root/torso":
			return TORSO_KEYS
		"character-a/root/head":
			return HEAD_KEYS
		"character-a/root/torso/arm-right":
			return ARM_R_KEYS
		"character-a/root/torso/arm-left":
			return ARM_L_KEYS
	return []
