extends SceneTree
## Import contract validation only; never attached to game scenes.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var stats: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/arena/asset_stats.json"))
	var active_triangles := 0
	for entry: Dictionary in stats.assets:
		var path := "res://art/arena/%s.glb" % entry.id
		check(FileAccess.get_sha256(path) == entry.sha256, "Source hash: " + entry.id)
		var packed := load(path) as PackedScene
		check(packed != null, "PackedScene import: " + entry.id)
		if packed == null:
			continue
		var model := packed.instantiate() as Node3D
		root.add_child(model)
		check(model.transform.is_equal_approx(Transform3D.IDENTITY), "Root transform: " + entry.id)
		check(model.find_children("*", "Light3D", true, false).is_empty(), "Unexpected real light")
		check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Unexpected collision")
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() == int(entry.mesh_nodes), "Mesh count: " + entry.id)
		var triangles := 0
		var surfaces := 0
		var textured := 0
		var bounds := AABB()
		var first := true
		for instance: MeshInstance3D in meshes:
			var box: AABB = instance.global_transform * instance.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			for slot in instance.mesh.get_surface_count():
				surfaces += 1
				var arrays := instance.mesh.surface_get_arrays(slot)
				var indices = arrays[Mesh.ARRAY_INDEX]
				triangles += indices.size() / 3 if indices != null and indices.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size() / 3
				var mat := instance.get_active_material(slot) as BaseMaterial3D
				check(mat != null, "Missing PBR material: " + entry.id)
				if mat != null:
					check(mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Unexpected transparency")
					if mat.albedo_texture != null:
						textured += 1
						check(mat.albedo_texture.get_width() == 512 and mat.albedo_texture.get_height() == 512, "Color map dimensions")
		var lo: Array = entry.bounds_min
		var hi: Array = entry.bounds_max
		check(bounds.position.is_equal_approx(Vector3(lo[0],lo[1],lo[2])), "Bounds origin: " + entry.id)
		check(bounds.end.is_equal_approx(Vector3(hi[0],hi[1],hi[2])), "Bounds end: " + entry.id)
		check(triangles == int(entry.triangles), "Triangle count: " + entry.id)
		check(surfaces == int(entry.surfaces), "Surface count: " + entry.id)
		if entry.id.begins_with("arena_"):
			check(textured == 2, "Paper and wood textures")
			model.scale = Vector3(1.25,1,.8)
			check(is_equal_approx(model.scale.y,1), "Independent horizontal scaling")
		else:
			active_triangles += triangles
		print("ARENA_CHECK ",entry.id," triangles=",triangles," surfaces=",surfaces," textured=",textured," bounds=",bounds)
		model.free()
	for entry: Dictionary in stats.assets:
		if entry.id == stats.preview_floor:
			active_triangles += int(entry.triangles)
	check(active_triangles == int(stats.active_environment_triangles), "Active environment accounting")
	check(active_triangles <= int(stats.environment_budget_triangles), "Environment budget exceeded")
	print("ARENA_PASS" if failures == 0 else "ARENA_FAIL", " failures=",failures," active_triangles=",active_triangles)
	quit(0 if failures == 0 else 1)
