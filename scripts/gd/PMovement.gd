extends RigidBody2D

# Export variables for tuning in the editor
@export var speed: float = 250.0
@export var acceleration: float = 1500.0 # How quickly the player reaches max speed
@export var dash_speed_multiplier: float = 3.0
@export var dash_cooldown: float = 1.0
@export var friction_damping: float = 5.0 # Damping when stopping without dash
@export var dash_damping: float = 3.0 # Damping after dash (higher = faster slowdown)

# Internal state variables
var move_input: Vector2 = Vector2.ZERO
var last_non_zero_move_input: Vector2 = Vector2.RIGHT # Default facing direction
var facing_right: bool = true
var can_dash: bool = true
var is_dashing: bool = false # True during the high-speed phase of the dash
var is_playing_dash_anim: bool = false # True while the dash animation is playing

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_cooldown_timer = Timer.new()

func _ready() -> void:
	# Configure the timer
	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.ignore_time_scale = true
	# Connect signals
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timer_timeout)
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	# Add the timer to the scene tree
	add_child(dash_cooldown_timer)
	# Set initial physics properties
	linear_damp = 0 # Start with no damping
	# Ensure gravity doesn't interfere if this is top-down
	gravity_scale = 0

func _process(_delta: float) -> void:
	# --- Input Handling ---
	move_input = Input.get_vector("player-left", "player-right", "player-up", "player-down")

	# Update facing direction based on horizontal input
	if move_input.x != 0:
		facing_right = move_input.x > 0
		last_non_zero_move_input = move_input.normalized()
	elif move_input.y != 0: # Store vertical input if no horizontal input this frame
		last_non_zero_move_input = move_input.normalized()
	# If no input at all, last_non_zero_move_input retains its value

	# --- Dash Input ---
	if Input.is_action_just_pressed("player-dash") and can_dash:
		_start_dash()

func _physics_process(delta: float) -> void:
	# --- Movement ---
	if not is_dashing:
		var target_velocity = move_input * speed
		# Use move_toward for smoother acceleration/deceleration towards target speed
		linear_velocity = linear_velocity.move_toward(target_velocity, acceleration * delta)

	# --- Damping ---
	_update_damping()

	# --- Animation ---
	_update_animation()

func _start_dash() -> void:
	if not can_dash:
		return

	can_dash = false
	is_dashing = true
	is_playing_dash_anim = true
	dash_cooldown_timer.start()

	# Determine dash direction: Use last movement input, default to facing direction if idle
	var dash_direction = last_non_zero_move_input
	if dash_direction == Vector2.ZERO: # Should not happen with default, but safety check
		dash_direction = Vector2.RIGHT if facing_right else Vector2.LEFT

	# Apply dash impulse - adds velocity instantly
	# Calculate impulse strength based on reaching dash speed from current speed
	var dash_target_velocity = dash_direction * speed * dash_speed_multiplier
	var impulse = (dash_target_velocity - linear_velocity) * mass # Impulse = mass * delta_velocity
	apply_central_impulse(impulse)

	# Play dash animation (handled in _update_animation)

func _update_damping() -> void:
	var current_speed_sq = linear_velocity.length_squared()
	var normal_speed_sq = speed * speed

	if is_dashing:
		# Determine target speed after dash based on whether player is holding movement keys
		var target_speed_sq = normal_speed_sq if move_input != Vector2.ZERO else 0.0
		# Add a small buffer to avoid immediate state flip-flop
		var threshold_speed_sq = target_speed_sq * 1.1

		if current_speed_sq > threshold_speed_sq:
			# Apply high damping while speed is above the post-dash target
			linear_damp = dash_damping
		else:
			# Speed has returned to normal (or zero), dash velocity boost is over
			is_dashing = false
			# Reset damping, let normal logic take over
			linear_damp = 0

	else: # Not dashing
		if move_input == Vector2.ZERO and current_speed_sq > 1.0: # Use small threshold
			# Apply friction damping when player releases keys and is still moving
			linear_damp = friction_damping
		else:
			# No damping if actively moving or already stopped
			linear_damp = 0

func _update_animation() -> void:
	var current_animation = animated_sprite.animation
	var direction_suffix = "-right" if facing_right else "-left"

	var new_animation = ""

	if is_playing_dash_anim:
		new_animation = "dash" + direction_suffix
	elif move_input != Vector2.ZERO or linear_velocity.length_squared() > 1.0: # Moving or sliding
		# Check if sliding due to inertia even without input
		if not is_dashing: # Don't play move anim if still in dash boost phase (handled above)
			new_animation = "move" + direction_suffix
		else:
			# If somehow is_dashing but not is_playing_dash_anim, default to move
			new_animation = "move" + direction_suffix
	else: # Idle
		new_animation = "idle" + direction_suffix

	# Play the animation only if it's different from the current one
	if new_animation != "" and new_animation != current_animation:
		animated_sprite.play(new_animation)


func _on_dash_cooldown_timer_timeout() -> void:
	can_dash = true

func _on_animated_sprite_animation_finished() -> void:
	# Check if the animation that just finished was the dash animation
	if animated_sprite.animation.begins_with("dash"):
		is_playing_dash_anim = false
		# Update animation immediately to reflect current state (might be moving or idle)
		_update_animation()
