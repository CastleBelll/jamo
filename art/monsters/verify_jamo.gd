extends SceneTree
## Imported asset contract check, independent of gameplay scenes and autoload state.
var failures := 0

func require(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var stats: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/monsters/asset_stats.json"))
	var total := 0
	for entry: Dictionary in stats.assets:
		var packed := load("res://art/monsters/%s.glb" % entry.id) as PackedScene
		require(packed != null, "Import failed: " + entry.id)
		var model := packed.instantiate() as Node3D
		root.add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		require(meshes.size() == 1, "Expected one mesh")
		var glyph := meshes[0] as MeshInstance3D
		require(glyph.name == "Glyph", "Stable mesh name")
		require(glyph.mesh.get_surface_count() == 2, "Expected two surfaces")
		var bounds: AABB = glyph.global_transform * glyph.get_aabb()
		require(absf(bounds.position.y) < 0.001, "Ground origin: " + entry.id)
		require(bounds.size.y <= 0.63 and bounds.size.z <= 0.111, "Unexpected units/axis")
		var triangles := 0
		for surface in range(2):
			var arrays := glyph.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			var mat := glyph.get_active_material(surface) as StandardMaterial3D
			require(mat != null and mat.albedo_texture == null, "Embedded solid material required")
			require(mat.resource_name == stats.slots[surface], "Material slot order")
		require(triangles == int(entry.triangles) and triangles <= 1000, "Triangle count mismatch")
		for path in ["res://materials/jamo_gold.tres", "res://materials/jamo_special_fast.tres"]:
			var special := load(path) as StandardMaterial3D
			require(special != null, "Special material load")
			glyph.set_surface_override_material(0, special)
			require(glyph.get_active_material(0) == special, "Surface override")
			glyph.set_surface_override_material(0, null)
		print("GLYPH_PASS ", entry.id, " triangles=", triangles, " bounds=", bounds)
		total += triangles
		model.free()
	print("JAMO_ASSET_PASS" if failures == 0 else "JAMO_ASSET_FAIL", " count=", stats.assets.size(), " catalog_triangles=", total,
		" worst_20_plus_core=", stats.worst_case_20_plus_core)
	quit(0 if failures == 0 else 1)
