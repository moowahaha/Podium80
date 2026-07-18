extends BaseScreen
## First screen on boot: "PLAYER 1 — PRESS START".
##
## Whichever controller presses START is designated Player 1 for the session (Platform.claim_player1) —
## an explicit choice instead of arbitrary pad connection order (which is a race at boot). In 1-player
## mode that pad drives everything; in 2-player the other connected pad becomes Player 2. The keyboard
## (Enter) claims P1 too, so the game stays testable without a controller.

const NEXT := "res://src/menus/PlayerSelect.tscn"

var _t := 0.0
var _done := false
var _prompt: Label

func _screen_ready() -> void:
	# Shared two-colour PODIUM '80 wordmark, same as the title.
	UI.add_podium_logo(self, 70.0, 110)

	var p1 := UI.center_label("PLAYER 1", 44, Palette.HIGHLIGHT)
	p1.position = Vector2(0, 300)
	p1.size = Vector2(Palette.BASE_WIDTH, 56)
	add_child(p1)

	_prompt = UI.center_label("PRESS  START", 30, Palette.PAPER)
	_prompt.position = Vector2(0, 380)
	_prompt.size = Vector2(Palette.BASE_WIDTH, 40)
	add_child(_prompt)
	# (no crowd bed on menus — the stadium ambience belongs to the competitions only)

func _process(delta: float) -> void:
	_t += delta
	_prompt.modulate.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(_t * 4.0))   # pulse the prompt
	queue_redraw()

## START is reserved (Platform doesn't map it), so read it raw here: a joypad START button, or Enter on
## the keyboard. The device that presses claims Player 1.
func _input(event: InputEvent) -> void:
	if _done:
		return
	var device := -2   # -2 = no claim this event; -1 = keyboard; >=0 = a joypad device
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		device = event.device
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		device = -1
	if device == -2:
		return
	_done = true
	if device >= 0:
		Platform.claim_player1(device)   # this pad = Player 1; the other pad = Player 2
	AudioBus.play(&"select")
	SceneRouter.goto_scene(NEXT)
