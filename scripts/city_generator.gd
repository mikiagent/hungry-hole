class_name CityGenerator
extends Node3D
## Builds a city on a 5 m grid: roads, sidewalks, blocks with stacked buildings, props, cars, people.
## Targets from 03-systems/maps-and-city.md: footprint ~250x300 m, ~2,500 objects, mostly size 1.
const TILE := 5.0
@export var tiles_x: int = 96
@export var tiles_z: int = 108
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
var bounds: Rect2
var spawn_groups: Array = []
var object_count := 0
var total_points := 0
var _tile_kind := {}   # Vector2i -> "road"|"side"|"block"|"park"
## Tripo-generated GLBs (normalized to ~1 unit). scale = world size of the longest axis class.
const MODELS := {
	"apartment": {"path": "res://assets/tripo/apartment_v3.glb", "scale": 12.0, "size": 7, "pts": 7, "type": 3},
	"skyscraper": {"path": "res://assets/tripo/skyscraper_v3.glb", "scale": 26.0, "size": 10, "pts": 10, "type": 3},
	"apartment_tall": {"path": "res://assets/tripo/apartment_v3.glb", "scale": 18.0, "size": 9, "pts": 10, "type": 3},
	"skyscraper_tall": {"path": "res://assets/tripo/skyscraper_v3.glb", "scale": 42.0, "size": 13, "pts": 16, "type": 3},
	"tower_mega": {"path": "res://assets/tripo/skyscraper_v3.glb", "scale": 64.0, "size": 16, "pts": 25, "type": 3},
	"tree": {"path": "res://assets/tripo/tree_v3.glb", "scale": 3.2, "size": 2, "pts": 2, "type": 0},
	"tree_small": {"path": "res://assets/tripo/tree_v3.glb", "scale": 2.0, "size": 1, "pts": 1, "type": 0},
	"lamp": {"path": "res://assets/tripo/lamp_v2.glb", "scale": 3.4, "size": 1, "pts": 1, "type": 0},
	"bench": {"path": "res://assets/tripo/bench_v2.glb", "scale": 1.9, "size": 1, "pts": 1, "type": 0},
	"person": {"path": "res://assets/tripo/person_v3.glb", "scale": 1.4, "size": 1, "pts": 1, "type": 1},
	"taxi": {"path": "res://assets/tripo/car_taxi.glb", "scale": 4.2, "size": 2, "pts": 2, "type": 2, "yaw": PI / 2},
	"car": {"path": "res://assets/tripo/car_red.glb", "scale": 4.2, "size": 2, "pts": 2, "type": 2, "yaw": PI / 2},
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
	bounds = Rect2(-w / 2.0, -d / 2.0, w, d)
	_build_ground(w, d)
	_layout_tiles()
	_build_tiles()
	_build_walls(w, d)
	_populate()
	_place_landmarks()
	_make_spawn_groups()

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
	return Vector3(bounds.position.x + (x + 0.5) * TILE, 0.0, bounds.position.y + (z + 0.5) * TILE)

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

func _build_walls(w: float, d: float) -> void:
	var walls := StaticBody3D.new(); walls.collision_layer = 1 << 2; walls.collision_mask = 0
	for side in 4:
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
		var vertical := side < 2
		bs.size = Vector3(1.0, 20.0, d + 2) if vertical else Vector3(w + 2, 20.0, 1.0)
		cs.shape = bs
		cs.position = Vector3((w / 2.0 + 0.5) * (1 if side == 0 else -1), 10, 0) if vertical else Vector3(0, 10, (d / 2.0 + 0.5) * (1 if side == 2 else -1))
		walls.add_child(cs)
	add_child(walls)
	# low brick wall ring (eatable, size 3) like the original's Boundarie_S_BrickWall
	var step := 5.0
	for x in range(int(-w / 2 + 2.5), int(w / 2), int(step)):
		_prop_box("brick", Vector3(x, 0, -d / 2 + 1.0), Vector3(4.6, 1.2, 0.8), "b_coral2", 3, 1)
		_prop_box("brick", Vector3(x, 0, d / 2 - 1.0), Vector3(4.6, 1.2, 0.8), "b_coral2", 3, 1)
	for z in range(int(-d / 2 + 2.5), int(d / 2), int(step)):
		_prop_box("brick", Vector3(-w / 2 + 1.0, 0, z), Vector3(0.8, 1.2, 4.6), "b_coral2", 3, 1)
		_prop_box("brick", Vector3(w / 2 - 1.0, 0, z), Vector3(0.8, 1.2, 4.6), "b_coral2", 3, 1)

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

func _prop_box(nm: String, pos: Vector3, sz: Vector3, color: String, size_req: int, pts: int, type: int = 0, yaw := 0.0) -> FallingObject:
	var fo := _new_object(nm, pos + Vector3(0, sz.y / 2, 0), _fit_level(Vector2(sz.x, sz.z)), pts, type, sz.y)
	fo.footprint_half = maxf(sz.x, sz.z) * 0.5
	fo.rotation.y = yaw
	var mi := MeshInstance3D.new(); mi.mesh = box_mesh(sz); mi.material_override = mat(color); fo.add_child(mi)
	_apply_visibility(fo, sz.y)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = sz; cs.shape = bs; fo.add_child(cs)
	return fo

func _prop_tree(pos: Vector3, big: bool) -> void:
	var h := 2.6 if big else 1.8
	var fo := _new_object("tree", pos + Vector3(0, h / 2, 0), 2 if big else 1, 2 if big else 1, 0, h)
	var trunk := MeshInstance3D.new(); trunk.mesh = cyl_mesh(0.18, h * 0.5); trunk.material_override = mat("trunk"); trunk.position.y = -h / 2 + h * 0.25; fo.add_child(trunk)
	var canopy := MeshInstance3D.new(); canopy.mesh = sphere_mesh(1.1 if big else 0.75); canopy.material_override = mat("leaf"); canopy.position.y = h * 0.2; fo.add_child(canopy)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.6 if big else 1.1, h, 1.6 if big else 1.1); cs.shape = bs; fo.add_child(cs)

func _prop_lamp(pos: Vector3) -> void:
	var fo := _new_object("lamp", pos + Vector3(0, 1.6, 0), 1, 1, 0, 3.2)
	var pole := MeshInstance3D.new(); pole.mesh = cyl_mesh(0.08, 3.0); pole.material_override = mat("metal"); fo.add_child(pole)
	var head := MeshInstance3D.new(); head.mesh = box_mesh(Vector3(0.5, 0.25, 0.5)); head.material_override = mat("window"); head.position.y = 1.55; fo.add_child(head)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.5, 3.2, 0.5); cs.shape = bs; fo.add_child(cs)

func _prop_person(pos: Vector3) -> void:
	var fo := _new_object("person", pos + Vector3(0, 0.6, 0), 1, 1, 1, 1.2)
	var body := MeshInstance3D.new(); body.mesh = box_mesh(Vector3(0.45, 0.6, 0.3)); body.material_override = mat(["b_mint", "b_sky", "b_coral", "b_sun", "b_grape"].pick_random()); body.position.y = -0.2; fo.add_child(body)
	var head := MeshInstance3D.new(); head.mesh = sphere_mesh(0.3); head.material_override = mat(["skin", "skin2", "skin3"].pick_random()); head.position.y = 0.4; fo.add_child(head)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.6, 1.2, 0.6); cs.shape = bs; fo.add_child(cs)

func _prop_car(pos: Vector3, yaw: float) -> void:
	var col: String = ["taxi", "car_red", "car_blue", "truck"].pick_random()
	var is_truck := col == "truck"
	var sz := Vector3(2.0, 1.0, 4.2) if not is_truck else Vector3(2.2, 1.6, 5.0)
	var fo := _prop_box("car", pos, sz, col, 2, 3 if is_truck else 2, 2, yaw)
	for sx in [-1, 1]:
		for sz2 in [-1, 1]:
			var wh := MeshInstance3D.new(); wh.mesh = cyl_mesh(0.35, 0.3); wh.material_override = mat("tire")
			wh.rotation.z = PI / 2; wh.position = Vector3(sx * (sz.x / 2), -sz.y / 2 + 0.35, sz2 * (sz.z / 2 - 0.9)); fo.add_child(wh)
	var cab := MeshInstance3D.new(); cab.mesh = box_mesh(Vector3(sz.x * 0.8, 0.6, sz.z * 0.4)); cab.material_override = mat("window"); cab.position.y = sz.y / 2 + 0.3; fo.add_child(cab)

func _building_stack(pos: Vector3, stories: int, hue: String) -> void:
	# city_appartments_M_base/story/roof: each segment size 5 / 1 point, stacked and linked (domino)
	var prev: FallingObject = null
	var fp := 4.0
	for i in stories + 1:
		var is_roof := i == stories
		var h := 0.6 if is_roof else 3.0
		var y := i * 3.0
		var color := "roof" if is_roof else (hue if i % 2 == 0 else hue + "2")
		var seg := _prop_box("apt", pos + Vector3(0, y, 0), Vector3(fp if not is_roof else fp * 0.9, h, fp if not is_roof else fp * 0.9), color, 5, 1, 3)
		if not is_roof:
			for side in 4:
				var win := MeshInstance3D.new(); win.mesh = box_mesh(Vector3(0.7, 0.9, 0.1)); win.material_override = mat("window")
				win.rotation.y = side * PI / 2; win.position = Vector3(0, 0.2, fp / 2 + 0.02).rotated(Vector3.UP, side * PI / 2); seg.add_child(win)
		if prev: prev.stack_above = seg
		prev = seg

func _skyscraper(pos: Vector3) -> void:
	var segs := [Vector3(7, 10, 7), Vector3(6, 8, 6), Vector3(5, 6, 5)]
	var y := 0.0; var prev: FallingObject = null
	for i in segs.size():
		var s: Vector3 = segs[i]
		var seg := _prop_box("tower", pos + Vector3(0, y, 0), s, "b_sky" if i % 2 == 0 else "b_sky2", 10 if i == 0 else 9, 10 if i == 0 else 7, 3)
		if prev: prev.stack_above = seg
		prev = seg; y += s.y
	var top := _prop_box("tower_top", pos + Vector3(0, y, 0), Vector3(1.0, 3.0, 1.0), "dark", 7, 3, 3)
	if prev: prev.stack_above = top

func _m_building(pos: Vector3) -> void:
	var hue: String = ["b_sun", "b_mint", "b_grape", "b_coral"].pick_random()
	var base := _prop_box("mbuilding", pos, Vector3(8, 6, 8), hue, 7, 7, 3)
	var roof := _prop_box("mroof", pos + Vector3(0, 6, 0), Vector3(7.4, 0.6, 7.4), "roof", 5, 1, 3)
	base.stack_above = roof

func _populate() -> void:
	var cx := tiles_x / 2; var cz := tiles_z / 2
	for key in _tile_kind:
		var p := _tile_pos(key.x, key.y)
		var kind: String = _tile_kind[key]
		var nx: float = absf(key.x - cx) / float(tiles_x / 2); var nz: float = absf(key.y - cz) / float(tiles_z / 2)
		var zone: float = maxf(nx, nz)
		var downtown: bool = zone < 0.22
		var midtown: bool = zone < 0.45
		match kind:
			"block":
				var r := _rng.randf()
				var bx: int = key.x % block_tiles; var bz: int = key.y % block_tiles
				var anchor: bool = (bx % 2 == 1) and (bz % 2 == 1)   # big footprints every other tile (10 m spacing)
				if anchor:
					var hue: String = ["b_coral", "b_sun", "b_mint", "b_sky", "b_grape"].pick_random()
					if downtown:
						if r < 0.3: _prop_model("skyscraper_tall", p, [0.0, PI / 2].pick_random())
						elif r < 0.55: _prop_model("skyscraper", p, [0.0, PI / 2].pick_random())
						elif r < 0.75: _prop_model("apartment_tall", p, [0.0, PI / 2, PI, -PI / 2].pick_random())
						else: _building_stack(p, _rng.randi_range(5, 7), hue)
					elif midtown:
						if r < 0.15: _prop_model("skyscraper", p, [0.0, PI / 2].pick_random())
						elif r < 0.35: _prop_model("apartment_tall", p, [0.0, PI / 2, PI, -PI / 2].pick_random())
						elif r < 0.65: _prop_model("apartment", p, [0.0, PI / 2, PI, -PI / 2].pick_random())
						else: _building_stack(p, _rng.randi_range(3, 5), hue)
					else:
						if r < 0.5: _prop_model("apartment", p, [0.0, PI / 2, PI, -PI / 2].pick_random())
						else: _building_stack(p, _rng.randi_range(2, 4), hue)
				else:
					# fill the gaps between buildings (the original packs ~3 small objects per 5 m tile)
					var n := _rng.randi_range(2, 4)
					for i in n:
						var q := p + Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0))
						var k := _rng.randf()
						if k < 0.25: _prop_model("tree_small", q, _rng.randf() * TAU)
						elif k < 0.4: _prop_box("hedge", q, Vector3(1.6, 0.9, 0.8), "leaf", 2, 2, 0, [0.0, PI / 2].pick_random())
						elif k < 0.55: _prop_box("flower", q, Vector3(0.5, 0.5, 0.5), ["flower1", "flower2", "flower3"].pick_random(), 1, 1)
						elif k < 0.7: _prop_box("crate", q, Vector3(0.8, 0.8, 0.8), "wood", 1, 1, 0, _rng.randf() * PI)
						elif k < 0.8: _prop_box("dumpster", q, Vector3(1.8, 1.2, 1.0), "b_mint2", 2, 2, 0, [0.0, PI / 2].pick_random())
						elif k < 0.9: _prop_model("bench", q, _rng.randf() * TAU)
						else: _attach_mover(_prop_model("person", q, _rng.randf() * TAU), Movable.Kind.PERSON, Vector3.FORWARD, 0.0, 0.0)
			"side":
				for k in (1 if _rng.randf() < 0.6 else 0):
					var q := p + Vector3(_rng.randf_range(-2.2, 2.2), 0, _rng.randf_range(-2.2, 2.2))
					match _rng.randi() % 4:
						0: _prop_box("can", q, Vector3(0.3, 0.4, 0.3), ["cone", "b_coral", "b_sky"].pick_random(), 1, 1)
						1: _prop_box("flower", q, Vector3(0.45, 0.45, 0.45), ["flower1", "flower2", "flower3"].pick_random(), 1, 1)
						2: _prop_box("box", q, Vector3(0.6, 0.5, 0.6), "wood", 1, 1, 0, _rng.randf() * PI)
						3: _prop_box("hydrant", q, Vector3(0.35, 0.7, 0.35), "b_coral", 1, 1)
				if _rng.randf() < 0.5:
					_prop_box("cone" if _rng.randf() < 0.5 else "bin", p + Vector3(_rng.randf_range(-1.8, 1.8), 0, _rng.randf_range(-1.8, 1.8)), Vector3(0.5, 0.7, 0.5) , ["cone", "bin"].pick_random(), 1, 1)
				var r := _rng.randf()
				if r < 0.28: _prop_model("lamp", p + Vector3(_rng.randf_range(-1.8, 1.8), 0, _rng.randf_range(-1.8, 1.8)))
				elif r < 0.45: _prop_box("pole", p + Vector3(_rng.randf_range(-1.8, 1.8), 0, _rng.randf_range(-1.8, 1.8)), Vector3(0.2, 2.6, 0.2), "metal", 1, 1)
				elif r < 0.58: _prop_model("bench", p, _rng.randf() * PI)
				elif r < 0.68: _prop_box("bin", p + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5)), Vector3(0.6, 0.9, 0.6), "bin", 1, 1)
				elif r < 0.78: _prop_box("cone", p + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5)), Vector3(0.5, 0.7, 0.5), "cone", 1, 1)
				elif r < 0.9: _attach_mover(_prop_model("person", p + Vector3(_rng.randf_range(-1.8, 1.8), 0, _rng.randf_range(-1.8, 1.8)), _rng.randf() * TAU), Movable.Kind.PERSON, Vector3.FORWARD, 0.0, 0.0)
				else: _prop_model("tree_small", p, _rng.randf() * TAU)
			"park":
				var r := _rng.randf()
				if r < 0.35: _prop_box("flower", p + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2)), Vector3(0.5, 0.5, 0.5), ["flower1", "flower2", "flower3"].pick_random(), 1, 1)
				elif r < 0.6: _prop_model("tree" if _rng.randf() < 0.5 else "tree_small", p + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5)), _rng.randf() * TAU)
				elif r < 0.75: _prop_box("hedge", p, Vector3(2.4, 0.9, 0.8), "leaf", 2, 2, 0, _rng.randf() < 0.5 if 0.0 else PI / 2)
				elif r < 0.85: _prop_model("bench", p, _rng.randf() * TAU)
				elif r < 0.95: _attach_mover(_prop_model("person", p, _rng.randf() * TAU), Movable.Kind.PERSON, Vector3.FORWARD, 0.0, 0.0)
			"road":
				if _rng.randf() < 0.06:
					var yaw := 0.0 if key.x % block_tiles < 2 else PI / 2
					if _rng.randf() < 0.5: yaw += PI
					var car := _prop_model("taxi" if _rng.randf() < 0.4 else "car", p + Vector3(_rng.randf_range(-0.8, 0.8), 0, _rng.randf_range(-0.8, 0.8)), yaw)
					_attach_mover(car, Movable.Kind.CAR, Vector3(0, 0, 1).rotated(Vector3.UP, yaw), _rng.randf_range(6.0, 10.0), PI / 2)

var match_ref = null
var mover_count := 0
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
	var w := bounds.size.x; var d := bounds.size.y
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
