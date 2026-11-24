extends Area2D
# Mola (cogumelo-mola, cristal, etc.): lança o herói para o alto. Origem = canto superior esquerdo do bloco.

var tema := 0
var forca := -480.0
var _spr: Sprite2D
var _t := 0.0


func _ready() -> void:
	z_index = 1
	collision_layer = 0
	collision_mask = 2
	_spr = Sprite2D.new()
	_spr.texture = load("res://arte/objetos/mola.png")
	_spr.region_enabled = true
	_spr.centered = false
	add_child(_spr)
	_quadro(0)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12.0, 6.0)
	cs.shape = r
	cs.position = Vector2(8, 9)
	add_child(cs)
	body_entered.connect(_ao_entrar)


func _quadro(f: int) -> void:
	_spr.region_rect = Rect2(f * 16, tema * 16, 16, 16)


func _ao_entrar(corpo: Node) -> void:
	if not corpo.is_in_group("jogador") or corpo.morto:
		return
	if corpo.velocity.y < -60.0:
		return
	corpo.impulso(forca)
	_quadro(2)
	_t = 0.28
	Sons.tocar_var("mola")
	Util.particulas(get_parent(), global_position + Vector2(8, 4), Color(1.0, 1.0, 0.8), 6, 30.0, 70.0, 0.4, 100.0, 1.5)


func _process(delta: float) -> void:
	if _t > 0.0:
		_t -= delta
		if _t <= 0.0:
			_quadro(0)
