extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var stats: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/monsters/asset_stats.json"))
	for entry: Dictionary in stats.assets:
		var packed := load("res://art/monsters/%s.glb" % entry.id) as PackedScene
		check(packed != null, "Missing GLB")
		if packed == null: continue
		var model := packed.instantiate() as Node3D
		root.add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() == 5, "Mesh count " + entry.id)
		var triangles := 0
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in meshes:
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			for surface in mesh.mesh.get_surface_count():
				triangles += mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3
		for name in ["Glyph", "Eye_L", "Eye_R", "Leg_L", "Leg_R"]:
			check(model.find_child(name,true,false) != null, "Part missing " + name)
		check(triangles == int(entry.triangles), "Triangles " + entry.id)
		check(absf(bounds.position.y) < .00001, "Floor " + entry.id)
		check(absf(bounds.end.y-float(entry.height)) < .002, "Height " + entry.id)
		var glyph := model.find_child("Glyph",true,false) as MeshInstance3D
		if glyph != null:
			check(glyph.mesh.get_surface_count()==2,"Glyph slots")
			for slot in 2:
				check(glyph.get_active_material(slot).resource_name == stats.slots[slot], "Slot name")
			for path in ["res://materials/jamo_gold.tres","res://materials/jamo_special_fast.tres"]:
				var special := load(path) as Material
				glyph.set_surface_override_material(0,special)
				check(glyph.get_active_material(0)==special,"Override")
				glyph.set_surface_override_material(0,null)
		for name in ["Leg_L","Leg_R"]:
			var leg := model.find_child(name,true,false) as Node3D
			if leg == null: continue
			var rest := leg.transform
			var pivot := leg.global_position
			leg.rotation.x = .35
			check(leg.global_position.is_equal_approx(pivot) and not leg.transform.is_equal_approx(rest), "Hip rotation")
			leg.transform = rest
		print("CHARACTER_CHECK ",entry.id," triangles=",triangles," bounds=",bounds)
		model.free()
	print("CHARACTERS_PASS" if failures==0 else "CHARACTERS_FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)

