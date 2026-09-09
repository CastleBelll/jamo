extends Node

## Single owner of playback and of the three bus volumes. Doc v0.3 section 25.
##
## Every sound goes through here so nothing allocates an AudioStreamPlayer per
## click: the pool in audio_manager.tscn is fixed and reused round-robin, and a
## stream is loaded at most once and then kept. Doc v0.3 section 36.
##
## The repository ships no audio files yet, so every cue resolves to an empty
## path and play() quietly does nothing. That is deliberate: a missing file must
## never raise a load error mid-fight.

## Bus names, matching res://default_bus_layout.tres.
const BUS_MASTER := &"Master"
const BUS_BGM := &"BGM"
const BUS_SFX := &"SFX"

## Quietest slider position that still plays. Below it the bus is muted, so a
## slider at 0 is silence rather than a very faint sound.
const MIN_AUDIBLE_VOLUME := 0.001

## Named cues and their file paths. Assigned in audio_manager.tscn.
@export var library: AudioLibrary

@onready var _sfx_pool: Node = $SfxPool
@onready var _bgm_player: AudioStreamPlayer = $BgmPlayer

## Slider positions, 0.0 - 1.0 linear. Written by the settings screen and saved.
var _volumes: Dictionary = {
	BUS_MASTER: 1.0,
	BUS_BGM: 1.0,
	BUS_SFX: 1.0,
}

## Fixed pool of players, filled from the scene. Never grows at runtime.
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
## Absolute path -> AudioStream, with null recorded for a path that is missing
## so a absent file is looked up once and then skipped for free.
var _streams: Dictionary = {}


func _ready() -> void:
	for child: Node in _sfx_pool.get_children():
		var player := child as AudioStreamPlayer
		if player != null:
			_players.append(player)
	if _players.is_empty():
		push_error("AudioManager: SfxPool has no AudioStreamPlayer children.")
	_apply_all_volumes()
	_start_bgm()


# --- Volume ----------------------------------------------------------------

## Slider position of one bus, 0.0 - 1.0.
func get_volume(bus: StringName) -> float:
	return float(_volumes.get(bus, 1.0))


## Moves one bus. Unknown bus names are ignored so a stale save cannot create
## a bus that the layout does not have.
func set_volume(bus: StringName, value: float) -> void:
	if not _volumes.has(bus):
		return
	_volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)


func _apply_all_volumes() -> void:
	for bus: StringName in _volumes:
		_apply_volume(bus)


func _apply_volume(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(String(bus))
	if index < 0:
		push_warning("AudioManager: audio bus %s is missing from the layout." % bus)
		return
	var value: float = get_volume(bus)
	AudioServer.set_bus_mute(index, value < MIN_AUDIBLE_VOLUME)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, MIN_AUDIBLE_VOLUME)))


# --- Playback ---------------------------------------------------------------

## Plays a named cue from the library. Silent when the cue is empty or its file
## is not in the project.
func play_sfx(key: StringName) -> void:
	if library == null:
		return
	play_sfx_path(library.path_for(key))


## Plays an arbitrary audio path, used by MotionProfile step sounds which carry
## their own path rather than a library key. Doc v0.3 section 25.
func play_sfx_path(path: String) -> void:
	var stream := _stream_for(path)
	if stream == null or _players.is_empty():
		return
	# Round-robin: the oldest player is the one reused, so a burst of clicks
	# overlaps instead of cutting itself off.
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.play()


## Cached stream for a path, or null when the path is empty or the file is not
## in the project. Nothing is loaded twice and a missing file logs nothing.
func _stream_for(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = ResourceLoader.load(path) as AudioStream
	_streams[path] = stream
	return stream


func _start_bgm() -> void:
	if library == null:
		return
	var stream := _stream_for(library.bgm)
	if stream == null:
		return
	_bgm_player.stream = stream
	_bgm_player.play()


# --- Save / load ------------------------------------------------------------
# Stored inside the same save file as the rest of the game. Doc v0.3 section 30.

func to_dict() -> Dictionary:
	return {
		"master": get_volume(BUS_MASTER),
		"bgm": get_volume(BUS_BGM),
		"sfx": get_volume(BUS_SFX),
	}


func from_dict(data: Dictionary) -> void:
	set_volume(BUS_MASTER, float(data.get("master", get_volume(BUS_MASTER))))
	set_volume(BUS_BGM, float(data.get("bgm", get_volume(BUS_BGM))))
	set_volume(BUS_SFX, float(data.get("sfx", get_volume(BUS_SFX))))
