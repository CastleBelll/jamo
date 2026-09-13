extends SubViewportContainer
## 3D character layer over the 2D battlefield (P6). Gameplay stays 2D (paths, click circles,
## HUD); this viewport only draws the porcelain figures where the 2D entities are. A screen
## point maps to the ground plane through the camera ray, so any camera tilt works.

const GROUND := Plane(Vector3.UP, 0.0)

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/World/Camera3D
@onready var proxies: Node3D = $SubViewport/World/Proxies


func _ready() -> void:
	add_to_group("battle3d")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.transparent_bg = true


## 2D battlefield coordinates (the logical 1920x1080 canvas) -> point on the 3D ground.
func ground_point(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var hit = GROUND.intersects_ray(origin, dir)
	return hit if hit != null else Vector3(screen.x * 0.01, 0.0, screen.y * 0.01)


## Returns a proxy when a model exists for the jamo, else null (the 2D sprite stays).
func spawn_proxy(jamo: String, motion_id: StringName) -> CharacterProxy:
	return spawn_scene(CharacterProxy.model_for(jamo), motion_id, CharacterProxy.TARGET_HEIGHT)


## Boss figures: their own model file, 1.5x the enemy height (fits between the HUD band and the
## B11 anchor at y=260 without clipping), no gait.
func spawn_boss_proxy(boss_id: StringName) -> CharacterProxy:
	return spawn_scene(CharacterProxy.model_for_boss(boss_id), &"GLIDE", CharacterProxy.TARGET_HEIGHT * 1.5)


func spawn_scene(scene: PackedScene, motion_id: StringName, height: float) -> CharacterProxy:
	if scene == null:
		return null
	var proxy := CharacterProxy.new()
	proxies.add_child(proxy)
	proxy.setup(scene, motion_id, height)
	return proxy
