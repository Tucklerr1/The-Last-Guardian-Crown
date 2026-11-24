class_name Aviso
extends Node2D
# Marcação visual de um ataque que está para acontecer (telegrafar = o jogador consegue reagir).
# formas: "retangulo", "circulo", "linha"

var forma := "retangulo"
var tamanho := Vector2(32, 8)
var cor := Color(1.0, 0.3, 0.2)
var duracao := 0.8
var _t := 0.0


func configurar(f: String, tam: Vector2, c: Color, dur: float) -> void:
	forma = f
	tamanho = tam
	cor = c
	duracao = maxf(dur, 0.05)


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duracao:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / duracao, 0.0, 1.0)
	var pisca := 0.30 + 0.35 * absf(sin(_t * 16.0))
	var c := Color(cor.r, cor.g, cor.b, pisca)
	var forte := Color(cor.r, cor.g, cor.b, 0.85)
	match forma:
		"retangulo":
			var r := Rect2(-tamanho.x * 0.5, -tamanho.y * 0.5, tamanho.x, tamanho.y)
			draw_rect(r, c)
			draw_rect(Rect2(r.position, Vector2(tamanho.x * k, tamanho.y)), Color(cor.r, cor.g, cor.b, 0.55))
			draw_rect(r, forte, false, 1.0)
		"circulo":
			var raio := tamanho.x * 0.5
			draw_arc(Vector2.ZERO, raio, 0.0, TAU, 24, forte, 1.5)
			draw_circle(Vector2.ZERO, raio * k, Color(cor.r, cor.g, cor.b, 0.35))
		"linha":
			draw_line(Vector2.ZERO, Vector2(tamanho.x, 0.0), c, maxf(tamanho.y, 1.0))
			draw_line(Vector2.ZERO, Vector2(tamanho.x * k, 0.0), forte, maxf(tamanho.y, 1.0))
