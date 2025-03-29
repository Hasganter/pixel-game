@tool
@icon('TileMapDual.svg')
class_name TileMapDual
extends TileMapLayer


var _tileset_watcher: TileSetWatcher
var _display: Display

func _ready() -> void:
	_tileset_watcher = TileSetWatcher.new(tile_set)
	_display = Display.new(self, _tileset_watcher)
	add_child(_display)
	_make_self_invisible()

	# --- Connect signal ONLY in the editor ---
	# The signal connection itself might be fine, but the function it calls is problematic.
	# We only need the auto-tiling logic in the editor anyway.
	if Engine.is_editor_hint():
		# Connect the signal only if in the editor
		if not _tileset_watcher.atlas_autotiled.is_connected(_atlas_autotiled):
			_tileset_watcher.atlas_autotiled.connect(_atlas_autotiled, CONNECT_ONE_SHOT) # CONNECT_ONE_SHOT might be safer if called multiple times
		set_process(true) # Keep editor processing
	else: # Run in-game using signals for better performance
		set_process(false)
		# Do NOT connect atlas_autotiled signal in game
		if not changed.is_connected(_changed):
			changed.connect(_changed, CONNECT_REFERENCE_COUNTED) # Use flag if needed for connect once

	# Update full tileset on first instance
	await get_tree().process_frame
	_changed()


## Automatically generate terrains when the atlas is initialized.
## This function should now ONLY be called when Engine.is_editor_hint() is true,
## because we only connect the signal in the editor context within _ready().
func _atlas_autotiled(source_id: int, atlas: TileSetAtlasSource):
	# --- Double Guard (optional but safe) ---
	# Although the signal connection should prevent this from running outside the editor,
	# an explicit check here adds robustness.
	if not Engine.is_editor_hint():
		push_warning("TileMapDual: _atlas_autotiled called unexpectedly outside editor.")
		return

	# Inside _atlas_autotiled, guarded by if Engine.is_editor_hint():
	var EdPlug = ClassDB.get("EditorPlugin") # Get class by string
	if EdPlug:
		var instance = EdPlug.new()
		if instance:
			var urm = instance.call("get_undo_redo") # Call method by string
			if urm:
			# Getting constants like MergeMode is harder...
			# Maybe access via get_constant_value on UndoRedo class?
				var merge_mode # = UndoRedo.get_constant_value("MergeMode", "MERGE_ALL") ? Check API
			# urm.call("create_action", "...", merge_mode, self, true)
			# ... etc ...


##[br] Makes the main world grid invisible.
##[br] The main tiles don't need to be seen. Only the DisplayLayers should be visible.
##[br] Called on ready.
func _make_self_invisible() -> void:
	if material != null:
		return
	material = CanvasItemMaterial.new()
	material.light_mode = CanvasItemMaterial.LightMode.LIGHT_MODE_LIGHT_ONLY	


## HACK: How long to wait before processing another "frame"
@export_range(0.0, 0.1) var refresh_time: float = 0.02
var _timer: float = 0.0
func _process(delta: float) -> void:
	if refresh_time < 0.0:
		return
	if _timer > 0:
		_timer -= delta
		return
	_timer = refresh_time
	call_deferred('_changed')


## Called by signals when the tileset changes,
## or by _process inside the editor.
func _changed() -> void:
	# Check if _tileset_watcher or tile_set could be null here if accessed very early
	if _tileset_watcher and is_instance_valid(tile_set):
		_tileset_watcher.update(tile_set)


## Called when the user draws on the map or presses undo/redo.
func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:
	# Assumes _display is valid
	if _display:
		_display.update(coords)


##[br] Public method to add and remove tiles.
##[br]
##[br] - 'cell' is a vector with the cell position.
##[br] - 'terrain' is which terrain type to draw.
##[br] - terrain -1 completely removes the tile,
##[br] - and by default, terrain 0 is the empty tile.
func draw_cell(cell: Vector2i, terrain: int = 1) -> void:
	# Assumes _display is valid
	if not _display: return
	var terrains := _display.terrain.terrains # Potential null ref if _display.terrain isn't ready?
	if terrain not in terrains:
		erase_cell(cell)
		# Consider emitting changed only if erase_cell actually did something
		changed.emit()
		return
	var tile_to_use: Dictionary = terrains[terrain]
	var sid: int = tile_to_use.sid
	var tile: Vector2i = tile_to_use.tile
	set_cell(cell, sid, tile)
	changed.emit()

## Public method to get the terrain at a specific coordinate.
func get_cell(cell: Vector2i) -> int:
	var data = get_cell_tile_data(cell)
	# Check if data is valid before accessing terrain
	if data:
		return data.terrain
	return -1 #! Or appropriate default for 'no terrain'
