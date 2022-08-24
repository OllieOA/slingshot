class_name Astronaut extends RigidBody2D

# Get nodes
onready var player_camera = $"%player_camera"
onready var aiming_arrow = $"%aiming_arrow"
onready var aiming_bar = $"%aiming_bar"
onready var jet_particles = $"%jet_particles"
onready var collision_probe = $"%collision_probe"

onready var middle_trajectory = $"%middle_trajectory"

enum State {AIMING, LAUNCHING, LAUNCHED, FLYING, LANDED, VIEWING_MAP}
var _state: int setget _set_state

# Launch variables
var _base_launch_power := 300.0
var _launch_angle_vector := Vector2.ZERO
var _launch_angle_rads := 0.0
var _launch_impulse := Vector2.ZERO
var _launch_line_delta := 0.2
var _trajectory_timer : Timer
var _trajectory_calc_time := 0.1


# Flight variables
var _jet_strength := 1.0
var _horizontal_flight_strength := 0.0
var _vertical_flight_strength := 0.0
var _jet_vector := Vector2.ZERO


func _ready() -> void:
	_trajectory_timer = Timer.new()
	_trajectory_timer.wait_time = _trajectory_calc_time
	_trajectory_timer.autostart = true
	add_child(_trajectory_timer)
	_trajectory_timer.connect("timeout", self, "_handle_trajectory_calc_timeout")
	_trajectory_timer.start()


	aiming_arrow.hide()
	aiming_bar.hide()
	_state = State.LANDED

	
func _physics_process(_delta: float) -> void:
	match _state:
		State.AIMING:
			# Let the player aim and view the map
			_handle_aiming()
		State.LAUNCHING:
			# Player is now trying to hit the "sweet spot"
			_handle_launching()
		State.LAUNCHED:
			# Transition to flying or grasping
			_set_state(State.FLYING)
		State.FLYING:
			# Fly through the air, add jetpack stabilisers
			_handle_jetpack()
		State.LANDED:
			# Transition to aiming
			aiming_arrow.show()
			_set_state(State.AIMING)
		State.VIEWING_MAP:
			pass

# STATE MACHINE LOGIC

func _handle_aiming() -> void:
	if Input.is_action_pressed("main_click"):
		# Get vector between character and mouse, and then make that the
		# heading of the aiming arrow
		_launch_angle_vector = global_position - get_global_mouse_position()
		_launch_angle_rads = _launch_angle_vector.angle()
		_launch_impulse = Vector2(_base_launch_power, 0).rotated(_launch_angle_rads)
		aiming_arrow.global_rotation = _launch_angle_rads

	if Input.is_action_just_released("main_click"):
		print(middle_trajectory.points)
	
	if Input.is_action_just_pressed("main_action"):
		aiming_arrow.hide()
		aiming_bar.show()
		_trajectory_timer.paused = true
		_set_state(State.LAUNCHING)


func _handle_launching() -> void:
	if Input.is_action_just_pressed("main_action"):
		middle_trajectory.set_as_toplevel(true)
		aiming_bar.hide()
		apply_central_impulse(_launch_impulse)


		_set_state(State.LAUNCHED)


func _handle_jetpack() -> void:
	_horizontal_flight_strength = Input.get_axis("jet_left", "jet_right")
	_vertical_flight_strength = Input.get_axis("jet_up", "jet_down")
	_jet_vector = Vector2(_horizontal_flight_strength, _vertical_flight_strength)
	apply_central_impulse(_jet_vector.normalized() * _jet_strength)

	jet_particles.process_material.direction = Vector3(-_jet_vector.x, -_jet_vector.y, 0)
	# Toggle particles
	if _jet_vector.length() > 0.1:
		if not jet_particles.emitting:
			jet_particles.emitting = true
	else:
		if jet_particles.emitting:
			jet_particles.emitting = false


# SETTERS AND GETTERS

func _set_state(new_state: int) -> void:
	_state = new_state


# SIGNAL CALLBACKS

func _handle_trajectory_calc_timeout() -> void:
	_update_trajectory(middle_trajectory, _launch_impulse)

# SPECIAL METHODS

# Trajectory calculation

func _update_trajectory(line_element: Line2D, initial_velocity: Vector2) -> void:
	var point_velocities := [initial_velocity]
	var line_points := [global_position + (initial_velocity * _launch_line_delta)]
	
	var single_point_velocity := Vector2.ZERO
	var single_force_and_collide := []

	for _i in range(10):
		single_force_and_collide = collision_probe.move_and_probe(line_points[-1])
		if not single_force_and_collide[1]:
			break

		single_point_velocity = point_velocities[-1] + single_force_and_collide[0] * _launch_line_delta
		point_velocities.append(single_point_velocity)

		line_points.append(line_points[-1] + (point_velocities[-1] * _launch_line_delta))

	line_element.points = line_points
