extends SceneTree
## Asset-only import contract check; no game scene or logic modifications.

func _initialize() -> void:
	var packed := load("res://art/objective/sentence_core.glb") as PackedScene
	assert(packed != null, "GLB must import as PackedScene")
	var model := packed.instantiate() as Node3D
	root.add_child(model)
	var expected := ["Binding", "BookPages", "BindingThread", "SentenceInk", "CorePaper", "CoreInk", "Seal"]
	var triangles := 0
	var surfaces := 0
	var bounds := AABB()
	var first := true
	for mesh_name in expected:
		var part := model.find_child(mesh_name, true, false) as MeshInstance3D
		assert(part != null, "Missing mesh: " + mesh_name)
		assert(part.mesh != null)
		var world_bounds: AABB = part.transform * part.get_aabb()
		bounds = world_bounds if first else bounds.merge(world_bounds)
		first = false
		for surface in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			surfaces += 1
			assert(part.get_active_material(surface) != null)
		print("PART ", part.name, " surfaces=", part.mesh.get_surface_count())
	var core := model.find_child("CorePaper", true, false) as MeshInstance3D
	var original := core.get_active_material(0)
	var hit := original.duplicate() as StandardMaterial3D
	assert(hit != null)
	hit.albedo_color = Color(1.0, 0.3, 0.15)
	core.material_override = hit
	assert(core.get_active_material(0) == hit)
	core.material_override = null
	assert(core.get_active_material(0) == original)
	var glyph := model.find_child("CoreInk", true, false) as MeshInstance3D
	glyph.visible = false
	assert(not glyph.visible)
	glyph.visible = true
	assert(triangles < 5000)
	print("ASSET_PASS triangles=", triangles, " surfaces=", surfaces, " bounds=", bounds)
	model.queue_free()
	quit(0)
