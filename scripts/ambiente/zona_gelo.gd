extends Area2D
# Piso de gelo: o herói acelera e freia devagar enquanto estiver sobre esta zona. Origem = canto superior esquerdo do piso.

var larg := 4
var _brilho := 0.0


func _ready() -> void:
	z_index = 2
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(larg * 16.0, 22.0)
	cs.shape = r
	cs.position = Vector2(larg * 8.0, -11.0)
	add_child(cs)
	body_entered.connect(_entrou)
	body_exited.connect(_saiu)
	_brilho = randf() * 6.0


func _entrou(c: Node) -> void:
	if c.is_in_group("jogador"):
		c.sobre_gelo += 1


func _saiu(c: Node) -> void:
	if c.is_in_group("jogador"):
		c.sobre_gelo = maxi(c.sobre_gelo - 1, 0)


func _process(delta: float) -> void:
	_brilho += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, larg * 16.0, 2.0), Color(0.75, 0.93, 1.0, 0.55))
	for i in larg:
		var x := fmod(_brilho * 14.0 + float(i) * 16.0, larg * 16.0)
		draw_line(Vector2(x, 0.0), Vector2(x + 4.0, 0.0), Color(1, 1, 1, 0.9), 1.0)
