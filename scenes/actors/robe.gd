extends RefCounted
## Recolors the wizard sprite's blue robe and hat (skin, outline and button stay the same).
## Usage: sprite.material = Robe.make(Robe.RED)

const SHADER := preload("res://assets/shaders/hue_swap.gdshader")

# Hue shifts away from the drawn blue robe.
const BLUE := 0.0
const RED := 0.37
const PURPLE := 0.14
const ORANGE := 0.43
const YELLOW := 0.5
const GREEN := 0.69
const TEAL := 0.86
const NPC_COLORS := [PURPLE, ORANGE, GREEN, TEAL, YELLOW]


static func make(hue_shift: float, saturation := 1.0, value := 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("hue_shift", hue_shift)
	mat.set_shader_parameter("saturation", saturation)
	mat.set_shader_parameter("value", value)
	return mat


static func for_slot(slot: int) -> ShaderMaterial:
	return make(RED if slot == 2 else BLUE)
