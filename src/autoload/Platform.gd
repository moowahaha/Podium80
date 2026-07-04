extends Node
## Input + platform layer for Podium '80.
##
## Builds the InputMap at runtime so it always matches the MeboboxOS controller contract exactly and
## there is a single source of truth. On the console the game is pad-blind and driven by a synthetic
## KEYBOARD (the pad->key injector, agent/mebobox-input.py), so the keyboard bindings below MUST match
## the manifest.json `controls` / `controlsP2` maps. We ALSO bind the physical gamepad (per-device) so
## the game is testable off-console with real pads; on the console those never fire (pad hidden), so
## there is no double-input.
##
## Logical buttons (the only controls the console exposes): D-pad + A + B + LB + RB.
##   P1 keys: arrows, A=Space, B=B, LB=Q, RB=W          (matches manifest controls)
##   P2 keys: I/K/J/L,      A=F, B=G, LB=H, RB=N          (matches manifest controlsP2)
## START/SELECT are reserved by the OS (pause / hold-to-quit) and never used by gameplay.

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
# Logical button -> standard-gamepad button index (W3C / SDL layout the console normalises to).
const JOY := {
	&"up": JOY_BUTTON_DPAD_UP, &"down": JOY_BUTTON_DPAD_DOWN,
	&"left": JOY_BUTTON_DPAD_LEFT, &"right": JOY_BUTTON_DPAD_RIGHT,
	&"a": JOY_BUTTON_A, &"b": JOY_BUTTON_B,
	&"lb": JOY_BUTTON_LEFT_SHOULDER, &"rb": JOY_BUTTON_RIGHT_SHOULDER,
}

func _enter_tree() -> void:
	_build_input_map()

func _build_input_map() -> void:
	_add_player_actions(0, P1_KEYS)
	_add_player_actions(1, P2_KEYS)
	# Make standard Control focus navigation respond to the console's real keys/buttons too.
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
		InputMap.action_add_event(action, _key(keys[btn]))          # physical (layout-independent, off-console)
		InputMap.action_add_event(action, _key_logical(keys[btn]))  # logical keycode (the console's key injector)
		InputMap.action_add_event(action, _joy(JOY[btn], player))

func _key(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	return e

## Same key, matched by its logical keycode — this is what the console's pad->key injector emits.
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
