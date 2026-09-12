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


func _ready() -> void:
	for i in MAX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)


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
