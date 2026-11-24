extends Area2D
# Passagem secreta: parece uma parede comum, mas o herói atravessa. Ao entrar, a "parede" some e revela o tesouro.
# Origem = canto superior esquerdo da área (em pixels); `cel_w` x `cel_h` blocos.

var cel_w := 4
var cel_h := 2
var tema := 0
var _tex: Texture2D
var _revelado := false
var _alfa := 1.0


func _ready() -> void:
	z_index = 4
	collision_layer = 0
	collision_mask = 2
	_tex = load("res://arte/tiles/tileset.png")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(cel_w * 16.0, cel_h * 16.0)
	cs.shape = r
	cs.position = r.size * 0.5
	add_child(cs)
	body_entered.connect(_ao_entrar)
	queue_redraw()


func _ao_entrar(corpo: Node) -> void:
	if _revelado or not corpo.is_in_group("jogador"):
		return
	_revelado = true
	Sons.tocar("segredo")
	Jogo.mensagem.emit("Passagem secreta encontrada!")
	Util.particulas(get_parent(), global_position + Vector2(cel_w * 8.0, cel_h * 8.0), Color("#ffe27a"), 20, 30.0, 100.0, 0.8, 40.0, 2.0)
	var tw := create_tween()
	tw.tween_method(_definir_alfa, 1.0, 0.0, 0.5)
	tw.tween_callback(queue_free)


func _definir_alfa(a: float) -> void:
	_alfa = a
	queue_redraw()


func _draw() -> void:
	for i in cel_w:
		for j in cel_h:
			var col := 1 if (i + j) % 3 != 0 else 5
			draw_texture_rect_region(_tex, Rect2(i * 16, j * 16, 16, 16), Rect2(col * 16, tema * 16, 16, 16), Color(1, 1, 1, _alfa))
