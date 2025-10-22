extends CharacterBody2D

# --- Basic Vars --- 
var health: float = 3
var speed: float = 40

# --- Handlers ---
var mode := "idle"
var directionx := 0
var directiony := 0
var target = null

# --- Knockback Vars ---
var is_knockback: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 800.0
var immune: bool = false

# --- System Vars ---
@onready var main = get_node("../MainCharacter")
@onready var skeleton: AnimatedSprite2D = $SkeletonSprite
var starting_pos: Vector2 = Vector2.ZERO

func _ready():
	skeleton.play("idle")
	starting_pos = global_position

# --- Movement and Direction ---
func pursuit_start():
	mode = "pursuit"
	target = main

func pursuit_end():
	if mode == "pursuit":
		mode = "idle"
	target = null
	velocity = Vector2.ZERO

func _on_agro_range_body_exited(body):
	if body.is_in_group("Player"):
		pursuit_end()

func _on_agro_range_body_entered(body):
	if body.is_in_group("Player"):
		pursuit_start()

func pursuit_update():
	velocity = (target.global_position - global_position).normalized() * speed

	directionx = sign(velocity.x)
	directiony = sign(velocity.y)

	move_and_slide()

func idle_update():
	var dist = starting_pos.distance_to(global_position)
	if dist > 2: 
		velocity = (starting_pos - global_position).normalized() * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

	directionx = sign(velocity.x)
	directiony = sign(velocity.y)

# --- Animation ---
func animation_handler():
	if velocity == Vector2.ZERO or is_knockback:
		skeleton.play("idle")
		return

	if abs(directionx) > 0:
		if directionx == -1:
			skeleton.play("left")
		else:
			skeleton.play("right")
	elif directiony != 0:
		if directiony == -1:
			skeleton.play("front")
		else:
			skeleton.play("back")

# --- Deal and Receive Damage ---
func take_damage(from_position: Vector2):
	if not immune:
		if not main.hit_charged:
			health -= 1
		elif main.hit_charged:
			health = 0
		$DamageColourTimer.start()
		skeleton.modulate = Color(1, 0.5, 0.5, 1)
		$HitStunTimer.start()
		$ImmunityFrames.start()
		$"../MainCharacter/DamageDealtSoundEffect".play()

		# --- Apply knockback ---
		var dir = (global_position - from_position).normalized()
		knockback_velocity = dir * 300
		is_knockback = true
		immune = true

	if health <= 0:
		die()

func die():
	queue_free()

func _on_damage_colour_timer_timeout():
	skeleton.modulate = Color(1, 1, 1, 1)

func _physics_process(delta):
	if knockback_velocity.length() > 10:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
		speed = 0
		
	else:
		is_knockback = false

		if mode == "pursuit" and not main.is_invisible:
			pursuit_update()
		else:
			idle_update()

	animation_handler()


func _on_attack_area_body_entered(body):
	if body.is_in_group("Player"):
		body.take_damage(global_position)


func _on_hit_stun_timer_timeout():
	speed = 40

func _on_immunity_frames_timeout():
	immune = false

