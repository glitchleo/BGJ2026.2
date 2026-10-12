extends Node2D

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var front_wall_layer: TileMapLayer = $FrontWallLayer

const NO_TILE := Vector2i(-1, -1)

enum CellType {
	EMPTY,
	FLOOR,
	DOOR,
	HOME_DOOR,
}

const FLOOR_SOURCE_ID := 0
const FLOOR_ATLAS_COORDS := Vector2i(1, 2)

const WALL_SOURCE_ID := 0

const WALL_TOP := Vector2i(1, 1)
const WALL_BOTTOM := Vector2i(1, 3)
const WALL_LEFT := Vector2i(0, 2)
const WALL_RIGHT := Vector2i(2, 2)

const WALL_TOP_EXTRA := Vector2i(1, 0)

const WALL_INNER_CORNER_TL := Vector2i(3, 1)
const WALL_INNER_CORNER_TR := Vector2i(4, 1)
const WALL_INNER_CORNER_BL := Vector2i(3, 2)
const WALL_INNER_CORNER_BR := Vector2i(4, 2)

const WALL_INNER_CORNER_TL_EXTRA := Vector2i(3, 0)
const WALL_INNER_CORNER_TR_EXTRA := Vector2i(4, 0)

const WALL_OUTER_CORNER_TL := Vector2i(0, 1)
const WALL_OUTER_CORNER_TR := Vector2i(2, 1)
const WALL_OUTER_CORNER_BL := Vector2i(0, 3)
const WALL_OUTER_CORNER_BR := Vector2i(2, 3)

const WALL_OUTER_CORNER_TL_EXTRA := Vector2i(0, 0)
const WALL_OUTER_CORNER_TR_EXTRA := Vector2i(2, 0)

const WALL_FILL := Vector2i(5, 0)

const FRONT_WALL_STRAIGHT := Vector2i(1, 4)
const FRONT_INNER_CORNER_BL := Vector2i(3, 3)
const FRONT_INNER_CORNER_BR := Vector2i(4, 3)
const FRONT_OUTER_CORNER_BL := Vector2i(0, 4)
const FRONT_OUTER_CORNER_BR := Vector2i(2, 4)

const DOOR_BOTTOM := Vector2i(6, 1)
const DOOR_TOP := Vector2i(6, 0)

const HOME_DOOR_BOTTOM := DOOR_BOTTOM
const HOME_DOOR_TOP := DOOR_TOP


func render(grid: Array[Array]) -> void:
	_clear_layers()
	render_floor(grid)
	render_walls(grid)
	render_doors(grid)


func _clear_layers() -> void:
	floor_layer.clear()
	wall_layer.clear()
	front_wall_layer.clear()


func render_floor(grid: Array[Array]) -> void:
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			if grid[y][x] == CellType.FLOOR:
				floor_layer.set_cell(
					Vector2i(x, y),
					FLOOR_SOURCE_ID,
					FLOOR_ATLAS_COORDS
				)


func render_walls(grid: Array[Array]) -> void:
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			if grid[y][x] != CellType.EMPTY:
				continue

			_render_wall_cell(grid, x, y)


func _render_wall_cell(grid: Array[Array], x: int, y: int) -> void:
	var floor_up := is_floor(grid, x, y - 1)
	var floor_down := is_floor(grid, x, y + 1)
	var floor_left := is_floor(grid, x - 1, y)
	var floor_right := is_floor(grid, x + 1, y)

	var floor_up_left := is_floor(grid, x - 1, y - 1)
	var floor_up_right := is_floor(grid, x + 1, y - 1)
	var floor_down_left := is_floor(grid, x - 1, y + 1)
	var floor_down_right := is_floor(grid, x + 1, y + 1)

	var is_boundary := (
		floor_up
		or floor_down
		or floor_left
		or floor_right
		or floor_up_left
		or floor_up_right
		or floor_down_left
		or floor_down_right
	)

	if not is_boundary:
		return

	var atlas_coords := WALL_FILL
	var extra_coords := NO_TILE
	var front_coords := NO_TILE

	if floor_down and floor_right:
		atlas_coords = WALL_INNER_CORNER_TL
		extra_coords = WALL_INNER_CORNER_TL_EXTRA
	elif floor_down and floor_left:
		atlas_coords = WALL_INNER_CORNER_TR
		extra_coords = WALL_INNER_CORNER_TR_EXTRA
	elif floor_up and floor_right:
		atlas_coords = WALL_INNER_CORNER_BL
		front_coords = FRONT_INNER_CORNER_BL
	elif floor_up and floor_left:
		atlas_coords = WALL_INNER_CORNER_BR
		front_coords = FRONT_INNER_CORNER_BR
	elif floor_down:
		atlas_coords = WALL_TOP
		extra_coords = WALL_TOP_EXTRA
	elif floor_up:
		atlas_coords = WALL_BOTTOM
		front_coords = FRONT_WALL_STRAIGHT
	elif floor_right:
		atlas_coords = WALL_LEFT
	elif floor_left:
		atlas_coords = WALL_RIGHT
	elif floor_down_right:
		atlas_coords = WALL_OUTER_CORNER_TL
		extra_coords = WALL_OUTER_CORNER_TL_EXTRA
	elif floor_down_left:
		atlas_coords = WALL_OUTER_CORNER_TR
		extra_coords = WALL_OUTER_CORNER_TR_EXTRA
	elif floor_up_right:
		atlas_coords = WALL_OUTER_CORNER_BL
		front_coords = FRONT_OUTER_CORNER_BL
	elif floor_up_left:
		atlas_coords = WALL_OUTER_CORNER_BR
		front_coords = FRONT_OUTER_CORNER_BR

	wall_layer.set_cell(Vector2i(x, y), WALL_SOURCE_ID, atlas_coords)

	if extra_coords != NO_TILE:
		wall_layer.set_cell(Vector2i(x, y - 1), WALL_SOURCE_ID, extra_coords)

	if front_coords != NO_TILE:
		front_wall_layer.set_cell(
			Vector2i(x, y),
			WALL_SOURCE_ID,
			front_coords
		)


func render_doors(grid: Array[Array]) -> void:
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var cell: int = grid[y][x]
			if cell == CellType.DOOR:
				_render_door_tile(Vector2i(x, y), DOOR_BOTTOM, DOOR_TOP)
			elif cell == CellType.HOME_DOOR:
				_render_door_tile(
					Vector2i(x, y),
					HOME_DOOR_BOTTOM,
					HOME_DOOR_TOP
				)


func _render_door_tile(
	cell: Vector2i,
	bottom_atlas: Vector2i,
	top_atlas: Vector2i
) -> void:
	wall_layer.set_cell(cell, WALL_SOURCE_ID, bottom_atlas)
	wall_layer.set_cell(
		Vector2i(cell.x, cell.y - 1),
		WALL_SOURCE_ID,
		top_atlas
	)


func is_floor(grid: Array[Array], x: int, y: int) -> bool:
	if y < 0 or y >= grid.size():
		return false
	if x < 0 or x >= grid[y].size():
		return false

	return grid[y][x] == CellType.FLOOR
