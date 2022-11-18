extends Node2D


const MOTION_SPEED = 32 # Pixels/second.

@onready var _agent: NavigationAgent2D = $TileMap/CharacterBody2D/NavigationAgent2D
@onready var _player: CharacterBody2D = $TileMap/CharacterBody2D
@onready var _goal: Sprite2D = $Icon
@onready var _tilemap: TileMap = $TileMap

var _velocity = Vector2.ZERO

var _map: RID

var moving: bool = false

var tile_to_region: Dictionary = {}

func _unhandled_input(event):
	if Input.is_action_just_pressed("ui_accept"):
		moving = true
	if event is InputEventMouseButton and event.pressed:
		# This makes it so that the clicks correspond to the top x pixels of a tile instead of the
		# middle x pixels of a tile
		var tile_height_offset = Transform2D(0, Vector2(0, -_tilemap.get_tileset().get_tile_size().y / 2))
		var local = get_local_mouse_position() * tile_height_offset
		var tile_pos = _tilemap.local_to_map(local)
		_tilemap.erase_cell(0, tile_pos)
		generate_nav_for_tile(0, tile_pos)
		print("GENERATED")
		NavigationServer2D.map_force_update(_map)


func get_or_create_region(layer_idx, tile_idx) -> RID:
	var key = "%d:%d:%d" % [layer_idx, tile_idx.x, tile_idx.y]
	if key in tile_to_region:
		return tile_to_region[key]
	else:
		var region: RID = NavigationServer2D.region_create()
		tile_to_region[key] = region
		return region


func generate_nav_for_tile(layer_idx, tile_idx):
	# Get the navigation polygon associated with our current tile
	var tile_data = _tilemap.get_cell_tile_data(layer_idx, tile_idx)
	if tile_data == null:
		return
	var final_poly = null
	var nav_poly_obj = tile_data.get_navigation_polygon(0)
	
	# Skip it if it doesnt' have a navigation mesh
	if nav_poly_obj == null:
		return

	# Transform the nav polygon to the local coordinates for the tilemap 
	var nav_poly = nav_poly_obj.get_outline(0)
	var nav_transform: Vector2 = _tilemap.map_to_local(tile_idx)
	nav_poly = Transform2D(0, nav_transform) * nav_poly
	final_poly = nav_poly
	
	# Get the cell "above" our current cell
	var above_idx = tile_idx - Vector2i(0, 2)
	var above_data = _tilemap.get_cell_tile_data(layer_idx + 1, above_idx)
	
	# If the cell above our present cell has collision data, get it and clip the nav polygon
	if above_data != null and above_data.get_collision_polygons_count(0) >= 1:
		# (Only handles the first collision polygon on collision layer 0)
		var collider_poly = above_data.get_collision_polygon_points(0, 0)
		nav_transform = _tilemap.map_to_local(above_idx)
		collider_poly = Transform2D(0, nav_transform) * collider_poly
		final_poly = Geometry2D.clip_polygons(nav_poly, collider_poly)[0]

	# Create a new region for this tile and add it to the NavigationServer
	var region: RID = get_or_create_region(layer_idx, tile_idx)
	NavigationServer2D.region_set_map(region, _map)
	var nav_polygon: NavigationPolygon = NavigationPolygon.new()
	nav_polygon.add_outline(final_poly)
	nav_polygon.make_polygons_from_outlines()
	nav_polygon.get_mesh().agent_radius = 16
	NavigationServer2D.region_set_navpoly(region, nav_polygon)
	NavigationServer2D.region_set_navigation_layers(region, layer_idx + 1)

#			var render_poly = Polygon2D.new()
#			render_poly.set_polygon(final_poly)
#			render_poly.z_index = 4
#			render_poly.color = Color(1, 1, 1, 0.5)
#			add_child(render_poly)
			#$Polygon2D.polygon = final_poly


func _ready() -> void:
	var score = 0

	_map = NavigationServer2D.map_create()
	NavigationServer2D.map_set_edge_connection_margin(_map, 0)
	_agent.set_navigation_map(_map)
	
	
	$HUD.update_score(score)
	$HUD.show_message("Get Ready")
	
	# Loop through each tile map layer
	for layer_idx in range(_tilemap.get_layers_count()):
		# Check each used cell in the map
		for tile_idx in _tilemap.get_used_cells(layer_idx):
			#print("Processing tile: ", layer_idx, " ", tile_idx)
			generate_nav_for_tile(layer_idx, tile_idx)
	
	NavigationServer2D.map_force_update(_map)
	print(_goal.global_position)
	_agent.set_target_location(_goal.global_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if NavigationServer2D.agent_is_map_changed(_agent.get_rid()):
		print("MAP CHANGED")
	if !moving or _agent.is_navigation_finished():
		var _blank = _agent.get_next_location()
		return
	
	var direction = _player.global_position.direction_to(_agent.get_next_location())
	
	var desired_velocity = direction * 10
	var steering = (desired_velocity - _velocity) * delta * 4.0
	_velocity += steering
	
	_player.velocity = _velocity
	_player.move_and_slide()
	_velocity = _player.velocity


func _process(_delta) -> void:
	$Line2D.points = _agent.get_nav_path()
