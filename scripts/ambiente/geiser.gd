extends Area2D
# Gêiser de lava: borbulha (aviso), depois joga uma coluna de fogo para cima. Origem = base no chão.

var periodo := 3.6
var desloc := 0.0
var altura := 78.0
var _t := 0.0
var _estado := 0          # 0 quieto, 1 aviso, 2 erupção
var _luz: PointLight2D


func _ready() -> void:
	z_index = 1
	collision_layer = 16
	collision_mask = 0
	monitorable = false
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12.0, altura)
	cs.shape = r
	cs.position = Vector2(0.0, -altura * 0.5)
	add_child(cs)
	_t = desloc
	_luz = Util.luz(self, Vector2(0, -8), Color(1.0, 0.5, 0.15), 0.0, 0.7)


func _process(delta: float) -> void:
	_t += delta
	var c := fmod(_t, periodo)
	var novo := 0
	if c > periodo - 0.75:
		novo = 2
	elif c > periodo - 1.4:
		novo = 1
	if novo != _estado:
		_estado = novo
		set_deferred("monitorable", novo == 2)
		if novo == 2:
			var tela := get_viewport().get_visible_rect().size.x
			var jog := get_tree().get_first_node_in_group("jogador")
			if jog and absf(jog.global_position.x - global_position.x) < tela:
				Sons.tocar_var("geiser", -6.0)
				Jogo.tremer(1.0, 0.1)
	_luz.energy = 0.9 if _estado == 2 else (0.25 if _estado == 1 else 0.0)
	queue_redraw()


func _draw() -> void:
	var c := fmod(_t, periodo)
	draw_rect(Rect2(-8, -3, 16, 3), Color("#4a2a2a"))
	draw_rect(Rect2(-5, -4, 10, 2), Color("#ff7a1a"))
	if _estado == 1:
		var k := (c - (periodo - 1.4)) / 0.65
		for i in 3:
			var y := -4.0 - fmod(_t * 30.0 + float(i) * 6.0, 14.0) * (0.4 + 0.6 * k)
			draw_circle(Vector2(sin(_t * 9.0 + float(i) * 2.0) * 3.0, y), 1.5 + k, Color(1.0, 0.65, 0.2, 0.9))
		if int(_t * 14.0) % 2 == 0:
			draw_rect(Rect2(-6, -6, 12, 2), Color(1.0, 0.3, 0.1, 0.8))
	elif _estado == 2:
		var e := c - (periodo - 0.75)
		var h := altura * clampf(e / 0.14, 0.0, 1.0)
		if e > 0.55:
			h *= clampf(1.0 - (e - 0.55) / 0.2, 0.0, 1.0)
		var larg := 6.0 + sin(_t * 40.0) * 1.0
		draw_rect(Rect2(-larg, -h, larg * 2.0, h), Color("#ff5a1a"))
		draw_rect(Rect2(-larg * 0.6, -h, larg * 1.2, h), Color("#ffb02a"))
		draw_rect(Rect2(-larg * 0.25, -h, larg * 0.5, h), Color("#fff2a0"))
		draw_circle(Vector2(0, -h), larg + 2.0, Color("#ffd24a"))
