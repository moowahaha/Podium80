extends Node
## Placeholder audio, fully synthesized at runtime (no asset files) so the final SFX/music can be
## dropped in later without touching gameplay code. Every sound is a small AudioStreamWAV built from
## square/sine/noise generators; play them by name via AudioBus.play(&"select").
##
## To swap in real audio later: register a stream in `_sfx` under the same name (or point play() at a
## loaded file). Gameplay only ever calls play()/loop_crowd(), so nothing else changes.

const MIX_RATE := 22050
const POOL_SIZE := 10

const MUSIC_DIR := "res://assets/music/"
const MUSIC_EXTS := [".ogg", ".mp3", ".wav"]

var _sfx: Dictionary = {}                 # name -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_key := &""

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)
	_crowd_player = AudioStreamPlayer.new()
	_crowd_player.bus = &"Master"
	_crowd_player.volume_db = -18.0
	add_child(_crowd_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Master"
	add_child(_music_player)
	_build_library()

## Play a looping background track by key: loads assets/music/<key>.{ogg,mp3,wav} if present and loops
## it. Calling with the SAME key that's already playing is a no-op (music continues seamlessly across
## menu screens). No file for that key -> silence. This is how supplied music drops in per screen/event.
func play_music(key: StringName, volume_db := -9.0) -> void:
	if key == _music_key and _music_player.playing:
		_music_player.volume_db = volume_db
		return
	var path := ""
	for ext in MUSIC_EXTS:
		var p := "%s%s%s" % [MUSIC_DIR, key, ext]
		if ResourceLoader.exists(p):
			path = p
			break
	_music_key = key
	if path == "":
		_music_player.stop()
		_music_player.stream = null
		return
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music_player.stream = s
	_music_player.volume_db = volume_db
	_music_player.play()

func stop_music() -> void:
	_music_key = &""
	_music_player.stop()

func play(name: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStreamWAV = _sfx.get(name)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

## Continuous crowd murmur (looping noise). Call with playing=false to stop.
func loop_crowd(playing := true, volume_db := -18.0) -> void:
	if playing:
		if _crowd_player.stream == null:
			_crowd_player.stream = _make_crowd()
		_crowd_player.volume_db = volume_db
		if not _crowd_player.playing:
			_crowd_player.play()
	else:
		_crowd_player.stop()

func swell_crowd(volume_db := -8.0) -> void:
	## Brief cheer over the ambient bed (e.g. a finish or a big jump).
	play(&"cheer", volume_db)

# --- Sound library ------------------------------------------------------------

func _build_library() -> void:
	_sfx[&"move"] = _tone(660.0, 0.05, "square", 0.5)
	_sfx[&"select"] = _tone(880.0, 0.10, "square", 0.5, 1.5)   # rising
	_sfx[&"back"] = _tone(300.0, 0.10, "square", 0.5, 0.6)
	_sfx[&"beep"] = _tone(500.0, 0.14, "square", 0.4)
	_sfx[&"go"] = _tone(1000.0, 0.30, "square", 0.3)
	_sfx[&"step"] = _tone(180.0, 0.04, "square", 0.7)
	_sfx[&"jump"] = _tone(520.0, 0.12, "sine", 0.4, 2.2)
	_sfx[&"land"] = _noise(0.12, 6.0)
	_sfx[&"whistle"] = _tone(1600.0, 0.35, "sine", 0.2)
	_sfx[&"foul"] = _tone(140.0, 0.35, "square", 0.15)
	_sfx[&"cheer"] = _make_cheer()
	_sfx[&"clang"] = _tone(240.0, 0.18, "square", 0.25, 3.0)   # hurdle clip
	_sfx[&"whoosh"] = _noise(0.22, 3.0)
	_sfx[&"points"] = _tone(784.0, 0.16, "square", 0.4, 1.8)
	_sfx[&"fanfare"] = _make_fanfare()

## A pitched tone. wave = "square"|"sine". decay = exp falloff strength. bend = end/start freq ratio.
func _tone(freq: float, dur: float, wave := "square", decay := 0.5, bend := 1.0) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var prog: float = float(i) / float(max(1, n - 1))
		var f := freq * lerpf(1.0, bend, prog)
		phase += TAU * f / MIX_RATE
		var s: float
		if wave == "sine":
			s = sin(phase)
		else:
			s = 1.0 if sin(phase) >= 0.0 else -1.0
		var env := exp(-decay * prog * 8.0)
		_put_sample(data, i, s * env * 0.55)
	return _wav(data)

func _noise(dur: float, decay := 4.0) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var prog: float = float(i) / float(max(1, n - 1))
		var env := exp(-decay * prog)
		_put_sample(data, i, (randf() * 2.0 - 1.0) * env * 0.5)
	return _wav(data)

func _make_cheer() -> AudioStreamWAV:
	# Filtered noise with a rising-then-falling swell — a short crowd roar.
	var dur := 0.9
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var last := 0.0
	for i in n:
		var prog: float = float(i) / float(max(1, n - 1))
		var swell: float = sin(prog * PI)          # 0..1..0
		var raw := randf() * 2.0 - 1.0
		last = lerpf(last, raw, 0.35)              # low-pass -> softer roar
		_put_sample(data, i, last * swell * 0.6)
	return _wav(data)

func _make_crowd() -> AudioStreamWAV:
	# Longer low-passed noise bed for looping ambience.
	var dur := 2.0
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var last := 0.0
	for i in n:
		var raw := randf() * 2.0 - 1.0
		last = lerpf(last, raw, 0.12)
		_put_sample(data, i, last * 0.5)
	var w := _wav(data)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func _make_fanfare() -> AudioStreamWAV:
	# Three rising notes — victory sting.
	var notes := [523.0, 659.0, 784.0, 1047.0]
	var note_dur := 0.16
	var data := PackedByteArray()
	for ni in notes.size():
		var f: float = notes[ni]
		var n := int(MIX_RATE * note_dur)
		var phase := 0.0
		for i in n:
			var prog: float = float(i) / float(max(1, n - 1))
			phase += TAU * f / MIX_RATE
			var s := 1.0 if sin(phase) >= 0.0 else -1.0
			var env := exp(-1.5 * prog)
			var idx := data.size() / 2
			data.resize(data.size() + 2)
			_put_sample(data, idx, s * env * 0.5)
	return _wav(data)

func _put_sample(data: PackedByteArray, index: int, value: float) -> void:
	var v := int(clampf(value, -1.0, 1.0) * 32767.0)
	data.encode_s16(index * 2, v)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w
