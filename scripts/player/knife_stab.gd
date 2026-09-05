class_name KnifeStab
extends Object

const CLIP_NAME := "attack-knife-stab"
const TRACKS := [
	"character-a/root/hip/torso",
	"character-a/root/hip/torso/neck/head",
	"character-a/root/hip/torso/arm-right",
	"character-a/root/hip/torso/arm-left",
]

const TORSO_KEYS := [
	[0.0, Vector3(0, 0, 0)],
	[0.06, Vector3(0, -0.4, 0)],
	[0.14, Vector3(0, 0.5, 0.03)],
	[0.22, Vector3(0, 0.35, 0)],
	[0.32, Vector3(0, 0, 0)],
]
const HEAD_KEYS := [
	[0.0, Vector3(0, 0, 0)],
	[0.06, Vector3(0, 0.25, 0)],
	[0.14, Vector3(0, -0.3, 0)],
	[0.32, Vector3(0, 0, 0)],
]
const ARM_R_KEYS := [
	[0.0, Vector3(0, 0, 0)],
	[0.06, Vector3(-2.3, -0.55, 0.35)],
	[0.14, Vector3(-1.3, 1.15, -0.2)],
	[0.22, Vector3(-1.45, 0.95, -0.15)],
	[0.32, Vector3(0, 0, 0)],
]
const ARM_L_KEYS := [
	[0.0, Vector3(0, 0, 0)],
	[0.06, Vector3(-0.5, -0.2, -0.3)],
	[0.14, Vector3(-0.7, 0.3, -0.4)],
	[0.32, Vector3(0, 0, 0)],
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
	a.length = 0.32
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
		"character-a/root/hip/torso":
			return TORSO_KEYS
		"character-a/root/hip/torso/neck/head":
			return HEAD_KEYS
		"character-a/root/hip/torso/arm-right":
			return ARM_R_KEYS
		"character-a/root/hip/torso/arm-left":
			return ARM_L_KEYS
	return []
