extends StaticBody2D
# Portão de ferro que tranca a arena do chefe durante a luta. Origem = topo do portão; altura em pixels.

var altura := 208.0
var cor := Color("#3a3050")
var _prog := 0.0
var _cs: CollisionShape2D


func _ready() -> void:
	z_index = 3
	collision_layer = 1
	collision_mask = 0
	_cs = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12.0, altura)
	_cs.shape = r
	_cs.position = Vector2(0.0, altura * 0.5)
	_cs.disabled = true
	add_child(_cs)


func fechar() -> void:
	_cs.set_deferred("disabled", false)
	Sons.tocar("impacto", -4.0)
	Jogo.tremer(2.5, 0.25)
	var tw := create_tween()
	tw.tween_method(_definir, _prog, 1.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(Jogo.tremer.bind(3.0, 0.2))


func abrir() -> void:
	Sons.tocar("porta")
	var tw := create_tween()
	tw.tween_method(_definir, _prog, 0.0, 0.8)
	tw.tween_callback(_cs.set_deferred.bind("disabled", true))


func _definir(v: float) -> void:
	_prog = v
	queue_redraw()


func _draw() -> void:
	var h := altura * _prog
	if h < 1.0:
		return
	for i in 4:
		var x := -6.0 + float(i) * 4.0
		draw_rect(Rect2(x, 0.0, 2.5, h), cor.lightened(0.15))
		draw_rect(Rect2(x, 0.0, 1.0, h), cor.lightened(0.45))
	for fr in [0.2, 0.55, 0.85]:
		draw_rect(Rect2(-7.0, h * fr, 14.0, 3.0), cor)
	draw_rect(Rect2(-7.0, 0.0, 14.0, 4.0), Color("#c8a63a"))
