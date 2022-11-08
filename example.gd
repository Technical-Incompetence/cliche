extends Node2D


const MOTION_SPEED = 32 # Pixels/second.

@onready var _agent = $TileMap/CharacterBody2D/NavigationAgent2D
@onready var _player: CharacterBody2D = $TileMap/CharacterBody2D
@onready var _goal: Sprite2D = $Icon
@onready var _tilemap: TileMap = $TileMap

var _velocity = Vector2.ZERO

var _map: RID

func _ready() -> void:
	_agent.set_target_location(_goal.global_position)
	
	_map = NavigationServer2D.map_create()
	var region = NavigationServer2D.region_create()
	
	#for tile_idx in _tilemap.get_used_cells(0):
	var tile_data = _tilemap.get_cell_tile_data(0, Vector2i(0, 0))
	var final_poly = null
	var nav_poly_obj = tile_data.get_navigation_polygon(0)
	
	if nav_poly_obj == null:
		return

	var nav_poly = nav_poly_obj.get_outline(0)
	var transform: Vector2 = _tilemap.map_to_local(Vector2i(0, 0))
	nav_poly = Transform2D(0, transform) * nav_poly
	
	var above_data = _tilemap.get_cell_tile_data(1, Vector2i(0, 0) - Vector2i(0, 2))
	
	if above_data != null:
		var collider_poly = above_data.get_collision_polygon_points(0, 0)
		transform = _tilemap.map_to_local(Vector2i(0, -2))
		collider_poly = Transform2D(0, transform) * collider_poly
		final_poly = Geometry2D.clip_polygons(nav_poly, collider_poly)
		#final_poly = collider_poly
	else:
		final_poly = nav_poly

	print(nav_poly)
	print(final_poly)
	print()
	

	$Polygon2D.polygon = final_poly[0]
	
		
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if _agent.is_navigation_finished():
		return
	
	var direction = _player.global_position.direction_to(_agent.get_next_location())
	
	var desired_velocity = direction * 10
	var steering = (desired_velocity - _velocity) * delta * 4.0
	_velocity += steering
	
	_player.velocity = _velocity
	_player.move_and_slide()
	_velocity = _player.velocity


func _process(delta) -> void:
	$Line2D.points = _agent.get_nav_path()
