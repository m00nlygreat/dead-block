extends CharacterBody3D

signal hp_changed(hp: float, max_hp: float)
signal hunger_changed(hunger: float, max_hunger: float)
signal thirst_changed(thirst: float, max_thirst: float)
signal died

const BAT_MODEL := preload("res://scenes/items/bat_model.tscn")
const PICKUP_SCENE := preload("res://scenes/items/item_pickup.tscn")
const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.5
const ACCELERATION := 12.0
const DECELERATION := 16.0
const TURN_SPEED := 14.0
const BACKPEDAL_MULT := 0.65

const SPRINT_DRAIN := 22.0
const STAMINA_REGEN := 16.0
const REGEN_DELAY := 0.8

const HUNGER_DRAIN := 100.0 / 300.0
const THIRST_DRAIN := 100.0 / 210.0
const STARVE_TICK := 2.0
const STARVE_DAMAGE := 2.0
const STARVED_STAMINA_REGEN_MULT := 0.5
const CONSUME_SPEED_MULT := 0.45

const MELEE_DAMAGE := 25.0
const MELEE_COOLDOWN := 0.6
const MELEE_REACH := 1.8
const MELEE_ARC_DEG := 90.0
const MELEE_HIT_DELAY := 0.15
const BAT_HIT_DELAY := 0.3

const FIST_TRAIL_COLOR := Color(0.85, 0.85, 0.9)
const BAT_TRAIL_COLOR := Color(1.0, 0.55, 0.1)

@export var model_yaw_offset := PI
@export var max_hp := 100.0
@export var max_stamina := 100.0
@export var max_hunger := 100.0
@export var max_thirst := 100.0
@export var survival_drain_mult := 1.0

var hp := 100.0
var stamina := 100.0
var hunger := 100.0
var thirst := 100.0

var _anim: AnimationPlayer
var _current_anim := ""
var _search_target: Node = null
var _search_progress := 0.0
var _melee_cd := 0.0
var _invuln := 0.0
var _lock_anim_t := 0.0
var _regen_wait := 0.0
var _hand: Node3D = null
var _weapon_visual: Node3D = null
var _dead := false
var _starve_t := 0.0
var _consume_item: ItemData = null
var _consume_id := ""
var _consume_progress := 0.0

@onready var _model: Node3D = $Model
@onready var _interact_area: Area3D = $InteractArea
@onready var _swing_trail: SwingTrail = $SwingTrail


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	stamina = max_stamina
	hunger = max_hunger
	thirst = max_thirst
	_model.rotation.y = model_yaw_offset
	_ground_model.call_deferred()
	_anim = find_child("AnimationPlayer", true, false)
	if _anim == null:
		push_error("Player: AnimationPlayer not found")
		return
	for anim_name in ["idle", "walk", "sprint", "holding-right", "holding-both"]:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play("idle")
	BatSwing.register(_anim)
	_hand = _model.find_child("arm-right", true, false)
	InventoryManager.weapon_changed.connect(_refresh_weapon_visual)
	_refresh_weapon_visual()


const ACTIONS_TO_RELEASE := [
	"move_up", "move_down", "move_left", "move_right",
	"sprint", "interact", "attack", "aim", "inventory", "reload", "dodge",
]


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if DisplayServer.get_name() == "headless":
			return
		_release_all_actions()


func _release_all_actions() -> void:
	for a in ACTIONS_TO_RELEASE:
		Input.action_release(a)


func _refresh_weapon_visual() -> void:
	var item = InventoryManager.get_equipped_item()
	var want_bat: bool = item != null and item.is_weapon()
	if want_bat and _weapon_visual == null and _hand != null:
		_weapon_visual = BAT_MODEL.instantiate()
		_hand.add_child(_weapon_visual)
		_weapon_visual.position = Vector3(0.0, -0.8, -0.02)
		_weapon_visual.rotation_degrees = Vector3(80.0, 0.0, 0.0)
	elif not want_bat and _weapon_visual != null:
		_weapon_visual.queue_free()
		_weapon_visual = null


func _ground_model() -> void:
	if _model == null:
		return
	var inv: Transform3D = _model.global_transform.affine_inverse()
	var min_y := INF
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var ab: AABB = inv * (m.global_transform * m.mesh.get_aabb())
		min_y = minf(min_y, ab.position.y)
	if min_y < INF and absf(min_y) > 0.001:
		_model.position.y -= min_y


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input_dir.x, 0.0, input_dir.y)
	var moving := dir.length() > 0.1
	var eating := is_consuming()
	var want_sprint := Input.is_action_pressed("sprint") and moving and stamina > 0.0 and not eating
	if want_sprint:
		stamina = maxf(stamina - SPRINT_DRAIN * delta, 0.0)
		_regen_wait = REGEN_DELAY
	else:
		_regen_wait -= delta
		if _regen_wait <= 0.0:
			var regen := STAMINA_REGEN * (STARVED_STAMINA_REGEN_MULT if hunger <= 0.0 else 1.0)
			stamina = minf(stamina + regen * delta, max_stamina)
	var sprinting := want_sprint
	var aiming := Input.is_action_pressed("aim")

	var target_vel := dir * _move_speed(sprinting, dir)
	if eating:
		target_vel *= CONSUME_SPEED_MULT
	var rate := ACCELERATION if moving else DECELERATION
	velocity.x = move_toward(velocity.x, target_vel.x, rate * delta * WALK_SPEED * 2.0)
	velocity.z = move_toward(velocity.z, target_vel.z, rate * delta * WALK_SPEED * 2.0)

	move_and_slide()
	_update_facing(delta, aiming, moving)
	_update_animation(sprinting, aiming)
	_update_interaction(delta, moving)
	_update_combat(delta)
	_update_survival(delta)
	_update_consuming(delta)


func _move_speed(sprinting: bool, dir: Vector3) -> float:
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	if dir.length() < 0.1:
		return speed
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	if fwd.dot(dir.normalized()) < -0.35:
		speed *= BACKPEDAL_MULT
	return speed


func take_damage(amount: float) -> void:
	if _dead or _invuln > 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	_invuln = 0.45
	HitFlash.flash(self)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	velocity = Vector3.ZERO
	died.emit()
	if _anim != null and _anim.has_animation("die"):
		_current_anim = ""
		_play("die")


func is_dead() -> bool:
	return _dead


func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)


func get_selected_consumable() -> ItemData:
	var id := InventoryManager.get_selected_id()
	if id == "":
		return null
	var item = ItemDB.get_item(id)
	if item != null and item.is_consumable() and InventoryManager.count_of(id) > 0:
		return item
	return null


func is_consuming() -> bool:
	return _consume_item != null


func get_consume_ratio() -> float:
	if _consume_item == null:
		return 0.0
	return clampf(_consume_progress / maxf(_consume_item.consume_time, 0.01), 0.0, 1.0)


func get_consume_name() -> String:
	if _consume_item == null:
		return ""
	return _consume_item.display_name


func _try_start_consume() -> void:
	if _dead or is_consuming():
		return
	var item := get_selected_consumable()
	if item == null:
		return
	_consume_item = item
	_consume_id = InventoryManager.get_selected_id()
	_consume_progress = 0.0


func _cancel_consume() -> void:
	_consume_item = null
	_consume_id = ""


func _finish_consume() -> void:
	var item := _consume_item
	var id := _consume_id
	if item.hunger_restore > 0.0:
		hunger = minf(hunger + item.hunger_restore, max_hunger)
		hunger_changed.emit(hunger, max_hunger)
	if item.thirst_restore > 0.0:
		thirst = minf(thirst + item.thirst_restore, max_thirst)
		thirst_changed.emit(thirst, max_thirst)
	if item.heal_amount > 0.0:
		heal(item.heal_amount)
	InventoryManager.use_durability(id)
	_cancel_consume()


func _update_survival(delta: float) -> void:
	if _dead:
		return
	hunger = maxf(hunger - HUNGER_DRAIN * survival_drain_mult * delta, 0.0)
	thirst = maxf(thirst - THIRST_DRAIN * survival_drain_mult * delta, 0.0)
	if hunger <= 0.0 or thirst <= 0.0:
		_starve_t += delta
		while _starve_t >= STARVE_TICK and not _dead:
			_starve_t -= STARVE_TICK
			hp = maxf(hp - STARVE_DAMAGE, 0.0)
			hp_changed.emit(hp, max_hp)
			if hp <= 0.0:
				_die()
	else:
		_starve_t = 0.0


func _update_consuming(delta: float) -> void:
	if not is_consuming():
		if Input.is_action_just_pressed("interact") and get_interact_target() == null:
			_try_start_consume()
		return
	var valid := Input.is_action_pressed("interact") \
		and InventoryManager.get_selected_id() == _consume_id \
		and get_selected_consumable() != null
	if not valid:
		_cancel_consume()
		return
	_consume_progress += delta
	if _consume_progress >= _consume_item.consume_time:
		_finish_consume()


func is_searching() -> bool:
	return _search_target != null and Input.is_action_pressed("interact")


func get_search_ratio() -> float:
	if _search_target == null:
		return 0.0
	var st_v = _search_target.get("search_time")
	var st: float = st_v if st_v != null else 0.05
	return clampf(_search_progress / maxf(st, 0.01), 0.0, 1.0)


func _update_facing(delta: float, aiming: bool, moving: bool) -> void:
	var target_yaw := rotation.y

	if aiming:
		var aim_point = _get_aim_point()
		if aim_point != null:
			var d: Vector3 = aim_point - global_position
			d.y = 0.0
			if d.length() > 0.2:
				target_yaw = atan2(-d.x, -d.z)
	elif moving and Vector2(velocity.x, velocity.z).length() > 0.5:
		target_yaw = atan2(-velocity.x, -velocity.z)

	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-TURN_SPEED * delta))


func _get_aim_point():
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var normal := cam.project_ray_normal(mouse)
	return Plane(Vector3.UP, global_position.y).intersects_ray(origin, normal)


func _update_animation(sprinting: bool, aiming: bool) -> void:
	if _anim == null:
		return
	_lock_anim_t -= get_physics_process_delta_time()
	if _lock_anim_t > 0.0:
		return
	var has_weapon := InventoryManager.get_equipped_item() != null
	if aiming and velocity.length() > 0.6:
		_play("walk")
		_anim.speed_scale = 0.55
	elif velocity.length() > 0.6:
		_anim.speed_scale = 1.0
		_play("sprint" if sprinting else "walk")
	else:
		_anim.speed_scale = 1.0
		if is_consuming() or has_weapon:
			_play("holding-both")
		else:
			_play("holding-right" if aiming else "idle")


func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_8:
			InventoryManager.set_selected(k - KEY_1)
		elif k == KEY_Q:
			_drop_selected()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			InventoryManager.cycle_selected(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			InventoryManager.cycle_selected(1)


func _drop_selected() -> void:
	var data := InventoryManager.drop_selected_data()
	if data.is_empty():
		return
	var pk := PICKUP_SCENE.instantiate()
	pk.item_id = data["id"]
	pk.qty = 1
	pk.durability_left = int(data["durability"])
	get_parent().add_child(pk)
	var ang := randf() * TAU
	pk.global_position = global_position + Vector3(cos(ang) * 0.9, 0.0, sin(ang) * 0.9)


func _update_combat(delta: float) -> void:
	_melee_cd -= delta
	_invuln -= delta
	if _dead:
		return
	if Input.is_action_just_pressed("attack") and not is_searching() and not is_consuming() and _melee_cd <= 0.0:
		_melee_attack()


func _get_weapon_stats() -> Dictionary:
	var item = InventoryManager.get_equipped_item()
	if item != null and item.is_weapon():
		return {
			"damage": item.damage,
			"reach": item.reach,
			"arc": item.arc_deg,
			"targets": item.max_targets,
			"cooldown": item.attack_cooldown,
			"hit_delay": BAT_HIT_DELAY,
		}
	return {
		"damage": MELEE_DAMAGE,
		"reach": MELEE_REACH,
		"arc": MELEE_ARC_DEG,
		"targets": 1,
		"cooldown": MELEE_COOLDOWN,
		"hit_delay": MELEE_HIT_DELAY,
	}


func _melee_attack() -> void:
	var ws := _get_weapon_stats()
	_melee_cd = float(ws["cooldown"])
	var clip := "attack-melee-right"
	var item = InventoryManager.get_equipped_item()
	if item != null and item.is_weapon() and _anim.has_animation(BatSwing.CLIP_NAME):
		clip = BatSwing.CLIP_NAME
	_play_oneshot(clip)
	var trail_color := FIST_TRAIL_COLOR
	if item != null and item.is_weapon():
		trail_color = BAT_TRAIL_COLOR
	_swing_trail.play(float(ws["reach"]), float(ws["arc"]), trail_color)
	NoiseSystem.emit_noise(global_position, 5.0, 0)
	get_tree().create_timer(float(ws["hit_delay"])).timeout.connect(_melee_hit.bind(ws))


func _melee_hit(ws: Dictionary) -> void:
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var hits: Array = []
	for z in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(z):
			continue
		var to: Vector3 = z.global_position - global_position
		to.y = 0.0
		if to.length() > float(ws["reach"]):
			continue
		if rad_to_deg(fwd.angle_to(to.normalized())) > float(ws["arc"]) * 0.5:
			continue
		hits.append([to.length(), z])
	hits.sort_custom(func(a, b): return a[0] < b[0])
	var n: int = mini(int(ws["targets"]), hits.size())
	for i in n:
		hits[i][1].take_damage(float(ws["damage"]), global_position)
	if n > 0 and InventoryManager.get_equipped_item() != null:
		InventoryManager.weapon_used()


func _play_oneshot(name: String) -> void:
	if _anim == null or not _anim.has_animation(name):
		return
	_current_anim = name
	_lock_anim_t = _anim.get_animation(name).length
	_anim.play(name, 0.1)


func get_interact_target() -> Node:
	var candidates := []
	for b in _interact_area.get_overlapping_bodies():
		candidates.append(b)
	for a in _interact_area.get_overlapping_areas():
		candidates.append(a)

	var best: Node = null
	var best_key := Vector2(INF, INF)
	for obj in candidates:
		if obj == null or not obj.has_method("can_interact"):
			continue
		if not obj.can_interact():
			continue
		var prio := 0
		if obj.has_method("interact_priority"):
			prio = obj.interact_priority()
		var d: float = global_position.distance_to(obj.global_position)
		var key := Vector2(float(-prio), d)
		if key < best_key:
			best_key = key
			best = obj
	return best


func _update_interaction(delta: float, moving: bool) -> void:
	var target := get_interact_target()

	if moving or is_consuming() or not Input.is_action_pressed("interact") or target == null:
		_search_progress = 0.0
		_search_target = null
		return

	if _search_target != target:
		_search_target = target
		_search_progress = 0.0

	var st_v = target.get("search_time")
	var duration: float = maxf(st_v if st_v != null else 0.05, 0.01)

	_search_progress += delta
	if _search_progress >= duration:
		target.complete_interaction(self)
		_search_target = null
		_search_progress = 0.0


func _play(anim_name: String) -> void:
	if _current_anim == anim_name or _anim == null or not _anim.has_animation(anim_name):
		return
	_current_anim = anim_name
	_anim.play(anim_name, 0.15)


func on_noise(_position: Vector3, _priority: int) -> void:
	pass
