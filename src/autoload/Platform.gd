extends Node
## Input + platform layer for Podium '80.
##
## Builds the InputMap at runtime, so there's a single source of truth. The game reads BOTH the
## keyboard and physical gamepads, so it plays with either. Two players use two gamepads (or the two
## keyboard maps below when developing): player 1 is the first-connected pad, player 2 the next. Logical buttons are D-pad + A + B + LB + RB — START/SELECT are reserved for
## pause / hold-to-quit and never used by gameplay.
##   P1 keys: arrows, A=Space, B=B, LB=Q, RB=W
##   P2 keys: I/K/J/L,      A=F, B=G, LB=H, RB=N

const BUTTONS: Array[StringName] = [&"up", &"down", &"left", &"right", &"a", &"b", &"lb", &"rb"]

# Per-player keyboard keycode for each logical button.
const P1_KEYS := {
	&"up": KEY_UP, &"down": KEY_DOWN, &"left": KEY_LEFT, &"right": KEY_RIGHT,
	&"a": KEY_SPACE, &"b": KEY_B, &"lb": KEY_Q, &"rb": KEY_W,
}
const P2_KEYS := {
	&"up": KEY_I, &"down": KEY_K, &"left": KEY_J, &"right": KEY_L,
	&"a": KEY_F, &"b": KEY_G, &"lb": KEY_H, &"rb": KEY_N,
}
# Logical button -> standard-gamepad button index (W3C / SDL layout). We rely on the platform's
# controller database to normalise each pad to these standard indices, so we don't remap per-controller.
const JOY := {
	&"up": JOY_BUTTON_DPAD_UP, &"down": JOY_BUTTON_DPAD_DOWN,
	&"left": JOY_BUTTON_DPAD_LEFT, &"right": JOY_BUTTON_DPAD_RIGHT,
	&"a": JOY_BUTTON_A, &"b": JOY_BUTTON_B,
	&"lb": JOY_BUTTON_LEFT_SHOULDER, &"rb": JOY_BUTTON_RIGHT_SHOULDER,
}

# Player slot -> the Godot joypad device id currently bound to it (-1 = none).
var _pad_slot := [-1, -1]

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection)
	_assign_pads()

func _enter_tree() -> void:
	# React to input the instant it arrives instead of accumulating it to the render frame — noticeably
	# snappier for the alternate-tap running (at a small CPU cost).
	Input.use_accumulated_input = false
	_build_input_map()

func _build_input_map() -> void:
	_add_player_actions(0, P1_KEYS)
	_add_player_actions(1, P2_KEYS)
	# Let standard Control focus navigation respond to the same accept/cancel keys.
	_ensure_event(&"ui_accept", _key(KEY_SPACE))
	_ensure_event(&"ui_accept", _key_logical(KEY_SPACE))
	_ensure_event(&"ui_cancel", _key(KEY_B))
	_ensure_event(&"ui_cancel", _key_logical(KEY_B))

func _add_player_actions(player: int, keys: Dictionary) -> void:
	for btn in BUTTONS:
		var action := act(player, btn)
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.5)
		InputMap.action_add_event(action, _key(keys[btn]))          # physical keycode (layout-independent)
		InputMap.action_add_event(action, _key_logical(keys[btn]))  # logical keycode (some input paths deliver keys this way)
		# Gamepad events bind to a device dynamically (see _assign_pads) so P1/P2 track the actual
		# connected pads and survive hot-plug/unplug — never a hardcoded device index.

func _key(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	return e

## Same key, matched by its logical keycode (some input paths deliver keys this way rather than by scancode).
func _key_logical(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode
	return e

func _joy(button: JoyButton, device: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = device
	return e

func _ensure_event(action: StringName, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)

# --- Gamepad device -> player assignment --------------------------------------
# A pad's Godot device id isn't a stable P1/P2 (it depends on what else is plugged in and on connection
# order), so we assign at runtime: P1 = the first-connected pad, P2 = the next, rebinding on every
# connect/disconnect — so unplugging a device before or during play just re-picks the players.
func _on_joy_connection(_device: int, _connected: bool) -> void:
	_assign_pads()

func _assign_pads() -> void:
	var pads := Input.get_connected_joypads()   # connected device ids, ascending (~ connection order)
	for slot in 2:
		var dev: int = pads[slot] if slot < pads.size() else -1
		if dev != _pad_slot[slot]:
			_pad_slot[slot] = dev
			_bind_joy(slot, dev)

## (Re)bind player `player`'s gamepad events to `device` (-1 = none), leaving the keyboard events intact.
func _bind_joy(player: int, device: int) -> void:
	for btn in BUTTONS:
		var action := act(player, btn)
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton:
				InputMap.action_erase_event(action, ev)
		if device >= 0:
			InputMap.action_add_event(action, _joy(JOY[btn], device))

# --- Query API (players are 0-indexed) ----------------------------------------

## The InputMap action name for a player's logical button, e.g. act(0, &"a") -> &"p1_a".
func act(player: int, button: StringName) -> StringName:
	return StringName("p%d_%s" % [player + 1, button])

func pressed(player: int, button: StringName) -> bool:
	return Input.is_action_pressed(act(player, button))

func just_pressed(player: int, button: StringName) -> bool:
	return Input.is_action_just_pressed(act(player, button))

func just_released(player: int, button: StringName) -> bool:
	return Input.is_action_just_released(act(player, button))
