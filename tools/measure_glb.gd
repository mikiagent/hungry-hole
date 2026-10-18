extends SceneTree
func _init() -> void:
	var dir := DirAccess.open("res://assets/tripo")
	for f in dir.get_files():
		if not f.ends_with(".glb"): continue
		var ps = load("res://assets/tripo/" + f)
		if ps == null: print(f, " LOAD FAILED"); continue
		var inst: Node3D = ps.instantiate()
		var aabb := AABB()
		var first := true
		var tris := 0
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb() if mi.is_inside_tree() else mi.transform * mi.mesh.get_aabb()
			aabb = b if first else aabb.merge(b); first = false
			for s in mi.mesh.get_surface_count(): tris += mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3 if mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] else 0
		print("%s size=%s min=%s tris=%d" % [f, aabb.size, aabb.position, tris])
		inst.free()
	quit()
