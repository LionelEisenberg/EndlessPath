class_name CyclingTechnique
extends Node2D

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var core_button: Button = $StartCyclingButton
@onready var auto_cycle_toggle: TextureButton = $AutoCycleToggle
@onready var path_2d: Path2D = $CyclingPath2D
@onready var path_follow_2d: PathFollow2D = %PathFollow2D
@onready var madra_ball: Area2D = %MadraBall
@onready var path_line: Line2D = $PathLine

#-----------------------------------------------------------------------------
# TWEEN FOR ANIMATION
#-----------------------------------------------------------------------------
var movement_tween: Tween

@export var technique_data_input: CyclingTechniqueData = null

#-----------------------------------------------------------------------------
# TECHNIQUE DATA
#-----------------------------------------------------------------------------
var technique_data: CyclingTechniqueData = null
var cycling_zones: Array[CyclingZone] = []
var zone_data: Array[CyclingZoneData] = []

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------
signal cycling_started
signal cycle_completed(madra_earned: float, mouse_accuracy: float)

#-----------------------------------------------------------------------------
# STATE TRACKING
#-----------------------------------------------------------------------------
enum CycleState { IDLE, CYCLING, COMPLETE }
var current_state: CycleState = CycleState.IDLE
var active_zone: CyclingZone = null

#-----------------------------------------------------------------------------
# MOUSE TRACKING
#-----------------------------------------------------------------------------
var last_mouse_position: Vector2
var mouse_tracking_accuracy: float = 0.0
var cycle_start_time: float = 0.0
var time_mouse_in_ball: float = 0.0  # Total time mouse was inside ball
var elapsed_cycle_time: float = 0.0  # Elapsed time during current cycle

#-----------------------------------------------------------------------------
# CLICK TIMING TRACKING
#-----------------------------------------------------------------------------
var click_timings: Array[Dictionary] = []  # Store timing data for each click

#-----------------------------------------------------------------------------
# PACKED SCENE REFERENCES
#-----------------------------------------------------------------------------
var cycling_zone_scene : PackedScene = preload("res://scenes/game_systems/cycling/cycling_technique/cycling_zone.tscn")
var floating_text_scene : PackedScene = preload("res://scenes/ui/floating_text/floating_text.tscn")

#-----------------------------------------------------------------------------
# INITIALIZATION
#-----------------------------------------------------------------------------

func _ready():
	# Connect core button to start cycling
	core_button.pressed.connect(_on_core_button_pressed)
	
	# Connect madra ball area signals
	madra_ball.area_entered.connect(_on_madra_ball_area_entered)
	madra_ball.area_exited.connect(_on_madra_ball_area_exited)
	
	# Connect input for clicking on zones
	# We'll handle this in _input() to detect clicks on any zone
	setup(technique_data_input)

## Initialize the technique with the provided data.
func setup(data: CyclingTechniqueData) -> void:
	technique_data = data
	
	# Apply the path curve
	if data.path_curve:
		path_2d.curve = data.path_curve
		_update_path_line()
	
	# Store zone data
	zone_data = data.cycling_zones
	
	# Create cycling zones dynamically based on the data
	_create_cycling_zones()
	
	# Initialize state
	current_state = CycleState.IDLE
	
	# Set Madra Ball Position
	path_follow_2d.progress_ratio = 0.0

## Set the current technique data and update display.
func set_technique_data(data: CyclingTechniqueData):
	setup(data)

## Update the Line2D to follow the Path2D curve.
func _update_path_line() -> void:
	if not path_2d.curve or not path_line:
		return
		
	# Clear existing points
	path_line.clear_points()
	
	# Sample points along the curve
	var curve_length = path_2d.curve.get_baked_length()
	var point_count = max(50, int(curve_length / 10))  # At least 50 points, or one per 10 units
	
	for i in range(point_count + 1):
		var ratio = float(i) / point_count
		var point = path_2d.curve.sample_baked(ratio * curve_length)
		path_line.add_point(point)
	
	# Set line properties for visual appeal
	path_line.width = 3.0
	path_line.default_color = Color(0.8, 0.8, 1.0, 0.7)  # Light blue with transparency

## Create cycling zones using the CyclingZone scene based on technique data.
func _create_cycling_zones() -> void:
	# Clear existing zones
	for zone in cycling_zones:
		if is_instance_valid(zone):
			zone.queue_free()
	cycling_zones.clear()
	
	# Check if the scene is loaded properly
	if not cycling_zone_scene:
		printerr("CyclingTechnique: cycling_zone_scene is null! Check the preload path.")
		return
	
	# Create zones for each zone data
	for i in range(zone_data.size()):
		var zone_data_item = zone_data[i]
		
		# Instantiate the CyclingZone scene
		var zone = cycling_zone_scene.instantiate()
		if not zone:
			printerr("CyclingTechnique: Failed to instantiate cycling zone scene!")
			continue
			
		# Cast to CyclingZone and verify
		var cycling_zone = zone as CyclingZone
		if not cycling_zone:
			printerr("CyclingTechnique: Instantiated object is not a CyclingZone! Check scene script.")
			zone.queue_free()
			continue
			
		cycling_zone.name = "CyclingZone" + str(i + 1)
		path_2d.add_child(cycling_zone)
		
		# Configure the zone with its data
		cycling_zone.setup(zone_data_item)
		
		# Position the zone at the exact coordinates
		cycling_zone.position = zone_data_item.position
		
		# Connect zone signals
		cycling_zone.zone_clicked.connect(_on_zone_clicked)
		
		# Store reference
		cycling_zones.append(cycling_zone)


#-----------------------------------------------------------------------------
# SIGNAL HANDLERS
#-----------------------------------------------------------------------------

func _on_core_button_pressed() -> void:
	_start_cycle()
	
## Start a new cycling cycle.
func _start_cycle() -> void:
	if current_state != CycleState.IDLE:
		return
		
	current_state = CycleState.CYCLING
	
	# Reset tracking variables for new cycle
	cycle_start_time = Time.get_ticks_msec() / 1000.0
	click_timings.clear()  # Clear previous cycle's timing data
	time_mouse_in_ball = 0.0  # Reset mouse tracking time
	elapsed_cycle_time = 0.0  # Reset elapsed cycle time
	
	# Show all zones and reset them for new cycle
	for zone in cycling_zones:
		zone.reset_for_new_cycle()
		zone.show_zone()
	
	# Reset ball position
	path_follow_2d.progress_ratio = 0.0
	
	# Emit cycling started signal
	cycling_started.emit()
	
	# Create and start the tween animation
	_start_cycling_animation()

## Create and start the cycling animation tween.
func _start_cycling_animation() -> void:
	if not technique_data:
		return
		
	# Clean up any existing tween
	if movement_tween:
		movement_tween.kill()
	
	# Create new tween for this cycle (now we're definitely in the scene tree)
	movement_tween = create_tween()
	movement_tween.tween_property(path_follow_2d, "progress_ratio", 1.0, technique_data.cycle_duration)
	movement_tween.finished.connect(_on_cycle_finished)

## Called when the ball completes one full cycle.
func _on_cycle_finished() -> void:
	current_state = CycleState.COMPLETE
	
	# Calculate final mouse tracking accuracy
	var final_mouse_accuracy = mouse_tracking_accuracy
	
	# Calculate madra earned: base_madra_per_cycle * mouse_tracking_accuracy (0.0 to 1.0)
	# This means perfect mouse tracking (1.0) gives 100% of base madra, poor tracking gives less
	var madra_earned = 0.0
	if technique_data:
		madra_earned = technique_data.base_madra_per_cycle * final_mouse_accuracy
		madra_earned = max(0.0, madra_earned)  # Ensure non-negative
		
		# Award madra to player
		if madra_earned > 0:
			ResourceManager.add_madra(madra_earned)
	
	# Emit cycle completed signal with madra earned and accuracy
	cycle_completed.emit(madra_earned, final_mouse_accuracy)
	
	# Hide all zones
	for zone in cycling_zones:
		zone.hide_zone()
	
	# Print cycle statistics
	_print_cycle_stats(madra_earned)
	
	current_state = CycleState.IDLE
	
	if auto_cycle_toggle.button_pressed:
		_start_cycle()


## Print comprehensive statistics for the completed cycle.
func _print_cycle_stats(madra_earned: float) -> void:
	var cycle_duration = technique_data.cycle_duration if technique_data else 0.0
	var cycle_end_time = Time.get_ticks_msec() / 1000.0
	var actual_duration = cycle_end_time - cycle_start_time
	
	# Count zones hit
	var zones_hit = 0
	var total_zones = cycling_zones.size()
	for zone in cycling_zones:
		if zone.is_used:
			zones_hit += 1
	
	# Calculate accuracy
	var accuracy_percentage = (float(zones_hit) / float(total_zones)) * 100.0 if total_zones > 0 else 0.0
	
	# Calculate average mouse tracking accuracy
	var avg_tracking_accuracy = mouse_tracking_accuracy * 100.0
	
	# Calculate timing statistics
	var total_timing_accuracy = 0.0
	var perfect_clicks = 0
	var good_clicks = 0
	var ok_clicks = 0
	
	for click_data in click_timings:
		total_timing_accuracy += click_data.timing_accuracy
		match click_data.timing_quality:
			"PERFECT":
				perfect_clicks += 1
			"GOOD":
				good_clicks += 1
			"OK":
				ok_clicks += 1
	
	var avg_timing_accuracy = total_timing_accuracy / click_timings.size() if click_timings.size() > 0 else 0.0
	
	print("=== CYCLE COMPLETE ===")
	print("Duration: %.2fs (Target: %.2fs)" % [actual_duration, cycle_duration])
	print("Madra Gained: %.2f (Mouse Accuracy: %.1f%%)" % [madra_earned, avg_tracking_accuracy])
	print("Zones Hit: %d/%d (%.1f%%)" % [zones_hit, total_zones, accuracy_percentage])
	print("Mouse Tracking Accuracy: %.1f%%" % avg_tracking_accuracy)
	print("Technique: %s" % (technique_data.technique_name if technique_data else "Unknown"))
	print("")
	print("--- CLICK TIMING BREAKDOWN ---")
	if click_timings.size() > 0:
		print("Average Timing Accuracy: %.1f%%" % avg_timing_accuracy)
		print("Perfect Clicks: %d" % perfect_clicks)
		print("Good Clicks: %d" % good_clicks)
		print("OK Clicks: %d" % ok_clicks)
		print("")
		print("Individual Click Details:")
		for i in range(click_timings.size()):
			var click = click_timings[i]
			print("  %d. %s: %.1f%% accuracy (%s) - %d XP" % [
				i + 1, 
				click.zone_name, 
				click.timing_accuracy, 
				click.timing_quality, 
				click.xp_reward
			])
	else:
		print("No successful clicks recorded")
	print("=============================")
	print("=====================")

## Called when the madra ball enters a cycling zone.
func _on_madra_ball_area_entered(area: Area2D) -> void:
	if area in cycling_zones and current_state == CycleState.CYCLING:
		active_zone = area as CyclingZone
		# Make the zone glow brighter
		_highlight_zone(active_zone, true)

## Called when the madra ball exits a cycling zone.
func _on_madra_ball_area_exited(area: Area2D) -> void:
	if area == active_zone:
		# Return zone to normal brightness
		_highlight_zone(active_zone, false)
		active_zone = null

## Handle clicking on a zone.
func _on_zone_clicked(zone: CyclingZone, zone_data_item: CyclingZoneData) -> void:
	if zone == active_zone and not zone.is_used and current_state == CycleState.CYCLING:
		_handle_zone_click(zone, zone_data_item)

#-----------------------------------------------------------------------------
# ZONE INTERACTION
#-----------------------------------------------------------------------------

## Process a successful zone click and award XP.
func _handle_zone_click(zone: CyclingZone, zone_data_item: CyclingZoneData) -> void:
	# Calculate timing accuracy based on ball position within the zone
	var ball_position = madra_ball.global_position
	var zone_center = zone.global_position
	var distance = ball_position.distance_to(zone_center)
	var zone_radius = zone.get_child(0).shape.radius
	
	# Calculate timing quality (0.0 = perfect center, 1.0 = edge)
	var timing_ratio = distance / zone_radius if zone_radius > 0 else 1.0
	timing_ratio = clamp(timing_ratio, 0.0, 1.0)
	
	# Calculate timing accuracy percentage (100% = perfect center)
	var timing_accuracy = (1.0 - timing_ratio) * 100.0
	
	# Determine timing quality
	var timing_quality: String
	var xp_reward: int
	var quality_color: Color
	if timing_ratio < 0.3:  # Perfect timing
		timing_quality = "PERFECT"
		xp_reward = zone_data_item.perfect_xp
		quality_color = Color.GOLD
		_flash_zone(zone, Color.GOLD)
	elif timing_ratio < 0.7:  # Good timing
		timing_quality = "GOOD"
		xp_reward = zone_data_item.good_xp
		quality_color = Color.GREEN
		_flash_zone(zone, Color.GREEN)
	else:  # OK timing
		timing_quality = "OK"
		xp_reward = zone_data_item.ok_xp
		quality_color = Color.WHITE
		_flash_zone(zone, Color.WHITE)
	
	# Show floating text at mouse position
	var mouse_pos = get_global_mouse_position()
	_spawn_floating_text(timing_quality + " +" + str(xp_reward) + " XP", quality_color, mouse_pos)
	
	# Record timing data for final stats
	click_timings.append({
		"zone_name": zone.name,
		"timing_accuracy": timing_accuracy,
		"timing_quality": timing_quality,
		"xp_reward": xp_reward,
		"distance_from_center": distance,
		"zone_radius": zone_radius
	})
	
	# Emit signal and mark zone as used
	CultivationManager.add_core_density_xp(xp_reward)
	zone.mark_as_used()

#-----------------------------------------------------------------------------
# VISUAL FEEDBACK
#-----------------------------------------------------------------------------

## Make a zone glow brighter or return to normal.
func _highlight_zone(zone: CyclingZone, highlight: bool) -> void:
	zone.set_active(highlight)

## Flash a zone with a specific color.
func _flash_zone(zone: CyclingZone, color: Color) -> void:
	zone.flash_zone(color)

## Spawn a floating text at the specified position.
func _spawn_floating_text(text: String, color: Color, text_position: Vector2) -> void:
	var floating_text = floating_text_scene.instantiate() as FloatingText
	if floating_text:
		get_tree().current_scene.add_child(floating_text)
		floating_text.show_text(text, color, text_position)

#-----------------------------------------------------------------------------
# MADRA GENERATION
#-----------------------------------------------------------------------------

## Track mouse accuracy during cycling (madra calculated at cycle end).
func _process(delta: float) -> void:
	if current_state != CycleState.CYCLING:
		return
		
	# Track elapsed cycle time
	elapsed_cycle_time += delta
		
	# Check if mouse is inside the MadraBall's area using point detection
	var mouse_inside_ball = is_mouse_in_madra_ball()
	
	# Track time mouse was inside ball
	if mouse_inside_ball:
		time_mouse_in_ball += delta
	
	# Calculate current mouse tracking accuracy (ratio of time inside ball, 0.0 to 1.0)
	if elapsed_cycle_time > 0.0:
		mouse_tracking_accuracy = time_mouse_in_ball / elapsed_cycle_time
	else:
		mouse_tracking_accuracy = 0.0

## Check if the mouse cursor is inside the MadraBall's collision shape.
func is_mouse_in_madra_ball() -> bool:
	if not madra_ball:
		return false
	
	# Get the collision shape from the MadraBall
	var collision_shape = madra_ball.get_node("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return false
	
	# Get mouse position and convert to MadraBall's local space
	var mouse_pos = get_global_mouse_position()
	var local_point = madra_ball.to_local(mouse_pos)
	
	# Calculate distance from shape center (accounting for collision shape position)
	var shape_relative = local_point - collision_shape.position
	
	# Check if mouse is within the circle radius
	var circle = collision_shape.shape as CircleShape2D
	return shape_relative.length() <= circle.radius
