extends Node2D

var _astar: AStarGrid2D = AStarGrid2D.new()
@onready var _tilemap: TileMap = $TileMap

# Called when the node enters the scene tree for the first time.
func _ready():
	_astar.cell_size = _tilemap.get_tileset().tile_size
	_astar.size = _tilemap.get_used_rect().size
	print(_tilemap.get_used_rect().size)
	_astar.update()
	
	for tile_idx in _tilemap.get_used_cells(0):
		_astar.set_point_solid(tile_idx)
	
	var path = _astar.get_point_path(Vector2i(1, 1), Vector2i(1, 8))
	print(path)
	$Line2D.points = path


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	pass
