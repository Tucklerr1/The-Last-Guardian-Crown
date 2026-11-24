extends StaticBody2D
# Plataforma que racha e desmorona pouco depois de você pisar. Volta a aparecer depois. Origem = canto superior esquerdo.

var tema := 2
var _spr: Sprite2D
var _cs: CollisionShape2D
var _estado := 0          # 0 firme, 1 rachando, 2 caída
var _t := 0.0
var _origem := Vector2.ZERO


func _ready() -> void:
	z_index = 1
	collision_layer = 1
	collision_mask = 0
	_origem = position
	_spr = Sprite2D.new()
	_spr.texture = load("res://arte/objetos/plataforma_fragil.png")
	_spr.region_enabled = true
	_spr.centered = false
	add_child(_spr)
	_quadro(0)
	_cs = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(46.0, 8.0)
	_cs.shape = r
	_cs.position = Vector2(24, 7)
	add_child(_cs)
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2
	var cs2 := CollisionShape2D.new()
	var r2 := RectangleShape2D.new()
	r2.size = Vector2(42.0, 8.0)
	cs2.shape = r2
	cs2.position = Vector2(24, -2)
	sensor.add_child(cs2)
	add_child(sensor)
	sensor.body_entered.connect(_ao_pisar)


func _quadro(f: int) -> void:
	_spr.region_rect = Rect2(f * 48, tema * 16, 48, 16)


func _ao_pisar(corpo: Node) -> void:
	if _estado == 0 and corpo.is_in_group("jogador"):
		_estado = 1
		_t = 0.0
		_quadro(1)
		Sons.tocar_var("desmoronar", -8.0)


func _physics_process(delta: float) -> void:
	_t += delta
	match _estado:
		1:
			_spr.position.x = sin(_t * 60.0) * 0.8
			if _t > 0.6:
				_estado = 2
				_t = 0.0
				_spr.position.x = 0.0
				_cs.set_deferred("disabled", true)
				Util.particulas(get_parent(), global_position + Vector2(24, 8), Color("#d8b888"), 10, 20.0, 70.0, 0.6, 200.0, 2.2)
		2:
			_spr.position.y += 140.0 * delta
			_spr.modulate.a = maxf(0.0, 1.0 - _t * 1.8)
			if _t > 3.4:
				_estado = 0
				_spr.position = Vector2.ZERO
				_spr.modulate.a = 1.0
				_quadro(0)
				_cs.set_deferred("disabled", false)
