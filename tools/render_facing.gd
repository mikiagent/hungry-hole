extends SceneTree
## Renders each model seen from +Z (camera at +Z looking toward -Z) and from +X, to find which local axis is the model's front.
const MODELS := ["person_v3", "car_red", "car_taxi"]
func _init() -> void:
	var root := Node3D.new(); get_root().add_child(root)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 30, 0); root.add_child(sun)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color.WHITE; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; root.add_child(env)
	var cam := Camera3D.new(); root.add_child(cam)
	for m in MODELS:
		var inst: Node3D = (load("res://assets/tripo/%s.glb" % m) as PackedScene).instantiate(); root.add_child(inst)
		var aabb := _aabb(inst)
		print(m, " aabb size=", aabb.size, " center=", aabb.get_center())
		var c := aabb.get_center(); var r := aabb.size.length()
		for side in [["z", Vector3(0, 0.3, 1)], ["x", Vector3(1, 0.3, 0)]]:
			cam.look_at_from_position(c + side[1].normalized() * r * 1.4, c)
			for i in 4: await process_frame
			get_root().get_texture().get_image().save_png("res://tools/facing_%s_from_%s.png" % [m, side[0]])
		inst.queue_free()
	quit()
func _aabb(n: Node) -> AABB:
	var out := AABB(); var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		if first: out = b; first = false
		else: out = out.merge(b)
	return out
