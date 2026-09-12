extends Node
## SFX voice manager (B11/G12): at most 8 simultaneous voices, the same sound never
## re-triggers within 0.05s, boss warnings take priority, volume caps for rapid input.
## Streams are optional: with none assigned the manager still counts voices so the
## rules are testable before audio assets land (P5 asset pass). Autoloaded as `Sfx`.

const MAX_VOICES := 8
const SAME_SOUND_GAP := 0.05
const PRIORITY_WARNING := 100

var streams: Dictionary = {}          # id -> AudioStream (empty until assets exist)
var last_played: Dictionary = {}      # id -> time (seconds)
var players: Array[AudioStreamPlayer] = []
var clock: float = 0.0
## Voices "in flight" for the rules; each entry {"id", "until", "priority"}.
var voices: Array[Dictionary] = []


const SFX_IDS := ["hit_ink", "purify", "sentence_hit", "boss_warning", "boss_intro", "page_turn", "boss_purified"]
const UI_IDS := ["ui_click", "ui_confirm", "ui_cancel", "ui_hover"]
const BGM_IDS := {"library": "res://art/audio/bgm_library.ogg", "combat": "res://art/audio/bgm_combat.ogg"}
const BOSS_LAYER_PATH := "res://art/audio/bgm_boss_layer.ogg"
const LAYER_FADE := 1.0
const LAYER_OFF_DB := -40.0
const CANCEL_NAME_HINTS := ["Back", "Abandon", "Close", "Skip", "Cancel"]

var bgm_player: AudioStreamPlayer
var current_bgm: String = ""
## B11 보스 강도 레이어: one extra loop over bgm_combat, faded in for boss Waves.
var layer_player: AudioStreamPlayer
var boss_layer_on: bool = false
var layer_tween: Tween
## UI bus: button clicks bypass the 8 SFX voices so combat feedback never loses a slot.
var ui_player: AudioStreamPlayer


func _ready() -> void:
	# Menus run with the tree paused (G2): the clock, the same-sound gap and the layer fade
	# must keep going, and BGM keeps playing under the pause panel.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in MAX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "BGM"
	add_child(bgm_player)
	layer_player = AudioStreamPlayer.new()
	layer_player.bus = "BGM"
	layer_player.volume_db = LAYER_OFF_DB
	add_child(layer_player)
	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "UI"
	add_child(ui_player)
	for id in SFX_IDS + UI_IDS:
		var path := "res://art/audio/sfx/%s.ogg" % id
		if ResourceLoader.exists(path):
			streams[id] = load(path)
	if ResourceLoader.exists(BOSS_LAYER_PATH):
		var layer: AudioStream = load(BOSS_LAYER_PATH)
		if layer is AudioStreamOggVorbis:
			layer.loop = true
		layer_player.stream = layer
	get_tree().node_added.connect(_on_node_added)


## Every button clicks on the UI bus (G12): primary actions confirm, back/abandon cancel.
func _on_node_added(node: Node) -> void:
	if not (node is BaseButton):
		return
	node.pressed.connect(func(): play_ui(_ui_sound_for(node)))
	node.mouse_entered.connect(func(): play_ui("ui_hover"))


func _ui_sound_for(button: BaseButton) -> String:
	if button.theme_type_variation == &"PrimaryButton":
		return "ui_confirm"
	for hint in CANCEL_NAME_HINTS:
		if hint in String(button.name):
			return "ui_cancel"
	return "ui_click"


## UI sounds share the 0.05s same-sound gap but never take an SFX voice.
func play_ui(id: String) -> bool:
	if last_played.has(id) and clock - last_played[id] < SAME_SOUND_GAP:
		return false
	last_played[id] = clock
	var stream: AudioStream = streams.get(id)
	if stream != null:
		ui_player.stream = stream
		ui_player.play()
	return true


## Boss layer on/off with a 1s fade; starts in sync with the combat loop's position.
func set_boss_layer(on: bool) -> void:
	if on == boss_layer_on:
		return
	boss_layer_on = on
	if layer_player.stream == null:
		return
	if on and not layer_player.playing:
		layer_player.play(bgm_player.get_playback_position() if bgm_player.playing else 0.0)
	if layer_tween != null:
		layer_tween.kill()
	layer_tween = create_tween()
	layer_tween.tween_property(layer_player, "volume_db", 0.0 if on else LAYER_OFF_DB, LAYER_FADE)
	if not on:
		layer_tween.tween_callback(layer_player.stop)


## BGM: 2 loops (서고/전투). Same id twice is a no-op so scene changes never restart it.
func play_bgm(id: String) -> void:
	if id == current_bgm:
		return
	var path: String = BGM_IDS.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	bgm_player.stream = stream
	bgm_player.play()
	current_bgm = id


func _process(delta: float) -> void:
	clock += delta
	voices = voices.filter(func(v): return v["until"] > clock)


## Returns true when the sound was (virtually) played. `length` is the voice length used
## for the cap while no stream is assigned.
func play(id: String, priority: int = 0, length: float = 0.25) -> bool:
	if last_played.has(id) and clock - last_played[id] < SAME_SOUND_GAP:
		return false
	voices = voices.filter(func(v): return v["until"] > clock)
	if voices.size() >= MAX_VOICES:
		var lowest := -1
		for i in voices.size():
			if lowest < 0 or voices[i]["priority"] < voices[lowest]["priority"]:
				lowest = i
		if lowest < 0 or voices[lowest]["priority"] >= priority:
			return false  # full and nothing to evict for this priority
		voices.remove_at(lowest)
	last_played[id] = clock
	voices.append({"id": id, "until": clock + length, "priority": priority})
	var stream: AudioStream = streams.get(id)
	if stream != null:
		for p in players:
			if not p.playing:
				p.stream = stream
				p.play()
				break
	return true


func active_voices() -> int:
	voices = voices.filter(func(v): return v["until"] > clock)
	return voices.size()


func reset() -> void:
	voices.clear()
	last_played.clear()
	clock = 0.0
	set_boss_layer(false)
