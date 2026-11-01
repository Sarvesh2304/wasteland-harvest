extends RefCounted
## Measuring wrapped text for code-laid-out UI (2026-10-08). A wrapped Label reports one line
## until a layout pass has run, so a panel that places things under a paragraph measures it with
## the font instead: the line count at that width, times the line height plus the theme's
## line_spacing (the pixel font is 8 px with 3 px between lines, so 11 px a line).

## Lines `text` wraps to at `width` in `label`'s font.
static func line_count(label: Control, text: String, width: float) -> int:
	if text == "":
		return 0
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y
	return maxi(1, int(round(h / maxf(font.get_height(size), 1.0))))


## Pixel height of `text` wrapped at `width` (no trailing line gap).
static func wrapped_height(label: Control, text: String, width: float) -> float:
	var n := line_count(label, text, width)
	if n == 0:
		return 0.0
	var font := label.get_theme_font("font")
	var line := font.get_height(label.get_theme_font_size("font_size"))
	return float(n) * line + float(n - 1) * float(label.get_theme_constant("line_spacing"))
