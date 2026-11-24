extends Area2D
# Perigo fixo do cenário. modo "espinho" (machuca ao encostar) ou "lava" (queima e devolve ao último ponto seguro).
# `resgata` = true em fossos: tira um coração e leva o herói de volta ao chão firme (sem ficar preso).
# A origem do nó é o canto superior esquerdo do primeiro bloco.

var modo := "espinho"
var tema := 0
var larg := 1           # largura em blocos
var resgata := false
var _t := 0.0
var _tex: Texture2D


func _ready() -> void:
	z_index = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	if modo == "lava":
		_tex = load("res://arte/objetos/lava.png")
		r.size = Vector2(larg * 16.0, 10.0)
		cs.position = Vector2(larg * 8.0, 9.0)
		resgata = true
	else:
		_tex = load("res://arte/objetos/espinhos.png")
		r.size = Vector2(larg * 16.0 - 4.0, 8.0)
		cs.position = Vector2(larg * 8.0, 11.0)
	cs.shape = r
	add_child(cs)
	if resgata:
		collision_layer = 0
		collision_mask = 2
		body_entered.connect(_ao_entrar)
	else:
		collision_layer = 16    # o herói detecta e leva dano pelo HurtBox
		collision_mask = 0
	if modo == "lava":
		Util.luz(self, Vector2(larg * 8.0, 0.0), Color(1.0, 0.5, 0.2), 0.7, 0.45 + 0.1 * float(mini(larg, 8)))
	queue_redraw()


func _ao_entrar(corpo: Node) -> void:
	if corpo.is_in_group("jogador"):
		if modo == "lava":
			Util.particulas(get_parent(), corpo.global_position, Color("#ff9a2a"), 14, 40.0, 120.0, 0.6, 200.0, 2.0)
		Sons.tocar("espinho")
		corpo.resgatar()


func _process(delta: float) -> void:
	if modo == "lava":
		_t += delta
		queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	for i in larg:
		if modo == "lava":
			var f := int(_t * 6.0 + float(i)) % 4
			draw_texture_rect_region(_tex, Rect2(i * 16, 0, 16, 16), Rect2(f * 16, 0, 16, 16))
		else:
			draw_texture_rect_region(_tex, Rect2(i * 16, 0, 16, 16), Rect2(tema * 16, 0, 16, 16))
