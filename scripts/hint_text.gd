extends RefCounted
## Milestone E: key hints for the screens outside the game world (title, settlement picker, the
## opening), in whatever is bound on the device in use. A template names actions in braces —
## "{nav} choose   {use} confirm   {back} back" — and fill() swaps in the Settings autoload's
## names, upper-cased to match these screens ("SPACE" / "A", "ESC" / "B", "UP/DOWN" / "D-PAD").
## Without the autoload (bare tools) the keyboard defaults are used.

const FALLBACK := {"use": "Space", "back": "Esc", "nav": "Up/Down", "delete": "Q"}
const ACTIONS := {"use": "use_tool", "delete": "build_cycle"}


static func fill(node: Node, template: String) -> String:
	var settings: Node = node.get_node_or_null("/root/Settings") if node != null and node.is_inside_tree() else null
	var out := template
	for key in FALLBACK:
		var token := "{%s}" % key
		if not out.contains(token):
			continue
		var name := String(FALLBACK[key])
		if settings != null:
			match String(key):
				"back":
					name = String(settings.back_prompt())
				"nav":
					name = String(settings.nav_prompt())
				_:
					var bound := String(settings.prompt(String(ACTIONS[key])))
					if bound != "":
						name = bound
		out = out.replace(token, name.to_upper())
	return out


## Calls `refresh` whenever the player switches between keyboard and pad.
static func follow_device(node: Node, refresh: Callable) -> void:
	var settings: Node = node.get_node_or_null("/root/Settings")
	if settings != null and settings.has_signal("input_device_changed"):
		settings.input_device_changed.connect(func(_pad: bool) -> void:
			if is_instance_valid(node):
				refresh.call())
