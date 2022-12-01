extends Control

var _expanded = true

var _astar: AStarGrid2D = AStarGrid2D.new()

@onready var initial_tile: Vector2i = Vector2i(1, 3)
@onready var current_tile: Vector2i = initial_tile
@onready var end_tile: Vector2i = initial_tile

enum InputState {NoInput, FirstSelection, Confirmed}
var current_state: InputState = InputState.NoInput

enum GameState {Choosing, Running}
var _gamestate: GameState = GameState.Choosing
var _current_action = 0

@onready var _tilemap: TileMap = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/TileMap
@onready var _player = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/Path2D/PathFollow2D/Player
@onready var _tile_hover = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/TileHoverHighlight
@onready var _tile_select = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/TileSelectHighlight
@onready var _viewport = $HBoxContainer/LevelView/SubViewport
@onready var _camera = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/Path2D/PathFollow2D/Player/Camera2D
@onready var _hideshow: Button = $HBoxContainer/GamePlan/HideShow
@onready var _rungame: Button = $HBoxContainer/LevelView/SubViewport/CanvasLayer/RunGame
@onready var _retry: Button = $HBoxContainer/LevelView/SubViewport/CanvasLayer/Retry

var _actions: Array[Dictionary] = []
var _action_lines: Array[Line2D] = []
var _line_to_dim := -1
@onready var _action_ui: ItemList = $HBoxContainer/GamePlan/VBoxContainer/ItemList
var _valid_tiles: Dictionary = {}

var _scroll_locked = false

@onready var _extras := [
	{
		"kind": "finish",
		"pos": Vector2i(16, 3)
	},
	{
		"kind": "door",
		"pos": Vector2i(16, 6)
	},
	{
		"kind": "button",
		"pos": Vector2i(1, 9)
	}
]

# Called when the node enters the scene tree for the first time.
func _ready():
	$HBoxContainer/LevelView/SubViewport.size = $HBoxContainer/LevelView.get_rect().size
	_astar.cell_size = _tilemap.get_tileset().tile_size
	_astar.size = _tilemap.get_used_rect().size
	_astar.offset = _tilemap.get_tileset().tile_size / 2
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	
	var largest_x = 0
	var largest_y = 0
	var smallest_x = 0
	var smallest_y = 0
	
	# Go through map and set up walkable tiles as in astargrid
	for tile_idx in _tilemap.get_used_cells(0):
		if tile_idx.x > largest_x:
			largest_x = tile_idx.x
		if tile_idx.y > largest_y:
			largest_y = tile_idx.y
		if tile_idx.x < smallest_x:
			smallest_x = tile_idx.x
		if tile_idx.y < smallest_y:
			smallest_y = tile_idx.y
		_valid_tiles[tile_idx] = true
		var data: TileData = _tilemap.get_cell_tile_data(0, tile_idx)
		if data != null and data.get_custom_data("unwalkable"):
			_astar.set_point_solid(tile_idx)
	
	# Block path by doors
	for extra in _extras:
		if extra["kind"] == "door":
			var door = preload("res://door.tscn").instantiate()
			door.position = extra["pos"] * _tilemap.get_tileset().tile_size + Vector2i(_tilemap.get_tileset().tile_size.x/2, 0)
			_tilemap.add_child(door)
			extra["scene"] = door
			_astar.set_point_solid(extra["pos"])
		elif extra["kind"] == "finish":
			var finish = preload("res://Finish.tscn").instantiate()
			finish.position = extra["pos"] * _tilemap.get_tileset().tile_size
			_tilemap.add_child(finish)
			extra["scene"] = finish
		elif extra["kind"] == "button":
			var button = preload("res://button.tscn").instantiate()
			button.position = extra["pos"] * _tilemap.get_tileset().tile_size
			_tilemap.add_child(button)
			extra["scene"] = button
	
	# Set camera extents
	_camera.limit_right = (largest_x+1) * _tilemap.get_tileset().tile_size.x
	_camera.limit_bottom = (largest_y+1) * _tilemap.get_tileset().tile_size.y
	
	# Called every frame. 'delta' is the elapsed time since the previous frame.
	var offset = (_tilemap.get_tileset().tile_size / 2)
	_player.position = current_tile * _tilemap.get_tileset().tile_size + offset
	
	set_player_path_curve()
	
var need_to_reset_position = true

func set_player_path_curve():
	var path = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/Path2D
	var curve = path.curve
	if !curve:
		path.curve = Curve2D.new()
	path.curve.clear_points()
	path.curve.add_point(_player.global_position + Vector2(0, 8))
	for point in _astar.get_point_path(current_tile, end_tile):
		path.curve.add_point(Vector2(point))
	need_to_reset_position = true
	
	_camera.offset = Vector2(0, 0)
	

func set_player_path(the_start_tile, the_end_tile):
	var path = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/Path2D
	var curve = path.curve
	if !curve:
		path.curve = Curve2D.new()
	path.curve.clear_points()
	path.curve.add_point(_player.global_position + Vector2(0, 8))
	
	need_to_reset_position = true
	_camera.offset = Vector2(0, 0)
	
	if the_start_tile == the_end_tile:
		return
	
	for point in _astar.get_point_path(the_start_tile, the_end_tile):
		path.curve.add_point(Vector2(point))
	

func find_extra_of_kind(kind):
	for extra in _extras:
		if extra["kind"] == kind:
			return extra


func _input(_event):
	if Input.is_action_just_released("left_click"):
#		var level_node = $HBoxContainer/LevelView/SubViewport/LoadLevelHere.get_child(0)
#		level_node._unhandled_input(event)

		var local = _tilemap.get_local_mouse_position()
		var tile_pos = _tilemap.local_to_map(local)
		
		if !_astar.is_in_boundsv(tile_pos) or _astar.is_point_solid(tile_pos) or !_valid_tiles.has(tile_pos):
			return
		
		# If NoInput, this is suggesting the next point, move to selected
		# If Selected, show the tentative point until another click, then confirm
		if current_state == InputState.NoInput:
			var astar_path = _astar.get_point_path(current_tile, tile_pos)
				
			# Invalid path because of wall and such, move on with live
			if astar_path.is_empty():
				return
			end_tile = tile_pos
			current_state = InputState.FirstSelection
		elif current_state == InputState.FirstSelection:
			if end_tile == tile_pos:
				var astar_path = _astar.get_point_path(current_tile, end_tile)
				
				# Invalid path because of wall and such, move on with live
				if astar_path.is_empty():
					return
					
				_rungame.visible = true
				# Add new action to the list and add new line
				_actions.append({"type": "move", "start": current_tile, "end": end_tile})
				var line = Line2D.new()
				_tilemap.add_child(line)
				line.visible = true
				line.width = 4
				
				for point in astar_path:
					line.add_point(point)
				_action_lines.append(line)
				var _ignore = _action_ui.add_item("Move to " + str(end_tile))
				
				# If they clicked on a button, change the _astar map
				var button = find_extra_of_kind("button")
				if button["pos"] == tile_pos:
					var color = button["scene"].color
					# Hide the door
					var door = find_extra_of_kind("door")
					if door["scene"].color == color:
						door["scene"].visible = false
						_astar.set_point_solid(Vector2i(door["pos"]), false)
				
				# Dim previous line
				if len(_action_lines) >=2:
					_action_lines[-2].default_color = Color(_action_lines[-2].default_color, 0.35)
					_line_to_dim += 1
					_action_lines[_line_to_dim - 1]
				#set_player_path_curve()
				current_tile = end_tile
				end_tile = current_tile
				current_state = InputState.NoInput
			else:
				var astar_path = _astar.get_point_path(current_tile, tile_pos)
				
				# Invalid path because of wall and such, move on with live
				if astar_path.is_empty():
					return
				end_tile = tile_pos

		# This makes it so that the clicks correspond to the top x pixels of a tile instead of the
		# middle x pixels of a tile

		#$Line2D.points = _astar.get_point_path(current_tile, end_tile)
	if Input.is_action_just_pressed("ui_accept"):
		toggle_sidebar()


func start_move_pattern():
	_gamestate = GameState.Running
	_action_lines[-1].default_color = Color(_action_lines[-1].default_color, 0.35)
	_camera.offset = Vector2(0, 0)
	_rungame.disabled = true
	
	for extra in _extras:
		extra["scene"].visible = true
	
	var path_follow = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/Path2D/PathFollow2D
	
	var current_action = _actions[_current_action]
	#var current_line = _action_lines[_current_action]
	
	# Highlight current line
	_action_lines[_current_action].default_color = Color(_action_lines[_current_action - 1].default_color, 1.0)
			
	set_player_path(current_action["start"], current_action["end"])
	path_follow.progress = 1
	

func toggle_sidebar():
	var tween = create_tween()
	tween.set_parallel(false)
	if _expanded:
		# Shrink it
		_scroll_locked = true
		tween.tween_property($HBoxContainer/GamePlan, "size_flags_stretch_ratio", 0, 1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func(): _scroll_locked = false)
		_expanded = false
		_hideshow.text = "<"
	else:
		# Expand it
		_scroll_locked = true
		tween.tween_property($HBoxContainer/GamePlan, "size_flags_stretch_ratio", 1, 1).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(func(): _scroll_locked = false)
		_expanded = true
		_hideshow.text = ">"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var path_follow = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/Path2D/PathFollow2D
	
	if need_to_reset_position:
		need_to_reset_position = false
		path_follow.progress = 0
		_player.position = Vector2(0,0)
	
	#current_tile = Vector2i(_player.global_position) / _tilemap.get_tileset().tile_size
	
	var local = _tilemap.get_local_mouse_position()
	var tile_pos = _tilemap.local_to_map(local)
	
	# Update Tile hover polygon
	if _astar.is_in_bounds(tile_pos.x, tile_pos.y) and !_astar.is_point_solid(tile_pos) and _valid_tiles.has(tile_pos) and !_rungame.is_hovered() and _gamestate == GameState.Choosing:
		_tile_hover.position = tile_pos * _tilemap.get_tileset().tile_size
		_tile_hover.visible = true
	else:
		_tile_hover.visible = false
	
	# Update Tile selected polygon
	if current_state == InputState.NoInput:
		_tile_select.visible = false
	elif current_state == InputState.FirstSelection:
		_tile_select.position = end_tile * _tilemap.get_tileset().tile_size
		_tile_select.visible = true

	path_follow.progress = path_follow.progress + 75 * delta

	#	print(get_viewport().get_mouse_position())
#	print(_viewport.get_visible_rect())
	
	# Move camera in world
	var viewport_rect = _viewport.get_visible_rect()
	var window_mouse_pos = get_viewport().get_mouse_position()
	var camera_center = _camera.get_screen_center_position()
	
	# Get the canvas transform
	var ctrans = _viewport.get_canvas_transform()

	# The canvas transform applies to everything drawn,
	# so scrolling right offsets things to the left, hence the '-' to get the world position.
	# Same with zoom so we divide by the scale.
	var min_pos = -ctrans.get_origin() / ctrans.get_scale()

	# The maximum edge is obtained by adding the rectangle size.
	# Because it's a size it's only affected by zoom, so divide by scale too.
	var view_size = _camera.get_viewport().get_visible_rect().size / ctrans.get_scale()
	var max_pos = min_pos + view_size
	
	# If the mouse is at the extents of the screen, move the camera offset
	if viewport_rect.has_point(window_mouse_pos) and window_mouse_pos != Vector2(0, 0) and !_hideshow.is_hovered() and !_rungame.is_hovered() and !_scroll_locked and _gamestate == GameState.Choosing:
		var non_move_area = viewport_rect.grow(-85.0)
		if !non_move_area.has_point(window_mouse_pos):
			if window_mouse_pos.x < 100:
				if min_pos.x > _camera.limit_left:
					_camera.offset.x -= 4
			if viewport_rect.size.x - window_mouse_pos.x < 100:
				if max_pos.x < _camera.limit_right:
					_camera.offset.x += 4
			if window_mouse_pos.y < 100:
				if min_pos.y > _camera.limit_top:
					_camera.offset.y -= 4
			if viewport_rect.size.y - window_mouse_pos.y < 100:
				if max_pos.y < _camera.limit_bottom:
					_camera.offset.y += 4
	
	# Fixup camera offsets so that they never extend past the limits
	# (really should have written my own camera)
	if max_pos.x > _camera.limit_right:
		_camera.offset.x -= ceil(max_pos.x - _camera.limit_right)
	if max_pos.y > _camera.limit_bottom:
		_camera.offset.y -= ceil(max_pos.y - _camera.limit_bottom)
	if min_pos.y < _camera.limit_top:
		_camera.offset.y += ceil(_camera.limit_top - min_pos.y)
	if min_pos.x < _camera.limit_left:
		_camera.offset.x += ceil(_camera.limit_left - min_pos.x)
		
	var player_end_tile = Vector2i(_player.global_position) / _tilemap.get_tileset().tile_size

	if _gamestate == GameState.Running:
		$ActionMusic.volume_db = -10
		# Set up new path
		if path_follow.progress_ratio == 1:
			_current_action += 1
			
			# if we hit a button, remove that door
			var button = find_extra_of_kind("button")
			if button["pos"] == player_end_tile:
				var color = button["scene"].color
				# Hide the door
				var door = find_extra_of_kind("door")
				if door["scene"].color == color:
					door["scene"].visible = false
			
			# We are out of actions
			if len(_actions) <= _current_action:
				var finish = find_extra_of_kind("finish")
				if player_end_tile == finish["pos"]:
					get_tree().change_scene_to_file("res://Opening.tscn")
				else:
					$HBoxContainer/LevelView/SubViewport/CanvasLayer/Retry.visible = true
					pass
			else:
				var current_action = _actions[_current_action]
				var current_line = _action_lines[_current_action]
				# Dim out prev line if existss
				if _current_action > 0:
					_action_lines[_current_action - 1].default_color = Color(_action_lines[_current_action - 1].default_color, 0.35)
				
				# Highlight current line
				_action_lines[_current_action].default_color = Color(_action_lines[_current_action - 1].default_color, 1.0)
			
				set_player_path(current_action["start"], current_action["end"])
		else:
			# Walk the path
			path_follow.progress = path_follow.progress + 75 * delta


func _on_retry_pressed():
	# Reloading the scene causes a crash ;-;
	# So I'll do this jank instead
	_actions.clear()
	for line in _action_lines:
		line.queue_free()
	_action_lines.clear()
	_action_ui.clear()

	
	#set_player_path_curve()
	
	current_state = InputState.NoInput
	_gamestate = GameState.Choosing
	
	_rungame.disabled = false
	_rungame.visible = false
	_retry.visible = false
	
	current_tile = initial_tile
	end_tile = initial_tile
	
	var path = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/Path2D
	var curve = path.curve
	if curve:
		path.curve.clear_points()
		
	var path_follow = $HBoxContainer/LevelView/SubViewport/LoadLevelHere/Node2D/Path2D/PathFollow2D	
	path_follow.progress = 0
	_player.position = Vector2(0,0)
	
	var offset = (_tilemap.get_tileset().tile_size / 2)
	_player.global_position = current_tile * _tilemap.get_tileset().tile_size + offset
	print(_player.global_position)
	
	_current_action = 0
	_line_to_dim = -1
	
	for extra in _extras:
		extra["scene"].visible = true
		if extra["kind"] == "door":
			_astar.set_point_solid(extra["pos"])
