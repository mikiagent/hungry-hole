class_name CityGenerator
extends Node3D
## Builds a city on a 5 m grid: roads, sidewalks, blocks with stacked buildings, props, cars, people.
## Targets from 03-systems/maps-and-city.md: footprint ~250x300 m, ~2,500 objects, mostly size 1.
const TILE := 5.0
@export var tiles_x: int = 140
@export var tiles_z: int = 152
@export var block_tiles: int = 6      # block size incl. 2-tile road
@export var seed_value: int = 0
@export var tiers: ObjectPhysicsTiers

const PAL := {
	"grass": Color("8BD450"), "grass2": Color("6DBF3C"), "road": Color("5C5F73"), "line": Color("F2F2E6"), "sidewalk": Color("D9D2C5"), "path": Color("C9A66B"),
	"b_coral": Color("FF6B6B"), "b_coral2": Color("E04F4F"), "b_sun": Color("FFD93D"), "b_sun2": Color("E6B800"), "b_mint": Color("6BCB77"), "b_mint2": Color("4DA85A"),
	"b_sky": Color("4D96FF"), "b_sky2": Color("2F6FD6"), "b_grape": Color("B06BFF"), "b_grape2": Color("8A4DE6"), "roof": Color("FFFFFF"), "dark": Color("3A3A4A"),
	"wood": Color("C98A4B"), "metal": Color("B0BEC5"), "leaf": Color("58B04A"), "trunk": Color("8D6E63"), "cone": Color("FF8F3A"), "bin": Color("607D8B"),
	"flower1": Color("FF5CA8"), "flower2": Color("FFB347"), "flower3": Color("7AD7F0"), "taxi": Color("FFD23F"), "car_red": Color("FF4F5E"), "car_blue": Color("3F8CFF"),
	"truck": Color("8BC34A"), "tire": Color("2B2B2B"), "skin": Color("F2C8A0"), "skin2": Color("C68B59"), "skin3": Color("8D5A3A"), "window": Color("FFF4C2"),
}
var _mats := {}
var _meshes := {}
var _rng := RandomNumberGenerator.new()
var _balance := BalanceTable.new()
var ground_mat: ShaderMaterial
var _cut_mats: Array[ShaderMaterial] = []
var bounds: Rect2          # current playable area (grows with zones)
var map_rect: Rect2        # the whole map; tiles are laid out on this
var spawn_groups: Array = []
var object_count := 0
var total_points := 0
var _tile_kind := {}   # Vector2i -> "road"|"side"|"block"|"park"
## Zones: rings by normalized distance from the centre. Only unlocked rings have objects; the next ring spawns
## in once UNLOCK_FRACTION of everything spawned so far has been eaten (user: larger map, zones that spawn in).
const ZONE_EDGES := [0.4, 0.7, 1.0]
const UNLOCK_FRACTION := 0.3
const TILES_PER_FRAME := 220
const WEB_PROP_KEEP := 0.5   # share of small-prop tiles kept on the web
signal zone_unlocked(index: int, rect: Rect2)
var zone_index := 0
var eaten_count := 0
var spawned_count := 0
var _pending: Array = []
var _walls: StaticBody3D
var _barrier: Array[MeshInstance3D] = []
## Tripo-generated GLBs (normalized to ~1 unit). scale = world size of the longest axis class.
const MODELS := {
	"apartment": {"path": "res://assets/tripo/apartment_v3.glb", "scale": 12.0, "size": 7, "pts": 7, "type": 3},
	"skyscraper": {"path": "res://assets/tripo/skyscraper_v3.glb", "scale": 26.0, "size": 10, "pts": 10, "type": 3},
	"apartment_tall": {"path": "res://assets/tripo/apartment_v3.glb", "scale": 18.0, "size": 9, "pts": 10, "type": 3},
	"skyscraper_tall": {"path": "res://assets/tripo/skyscraper_v3.glb", "scale": 42.0, "size": 13, "pts": 16, "type": 3},
	"tower_mega": {"path": "res://assets/tripo/skyscraper_v3.glb", "scale": 64.0, "size": 16, "pts": 25, "type": 3},
	"house": {"path": "res://assets/tripo/house.glb", "scale": 8.0, "size": 7, "pts": 7, "type": 3},
	"cone": {"path": "res://assets/tripo/cone.glb", "scale": 0.75, "size": 1, "pts": 1, "type": 0},
	"bin": {"path": "res://assets/tripo/bin.glb", "scale": 1.0, "size": 1, "pts": 1, "type": 0},
	"hydrant": {"path": "res://assets/tripo/hydrant.glb", "scale": 0.8, "size": 1, "pts": 1, "type": 0},
	"bush": {"path": "res://assets/tripo/bush.glb", "scale": 1.5, "size": 2, "pts": 2, "type": 0},
	"planter": {"path": "res://assets/tripo/planter.glb", "scale": 1.1, "size": 1, "pts": 1, "type": 0},
	"cardbox": {"path": "res://assets/tripo/cardbox.glb", "scale": 0.6, "size": 1, "pts": 1, "type": 0},
	"dumpster": {"path": "res://assets/tripo/dumpster.glb", "scale": 2.0, "size": 2, "pts": 2, "type": 0},
	"mailbox": {"path": "res://assets/tripo/mailbox.glb", "scale": 1.1, "size": 1, "pts": 1, "type": 0},
	"tree": {"path": "res://assets/tripo/tree_v3.glb", "scale": 3.2, "size": 2, "pts": 2, "type": 0},
	"tree_small": {"path": "res://assets/tripo/tree_v3.glb", "scale": 2.0, "size": 1, "pts": 1, "type": 0},
	"lamp": {"path": "res://assets/tripo/lamp_v2.glb", "scale": 3.4, "size": 1, "pts": 1, "type": 0},
	"bench": {"path": "res://assets/tripo/bench_v2.glb", "scale": 1.9, "size": 1, "pts": 1, "type": 0},
	"person": {"path": "res://assets/tripo/person_v3.glb", "scale": 1.4, "size": 1, "pts": 1, "type": 1},
	"taxi": {"path": "res://assets/tripo/car_taxi.glb", "scale": 4.2, "size": 2, "pts": 2, "type": 2, "yaw": -PI / 2},
	"car": {"path": "res://assets/tripo/car_red.glb", "scale": 4.2, "size": 2, "pts": 2, "type": 2, "yaw": -PI / 2},
}
var _scenes := {}
var _aabbs := {}

func _scene(key: String) -> PackedScene:
	if not _scenes.has(key):
		var ps = load(MODELS[key]["path"])
		_scenes[key] = ps
		var inst: Node3D = ps.instantiate()
		var aabb := AABB(); var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as Node3D).transform * (mi as MeshInstance3D).mesh.get_aabb()
			aabb = b if first else aabb.merge(b); first = false
		_aabbs[key] = aabb
		inst.free()
	return _scenes[key]

func _prop_model(key: String, pos: Vector3, yaw := 0.0) -> FallingObject:
	var m: Dictionary = MODELS[key]
	var ps := _scene(key)
	var aabb: AABB = _aabbs[key]
	var s: float = m["scale"]
	var h: float = aabb.size.y * s
	var fo := _new_object(key, pos + Vector3(0, h / 2, 0), _fit_level(Vector2(aabb.size.x, aabb.size.z) * s * 0.9), m["pts"], m["type"], h)
	fo.footprint_half = maxf(aabb.size.x, aabb.size.z) * s * 0.45
	fo.rotation.y = yaw + float(m.get("yaw", 0.0))
	var inst: Node3D = ps.instantiate()
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s - h / 2, -aabb.get_center().z * s)
	fo.add_child(inst)
	_apply_visibility(inst, h)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = aabb.size * s * Vector3(0.9, 1.0, 0.9); cs.shape = bs; fo.add_child(cs)
	return fo

## Distance culling by object height, the Godot stand-in for the original's LODMeshSwitcher/LODManager.
static func _apply_visibility(root: Node, height: float) -> void:
	var end := clampf(60.0 + height * 18.0, 70.0, 600.0)
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		g.visibility_range_end = end
		g.visibility_range_end_margin = end * 0.1
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if height < 1.5: g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func mat(key: String) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = PAL[key]
		m.roughness = 1.0
		m.metallic = 0.0
		_mats[key] = m
	return _mats[key]

func box_mesh(sz: Vector3) -> BoxMesh:
	var k := "box_%s" % sz
	if not _meshes.has(k):
		var b := BoxMesh.new(); b.size = sz; _meshes[k] = b
	return _meshes[k]

func cyl_mesh(r: float, h: float) -> CylinderMesh:
	var k := "cyl_%s_%s" % [r, h]
	if not _meshes.has(k):
		var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 10; _meshes[k] = c
	return _meshes[k]

func sphere_mesh(r: float) -> SphereMesh:
	var k := "sph_%s" % r
	if not _meshes.has(k):
		var s := SphereMesh.new(); s.radius = r; s.height = r * 2; s.radial_segments = 10; s.rings = 6; _meshes[k] = s
	return _meshes[k]

func build() -> void:
	_rng.seed = seed_value if seed_value != 0 else randi()
	var w := tiles_x * TILE; var d := tiles_z * TILE
	map_rect = Rect2(-w / 2.0, -d / 2.0, w, d)
	_build_ground(w, d)
	_layout_tiles()
	_build_tiles()
	bounds = zone_rect(0)
	_build_walls()
	for key in _tile_kind:
		if zone_of(key) == 0: _populate_tile(key)
	_place_landmarks()
	_make_spawn_groups()
	spawned_count = object_count
	Events.object_captured.connect(_on_captured)
	set_process(false)

func zone_of(key: Vector2i) -> int:
	var nx: float = absf(key.x + 0.5 - tiles_x / 2.0) / (tiles_x / 2.0); var nz: float = absf(key.y + 0.5 - tiles_z / 2.0) / (tiles_z / 2.0)
	var z: float = maxf(nx, nz)
	for i in ZONE_EDGES.size():
		if z <= ZONE_EDGES[i]: return i
	return ZONE_EDGES.size() - 1

func zone_rect(i: int) -> Rect2:
	var e: float = ZONE_EDGES[i]
	var hw := tiles_x * TILE * 0.5 * e; var hd := tiles_z * TILE * 0.5 * e
	return Rect2(-hw, -hd, hw * 2.0, hd * 2.0)

func _on_captured(_hole, _fo, _p, _x) -> void:
	eaten_count += 1
	if _pending.is_empty() and zone_index < ZONE_EDGES.size() - 1 and eaten_count >= spawned_count * UNLOCK_FRACTION:
		_unlock_next_zone()

func _unlock_next_zone() -> void:
	zone_index += 1
	for key in _tile_kind:
		if zone_of(key) == zone_index: _pending.append(key)
	set_process(true)

## Spawn the new ring a slice per frame so unlocking never hitches, then open the walls.
func _process(_delta: float) -> void:
	var n := 0
	while not _pending.is_empty() and n < TILES_PER_FRAME:
		_populate_tile(_pending.pop_back()); n += 1
	if _pending.is_empty():
		set_process(false)
		spawned_count = object_count
		bounds = zone_rect(zone_index)
		_place_walls(bounds)
		zone_unlocked.emit(zone_index, bounds)

func _build_ground(w: float, d: float) -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(w + 400, d + 400)
	g.mesh = pm
	ground_mat = _cut_mat("grass")
	g.material_override = ground_mat
	g.position.y = -0.01
	add_child(g)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 0; body.collision_mask = 0
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(w + 400, 1.0, d + 400); cs.shape = bs
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)

func _layout_tiles() -> void:
	for x in tiles_x:
		for z in tiles_z:
			var bx: int = x % block_tiles; var bz: int = z % block_tiles
			var kind := "block"
			if bx < 2 or bz < 2: kind = "road"
			elif bx == 2 or bz == 2 or bx == block_tiles - 1 or bz == block_tiles - 1: kind = "side"
			_tile_kind[Vector2i(x, z)] = kind
	# some blocks become parks
	for bxi in range(0, tiles_x, block_tiles):
		for bzi in range(0, tiles_z, block_tiles):
			if _rng.randf() < 0.18:
				for x in range(bxi + 3, min(bxi + block_tiles - 1, tiles_x)):
					for z in range(bzi + 3, min(bzi + block_tiles - 1, tiles_z)):
						_tile_kind[Vector2i(x, z)] = "park"

func _tile_pos(x: int, z: int) -> Vector3:
	return Vector3(map_rect.position.x + (x + 0.5) * TILE, 0.0, map_rect.position.y + (z + 0.5) * TILE)

func _cut_mat(color_key: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ground.gdshader")
	m.set_shader_parameter("base_color", PAL[color_key])
	_cut_mats.append(m)
	return m

func _build_tiles() -> void:
	var road_mm := _mm(box_mesh(Vector3(TILE, 0.06, TILE)), _cut_mat("road"))
	var side_mm := _mm(box_mesh(Vector3(TILE, 0.12, TILE)), _cut_mat("sidewalk"))
	var park_mm := _mm(box_mesh(Vector3(TILE, 0.04, TILE)), _cut_mat("grass2"))
	var line_mm := _mm(box_mesh(Vector3(0.3, 0.07, 2.0)), _cut_mat("line"))
	var roads: Array[Transform3D] = []; var sides: Array[Transform3D] = []; var parks: Array[Transform3D] = []; var lines: Array[Transform3D] = []
	for key in _tile_kind:
		var p := _tile_pos(key.x, key.y)
		match _tile_kind[key]:
			"road":
				roads.append(Transform3D(Basis(), p + Vector3(0, 0.03, 0)))
				if key.x % block_tiles == 1 and key.y % block_tiles >= 2: lines.append(Transform3D(Basis(), p + Vector3(-TILE / 2, 0.035, 0)))
				if key.y % block_tiles == 1 and key.x % block_tiles >= 2: lines.append(Transform3D(Basis(Vector3.UP, PI / 2), p + Vector3(0, 0.035, -TILE / 2)))
			"side": sides.append(Transform3D(Basis(), p + Vector3(0, 0.06, 0)))
			"park": parks.append(Transform3D(Basis(), p + Vector3(0, 0.02, 0)))
	_fill_mm(road_mm, roads); _fill_mm(side_mm, sides); _fill_mm(park_mm, parks); _fill_mm(line_mm, lines)

func _mm(mesh: Mesh, m: Material) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh
	mmi.multimesh = mm; mmi.material_override = m
	add_child(mmi)
	return mmi

func _fill_mm(mmi: MultiMeshInstance3D, xforms: Array[Transform3D]) -> void:
	mmi.multimesh.instance_count = xforms.size()
	for i in xforms.size(): mmi.multimesh.set_instance_transform(i, xforms[i])

func _build_walls() -> void:
	_walls = StaticBody3D.new(); _walls.collision_layer = 1 << 2; _walls.collision_mask = 0
	for side in 4:
		var cs := CollisionShape3D.new(); cs.shape = BoxShape3D.new(); _walls.add_child(cs)
		var bar := MeshInstance3D.new(); bar.mesh = BoxMesh.new(); bar.material_override = mat("cone"); bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bar); _barrier.append(bar)
	add_child(_walls)
	_place_walls(bounds)

func _place_walls(r: Rect2) -> void:
	var w := r.size.x; var d := r.size.y
	for side in 4:
		var cs := _walls.get_child(side) as CollisionShape3D
		var vertical := side < 2
		(cs.shape as BoxShape3D).size = Vector3(1.0, 40.0, d + 2) if vertical else Vector3(w + 2, 40.0, 1.0)
		var pos := Vector3((w / 2.0 + 0.5) * (1 if side == 0 else -1), 20, 0) if vertical else Vector3(0, 20, (d / 2.0 + 0.5) * (1 if side == 2 else -1))
		cs.position = pos
		var bar := _barrier[side]
		(bar.mesh as BoxMesh).size = Vector3(0.6, 0.8, d + 0.6) if vertical else Vector3(w + 0.6, 0.8, 0.6)
		bar.position = Vector3(pos.x, 0.4, pos.z)

func _new_object(nm: String, pos: Vector3, size_req: int, pts: int, type: int, height: float) -> FallingObject:
	pts = clampi(maxi(pts, size_req), 1, 25)   # bigger things are worth more, capped at the original's 25 (mega tower)
	if size_req <= 1: pts = maxi(pts, 2)
	var fo := FallingObject.new()
	fo.name = "%s_%d" % [nm, object_count]
	fo.size_required = size_req; fo.points = pts; fo.object_type = type; fo.height = height; fo.tiers = tiers
	fo.position = pos
	fo.add_to_group("eatable")
	add_child(fo)
	object_count += 1; total_points += pts
	return fo

## Eatable exactly when it physically fits through the opening: required level from the footprint diagonal.
func _fit_level(footprint: Vector2) -> int:
	return _balance.level_for_footprint(footprint.length())

## Debug/test helper only (edge test). The city itself uses real models exclusively.
func _prop_box(nm: String, pos: Vector3, sz: Vector3, color: String, size_req: int, pts: int, type: int = 0, yaw := 0.0) -> FallingObject:
	var fo := _new_object(nm, pos + Vector3(0, sz.y / 2, 0), _fit_level(Vector2(sz.x, sz.z)), pts, type, sz.y)
	fo.footprint_half = maxf(sz.x, sz.z) * 0.5
	fo.rotation.y = yaw
	var mi := MeshInstance3D.new(); mi.mesh = box_mesh(sz); mi.material_override = mat(color); fo.add_child(mi)
	_apply_visibility(fo, sz.y)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = sz; cs.shape = bs; fo.add_child(cs)
	return fo

func _populate_tile(key: Vector2i) -> void:
	var cx := tiles_x / 2; var cz := tiles_z / 2
	var p := _tile_pos(key.x, key.y)
	var kind: String = _tile_kind[key]
	# Browser builds step physics single-threaded in wasm, so they skip a share of the small-prop tiles (buildings and cars stay).
	var building_tile: bool = kind == "block" and (key.x % block_tiles) % 2 == 1 and (key.y % block_tiles) % 2 == 1
	if OS.has_feature("web") and kind != "road" and not building_tile and _rng.randf() > WEB_PROP_KEEP: return
	var nx: float = absf(key.x - cx) / float(tiles_x / 2); var nz: float = absf(key.y - cz) / float(tiles_z / 2)
	var zone: float = maxf(nx, nz)
	var downtown: bool = zone < 0.12
	var midtown: bool = zone < 0.3
	var j := func(a: float) -> Vector3: return p + Vector3(_rng.randf_range(-a, a), 0, _rng.randf_range(-a, a))
	var yaw4: float = [0.0, PI / 2, PI, -PI / 2].pick_random()
	match kind:
		"block":
			var r := _rng.randf()
			var bx: int = key.x % block_tiles; var bz: int = key.y % block_tiles
			var anchor: bool = (bx % 2 == 1) and (bz % 2 == 1)   # big footprints every other tile (10 m spacing)
			if anchor:
				if downtown:
					if r < 0.3: _prop_model("skyscraper_tall", p, [0.0, PI / 2].pick_random())
					elif r < 0.6: _prop_model("skyscraper", p, [0.0, PI / 2].pick_random())
					else: _prop_model("apartment_tall", p, yaw4)
				elif midtown:
					if r < 0.15: _prop_model("skyscraper", p, [0.0, PI / 2].pick_random())
					elif r < 0.4: _prop_model("apartment_tall", p, yaw4)
					elif r < 0.75: _prop_model("apartment", p, yaw4)
					else: _prop_model("house", p, yaw4)
				else:
					if r < 0.45: _prop_model("house", p, yaw4)
					else: _prop_model("apartment", p, yaw4)
			else:
				for i in _rng.randi_range(2, 4):
					var q: Vector3 = j.call(2.0)
					var k := _rng.randf()
					if k < 0.22: _prop_model("tree_small", q, _rng.randf() * TAU)
					elif k < 0.4: _prop_model("bush", q, _rng.randf() * TAU)
					elif k < 0.55: _prop_model("planter", q, _rng.randf() * TAU)
					elif k < 0.7: _prop_model("cardbox", q, _rng.randf() * TAU)
					elif k < 0.8: _prop_model("dumpster", q, yaw4)
					elif k < 0.9: _prop_model("bench", q, _rng.randf() * TAU)
					else: _attach_mover(_prop_model("person", q, _rng.randf() * TAU), Movable.Kind.PERSON, Vector3.FORWARD, 0.0, MODEL_FRONT_OFFSET)
		"side":
			for i in (2 if _rng.randf() < 0.5 else 1):
				_prop_model(["cone", "hydrant", "mailbox", "cardbox", "planter", "bin"].pick_random(), j.call(2.2), _rng.randf() * TAU)
			var r := _rng.randf()
			if r < 0.28: _prop_model("lamp", j.call(1.8))
			elif r < 0.42: _prop_model("bench", p, _rng.randf() * PI)
			elif r < 0.58: _prop_model("bin", j.call(1.5), _rng.randf() * TAU)
			elif r < 0.7: _prop_model("cone", j.call(1.5), _rng.randf() * TAU)
			elif r < 0.85: _attach_mover(_prop_model("person", j.call(1.8), _rng.randf() * TAU), Movable.Kind.PERSON, Vector3.FORWARD, 0.0, MODEL_FRONT_OFFSET)
			else: _prop_model("tree_small", p, _rng.randf() * TAU)
		"park":
			var r := _rng.randf()
			if r < 0.3: _prop_model("planter", j.call(2.0), _rng.randf() * TAU)
			elif r < 0.55: _prop_model("tree" if _rng.randf() < 0.5 else "tree_small", j.call(1.5), _rng.randf() * TAU)
			elif r < 0.72: _prop_model("bush", j.call(1.8), _rng.randf() * TAU)
			elif r < 0.85: _prop_model("bench", p, _rng.randf() * TAU)
			elif r < 0.95: _attach_mover(_prop_model("person", p, _rng.randf() * TAU), Movable.Kind.PERSON, Vector3.FORWARD, 0.0, MODEL_FRONT_OFFSET)
		"road":
			if _rng.randf() < 0.06:
				var yaw := 0.0 if key.x % block_tiles < 2 else PI / 2
				if _rng.randf() < 0.5: yaw += PI
				var car := _prop_model("taxi" if _rng.randf() < 0.4 else "car", j.call(0.8), yaw)
				_attach_mover(car, Movable.Kind.CAR, Vector3(0, 0, 1).rotated(Vector3.UP, yaw), _rng.randf_range(6.0, 10.0), MODEL_FRONT_OFFSET)

var match_ref = null
var mover_count := 0
## Tripo models face local +X; Movable points local +Z along travel, so rotate by -90°.
const MODEL_FRONT_OFFSET := -PI / 2
const VEHICLES_CAP := 30   # LevelConfig.m_vehiclesCap
const WALKERS_CAP := 160
var walker_count := 0

func _attach_mover(fo: FallingObject, kind: int, dir: Vector3, speed: float, yaw_offset: float) -> void:
	if fo == null: return
	if kind == Movable.Kind.CAR and mover_count >= VEHICLES_CAP: return
	if kind == Movable.Kind.PERSON:
		if walker_count >= WALKERS_CAP: return
		walker_count += 1
	var mv := Movable.new(); mv.kind = kind; mv.dir = dir; mv.speed = speed; mv.bounds = bounds; mv.match_ref = match_ref
	fo.set_meta("yaw_offset", yaw_offset); fo.add_child(mv)
	if kind == Movable.Kind.CAR: mover_count += 1

## The biggest things on the map: 3 mega towers near the center (size 16, 25 points each).
func _place_landmarks() -> void:
	var cx: int = tiles_x / 2; var cz: int = tiles_z / 2
	var spots := [Vector2i(cx, cz), Vector2i(cx - block_tiles * 2, cz + block_tiles), Vector2i(cx + block_tiles * 2, cz - block_tiles)]
	for s in spots:
		var bx: int = s.x - (s.x % block_tiles) + 4; var bz: int = s.y - (s.y % block_tiles) + 4
		var p := _tile_pos(bx, bz) - Vector3(TILE / 2, 0, TILE / 2)
		# clear whatever was generated on this lot
		for c in get_children():
			if not is_instance_valid(c): continue
			if c is FallingObject and Vector2(c.position.x - p.x, c.position.z - p.z).length() < 9.0:
				object_count -= 1; total_points -= c.points
				c.free()
		_prop_model("tower_mega", p, 0.0)

func _make_spawn_groups() -> void:
	spawn_groups.clear()
	var w := zone_rect(0).size.x; var d := zone_rect(0).size.y
	var centers := [Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(-0.35, 0.35), Vector2(0.35, 0.35), Vector2(0.0, 0.0)]
	for c in centers:
		var g: Array = []
		for i in 6:
			var ang := i * TAU / 6
			g.append(Vector3(c.x * w + cos(ang) * 12.0, 0, c.y * d + sin(ang) * 12.0))
		spawn_groups.append(g)

func update_hole_uniforms(holes: Array) -> void:
	var arr := PackedVector4Array()
	for i in 8:
		if i < holes.size() and not holes[i].is_dead:
			var h = holes[i]
			arr.append(Vector4(h.global_position.x, h.global_position.z, h.radius(), 1.0))
		else:
			arr.append(Vector4(0, 0, 0, 0))
	for m in _cut_mats: m.set_shader_parameter("holes", arr)
