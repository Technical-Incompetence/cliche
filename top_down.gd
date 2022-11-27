extends Node2D

var _astar: AStarGrid2D = AStarGrid2D.new()
@onready var _tilemap: TileMap = $TileMap

var current_tile: Vector2i = Vector2i(8, 1)
var end_tile: Vector2i = Vector2i(1, 8)

@onready var _player = $Path2D/PathFollow2D/Player

# Called when the node enters the scene tree for the first time.
func _ready():
	_astar.cell_size = _tilemap.get_tileset().tile_size
	_astar.size = _tilemap.get_used_rect().size
	_astar.offset = _tilemap.get_tileset().tile_size / 2
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	
	for tile_idx in _tilemap.get_used_cells(0):
		var data: TileData = _tilemap.get_cell_tile_data(0, tile_idx)
		if data.get_custom_data("unwalkable"):
			_astar.set_point_solid(tile_idx)
	
	var path = _astar.get_point_path(current_tile, end_tile)
	print(path)
	$Line2D.points = path
	
	var offset = (_tilemap.get_tileset().tile_size / 2)
	_player.position = current_tile * _tilemap.get_tileset().tile_size + offset
	print("Player Position", " ", _player.global_position)
	
	set_player_path_curve()


func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		# This makes it so that the clicks correspond to the top x pixels of a tile instead of the
		# middle x pixels of a tile
		var local = get_local_mouse_position()
		var tile_pos = _tilemap.local_to_map(local)
		if _astar.is_in_bounds(tile_pos.x, tile_pos.y) and !_astar.is_point_solid(tile_pos):
			end_tile = tile_pos
			$Line2D.points = _astar.get_point_path(current_tile, end_tile)
			set_player_path_curve()


var need_to_reset_position = true

func set_player_path_curve():
	var path = $Path2D
	var curve = path.curve
	if !curve:
		path.curve = Curve2D.new()
	else:
		print("reuse old curve")
	path.curve.clear_points()
	path.curve.add_point(_player.global_position + Vector2(0, 8))
	for point in _astar.get_point_path(current_tile, end_tile):
		path.curve.add_point(Vector2(point))
	need_to_reset_position = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if need_to_reset_position:
		need_to_reset_position = false
		$Path2D/PathFollow2D.progress = 0
		_player.position = Vector2(0,0)
	
	current_tile = Vector2i(_player.global_position) / _tilemap.get_tileset().tile_size
	
	var local = get_local_mouse_position()
	var tile_pos = _tilemap.local_to_map(local)
	if _astar.is_in_bounds(tile_pos.x, tile_pos.y) and !_astar.is_point_solid(tile_pos):
		$TileSelectHighlight.position = tile_pos * _tilemap.get_tileset().tile_size
		$TileSelectHighlight.visible = true
	else:
		$TileSelectHighlight.visible = false

	$Path2D/PathFollow2D.progress = $Path2D/PathFollow2D.progress + 75 * delta
