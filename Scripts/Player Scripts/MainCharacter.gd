extends CharacterBody2D

# --- Basic vars ---
var speed: float = 85
var current_hp: float = 5
var max_hp: float = 5
var combo: float = 0
var attack_cd: bool = false
var weapon_damage: float = 1
var attack_dir := "front" 

# --- Healing vars ---
var heal_timer: float = 0
var heal_hold: bool = false
var vitality: float = 2
var heal_mode: bool = false
var heal_time: float = 3

# --- Invisibility vars ---
var is_invisible: bool = false
var invis_cd: bool = false

# --- Movement vars ---
var input_vector := Vector2.ZERO
@onready var sprite: AnimatedSprite2D = $CharacterSprite
var is_walking: bool = false
var walking_dir := "front"
var afterimage_frame_counter = 0

# --- Knockback ---
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 600.0
var is_knockback: bool = false
var immunity_frames: bool = false

# --- Power Hit ---
var power_hit_damage_multi: float = 10000
var hit_charged: bool = false
var hit_charging: bool = false
var hit_charge_timer: float = 0
var hit_charge_time: float = 1.5

func _ready():
	$AttackAnimation.visible = false
	$ColorRect.visible = false

# --- Main Loop ---
func _physics_process(delta):
	get_input()
	apply_knockback(delta)
	move_character(delta)
	update_animation()
	health_display_manage()
	heal(delta)
	invis()
	combo_manage()
	attack_manager()
	if combo >= 5:
		afterimage_frame_counter += 1
		if afterimage_frame_counter % 2 == 0:  # every 2nd physics frame
			spawn_afterimage()

	if not $AttackTimer.is_stopped():
		attack_location_manager()
	if hit_charged:
		weapon_damage * power_hit_damage_multi

# --- Input & Movement ---
func get_input():
	if is_knockback:
		return
	input_vector = Vector2.ZERO
	if Input.is_action_pressed("right"):
		input_vector.x += 1
	if Input.is_action_pressed("left"):
		input_vector.x -= 1
	if Input.is_action_pressed("up"):
		input_vector.y -= 1
	if Input.is_action_pressed("down"):
		input_vector.y += 1
	input_vector = input_vector.normalized()
	velocity = input_vector * speed

func move_character(delta):
	move_and_slide()
	is_walking = input_vector.length() > 0

func update_animation():
	if not is_knockback:
		if input_vector.x > 0:
			sprite.animation = "right"
			walking_dir = "right"
		elif input_vector.x < 0:
			sprite.animation = "left"
			walking_dir = "left"
		elif input_vector.y < 0 and input_vector.x == 0:
			sprite.animation = "back"
			walking_dir = "back"
		elif input_vector.y > 0 and input_vector.x == 0:
			sprite.animation = "front"
			walking_dir = "front"

		if input_vector == Vector2.ZERO:
			sprite.animation = walking_dir + "_idle"

	sprite.play()

# --- Knockback ---
func apply_knockback(delta):
	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	else:
		is_knockback = false

func take_damage(from_position: Vector2):
	current_hp -= 1
	$HitColourTimer.start()
	speed = 0
	$HitStunTimer.start()
	immunity_frames = false
	$ImmunityFrames.start()
	sprite.modulate = Color(1, 0.3, 0.3, 1)
	$PlayerDamageRecievedSoundEffect.play()
	combo = 0

	var dir = (global_position - from_position).normalized()
	knockback_velocity = dir * 150
	is_knockback = true

	if current_hp > max_hp:
		current_hp = max_hp
	if current_hp <= 0:
		die()

func _on_hit_colour_timer_timeout():
	sprite.modulate = Color(1, 1, 1, 1)

func die():
	get_tree().call_group("Enemies", "set_physics_process", false)
	get_tree().call_group("Enemies", "set_process", false)
	set_physics_process(false)
	set_process(false)

	velocity = Vector2.ZERO

	$PlayerDeathSoundEffect.play()
	sprite.animation = "death"
	sprite.play()

	is_knockback = true
	attack_cd = true
	is_invisible = true
	if walking_dir == "left":
		$MainCharacterAnimation.play("Player_Death_Left")
	elif walking_dir == "right":
		$MainCharacterAnimation.play("Player_Death_Right")
	else:
		$MainCharacterAnimation.play("Player_Death_Right")


	await get_tree().create_timer(3).timeout
	await wait_for_input()
	get_tree().reload_current_scene()

func wait_for_input():
	while true:
		await get_tree().process_frame
		if Input.is_anything_pressed():
			break

# --- Health ---
func health_display_manage():
	$HealthBar.text = str(current_hp) + "/" + str(max_hp)

# --- Healing ---
func heal(delta):
	if Input.is_action_just_pressed("heal") and combo>= 16:
		$HealSoundEffect.play()
	if Input.is_action_pressed("heal") and not heal_mode and combo >= 16 and current_hp < max_hp and not is_knockback:
		heal_timer += delta
		heal_hold = true
		speed = 0
		sprite.animation = walking_dir + "_idle"
		if heal_timer >= heal_time:
			heal_timer = 0
			combo -= 15
			current_hp += 2
			speed = 85
			heal_mode = false
			$HealTimer.start()
			$ChargeAttackSoundEffect.stop()
	if Input.is_action_just_released("heal"):
		heal_timer = 0
		heal_hold = false
		speed = 85
		$HealSoundEffect.stop()

func _on_heal_timer_timeout():
	heal_mode = false

# --- Invisibility ---
func invis():
	if Input.is_action_just_pressed("invis") and not invis_cd and not is_knockback and not is_invisible:
		if combo >= 11:
			combo -= 10
			speed = 190
			sprite.modulate.a = 0.5
			$InvisTimer.start()
			is_invisible = true
			$InvisSoundEffect.play()

func _on_invis_timer_timeout():
	sprite.modulate.a = 1.0
	speed = 85
	is_invisible = false
	$InvisCDTimer.start()
	invis_cd = true

func _on_invis_cd_timer_timeout():
	invis_cd = false

# --- Combo ---
func combo_manage():
	$ManaGauge.text = str(combo)
	$ComboTimer.start()
	if combo >= 5 and not $AudioStreamPlayer2D.playing and not $FlowStateActivated.playing:
		$FlowStateActivated.play()
		sprite.animation = "front_idle"
		Engine.time_scale = 0.5
		await get_tree().create_timer(1.325).timeout
		$AudioStreamPlayer2D.play()
		$FlowStateActivated.stop()
		speed = 115
		$ColorRect.visible = true
		Engine.time_scale = 1
	if combo >= 10:
		speed = 145
		$CharacterSprite.speed_scale = 1.5
	if combo <= 0 and $AudioStreamPlayer2D.playing:
		$AudioStreamPlayer2D.stop()
		speed = 85
		$ColorRect.visible = false

# --- Attack ---
func attack_manager():
	if Input.is_action_just_pressed("attack") and not attack_cd and not is_knockback:

		attack_cd = true
		$AttackTimer.start()
		$SwordSoundEffect.play   ()
		$AttackAnimation.visible = true
		$AttackAnimation.play()

		attack_dir = walking_dir
		attack_location_manager()

		for body in $AttackArea.get_overlapping_bodies():
			if body.is_in_group("Enemy") and body.has_method("take_damage"):
				body.take_damage(global_position)
				combo += 1


	if hit_charged:
		hit_charged = false

func _on_attack_timer_timeout():
	$AttackCooldown.start()
	$AttackAnimation.visible = false
	$AttackAnimation.stop()
	$AttackAnimation.frame = 0

func _on_attack_cooldown_timeout():
	attack_cd = false

func attack_location_manager():
	var offset := Vector2.ZERO
	var rotation_angle := 0.0
	match attack_dir:  
		"front":
			offset = Vector2(0, 8)
			rotation_angle = PI/2
		"back":
			offset = Vector2(0, -8)
			rotation_angle = -PI/2
		"left":
			offset = Vector2(-8, 0)
			rotation_angle = -PI
		"right":
			offset = Vector2(8, 0)
			rotation_angle = 0
	$AttackArea.position = sprite.position + offset
	$AttackArea.rotation = rotation_angle
	$AttackAnimation.position = $AttackArea.position
	$AttackAnimation.rotation = rotation_angle

func _on_attack_area_body_entered(body):
	if not $AttackTimer.is_stopped():
		if body.is_in_group("Enemy") and body.has_method("take_damage"):
			body.take_damage(global_position)
			combo += 1

func _on_hit_stun_timer_timeout():
	speed = 85

func _on_immunity_frames_timeout():
	immunity_frames = false

func power_hit(delta):
	if Input.is_action_pressed("charge_hit") and not is_knockback and not hit_charged:
		hit_charge_timer += delta
		hit_charging = true
		speed = 40
		if hit_charge_timer >= hit_charge_time:
			hit_charge_timer = 0
			hit_charged = true
			speed = 85
			hit_charging = false
	if Input.is_action_just_released("charge_hit"):
		hit_charge_timer = 0
		hit_charging = 0
		speed = 85
		if not hit_charged:
			$ChargeAttackSoundEffect.stop()

func _on_charge_attack_timeout():
	speed = 85

# --- Afterimage ---
func spawn_afterimage():
	var afterimage1 = $CharacterSprite.duplicate()

	get_parent().add_child(afterimage1)

	afterimage1.global_position = $CharacterSprite.global_position

	afterimage1.modulate = Color(1, 1, 1, 0.5)

	var fade_time = 0.3
	for t in range(1, 31):  # roughly 30 frames = 0.3 seconds at 60fps
		await get_tree().process_frame
		afterimage1.modulate.a = 0.5 * (1 - t / 30.0)

	afterimage1.queue_free()
