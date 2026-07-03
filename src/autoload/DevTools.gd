extends Node
## Development-only helpers, inert unless a dev flag is passed (ships harmlessly). Flags:
##   --scene res://path.tscn      load this scene at boot (instead of the main scene)
##   --sim N                      start a USSR championship and simulate N events first
##   --noadvance                  after --sim, leave the event index on the last completed event
##                                (for verifying the results screen)
##   --shot out.png [--shot-delay S]   render a few frames, save a screenshot, then quit
## e.g. godot --sim 5 --scene res://src/menus/Podium.tscn --shot podium.png

var _shot_path := ""
var _scene := ""
var _sim := 0
var _event := -1
var _noadvance := false
var _delay := 1.2
var _armed := false

func _ready() -> void:
	var args := OS.get_cmdline_args()
	for i in args.size():
		match args[i]:
			"--shot":
				if i + 1 < args.size(): _shot_path = args[i + 1]
			"--shot-delay":
				if i + 1 < args.size(): _delay = float(args[i + 1])
			"--scene":
				if i + 1 < args.size(): _scene = args[i + 1]
			"--sim":
				if i + 1 < args.size(): _sim = int(args[i + 1])
			"--event":
				if i + 1 < args.size(): _event = int(args[i + 1])
			"--noadvance":
				_noadvance = true

	if "--runtest" in args:
		_run_engine_test()
		get_tree().quit()
		return

	if _sim > 0:
		Game.start_championship([CountryData.all_ids()[0]])
		for e in _sim:
			Game.submit_event({})
			var is_last := e == _sim - 1
			if not (is_last and _noadvance) and not Game.is_championship_over():
				Game.advance_event()

	if _scene != "" and _sim == 0 and Game.participants.is_empty():
		Game.start_championship([CountryData.all_ids()[0]])   # so event scenes have a championship
	if _event >= 0:
		Game.current_event_index = clampi(_event, 0, Game.event_count() - 1)

	if _scene != "":
		call_deferred("_change")

	_armed = _shot_path != ""
	set_process(_armed)

func _change() -> void:
	get_tree().change_scene_to_file(_scene)

## Simulate the sprint RunEngine at several tap cadences to check the fatigue balance: a good human
## rhythm should give a realistic 100m time, and impossible mashing should NOT keep scaling down.
func _run_engine_test() -> void:
	print("--- RunEngine 100m @ cadences ---")
	for cadence in [5.0, 7.0, 9.0, 12.0, 16.0, 25.0]:
		var eng := RunEngine.new()
		eng.start()
		var dt := 1.0 / 60.0
		var t := 0.0
		var tap_acc := 0.0
		var which := true
		var interval: float = 1.0 / float(cadence)
		while eng.distance < 100.0 and t < 30.0:
			tap_acc += dt
			while tap_acc >= interval:
				tap_acc -= interval
				if which: eng.tap_a()
				else: eng.tap_b()
				which = not which
			eng.update(dt)
			t += dt
		print("  %5.1f taps/s -> %6.2fs   (taps=%d, topspeed~%.1f)" % [cadence, t, eng.taps, eng.max_speed * eng.speed_ratio()])

func _process(delta: float) -> void:
	if not _armed:
		return
	_delay -= delta
	if _delay <= 0.0:
		_armed = false
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var err := img.save_png(_shot_path)
		if err != OK:
			push_error("DevTools: screenshot failed (%d) -> %s" % [err, _shot_path])
		else:
			print("DevTools: saved screenshot -> ", _shot_path)
		get_tree().quit()
