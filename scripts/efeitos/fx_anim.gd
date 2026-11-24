class_name FxAnim
extends Sprite2D
# Efeito visual de uma animação só (faísca, anel de choque, erupção...). Some sozinho no fim.

var _fps := 14.0
var _n := 4
var _t := 0.0


# base = true ancora o desenho pela parte de baixo (erupções que nascem do chão)
func configurar(nome: String, frames: int, fps: float, esc: float, flip: bool, cor: Color, base: bool) -> void:
	texture = load("res://arte/efeitos/%s.png" % nome)
	hframes = frames
	_n = frames
	_fps = fps
	scale = Vector2(esc, esc)
	flip_h = flip
	modulate = cor
	z_index = 6
	if base and texture:
		offset = Vector2(0.0, -texture.get_height() * 0.5)


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * _fps)
	if f >= _n:
		queue_free()
		return
	frame = f
