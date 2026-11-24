extends Area2D
# Estalactite presa ao teto: balança quando o herói passa embaixo e despenca. Reaparece depois de alguns segundos.
# A origem é o ponto onde ela encosta no teto (topo central).

var tema := 1
var _estado := 0          # 0 presa, 1 tremendo, 2 caindo, 3 quebrada
var _t := 0.0
var _vel := 0.0
var _origem := Vector2.ZERO
var _spr: Sprite2D
var _sensor: Area2D


func _ready() -> void:
	z_index = 1
	_origem = position
	collision_layer = 16
	collision_mask = 0
	_spr = Sprite2D.new()
	_spr.texture = load("res://arte/objetos/estalactite.png")
	_spr.region_enabled = true
	_spr.region_rect = Rect2(tema * 16, 0, 16, 24)
	_spr.centered = false
	_spr.position = Vector2(-8, 0)
	add_child(_spr)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(8.0, 14.0)
	cs.shape = r
	cs.position = Vector2(0, 12)
	add_child(cs)
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2
	var cs2 := CollisionShape2D.new()
	var r2 := RectangleShape2D.new()
	r2.size = Vector2(22.0, 170.0)
	cs2.shape = r2
	cs2.position = Vector2(0, 100)
	_sensor.add_child(cs2)
	add_child(_sensor)
	_sensor.body_entered.connect(_ao_passar)
	body_entered.connect(_ao_bater)


func _ao_passar(corpo: Node) -> void:
	if _estado == 0 and corpo.is_in_group("jogador"):
		_estado = 1
		_t = 0.0
		Sons.tocar("desmoronar", -10.0)


func _ao_bater(corpo: Node) -> void:
	if _estado == 2 and not corpo.is_in_group("jogador"):
		_quebrar()


func _physics_process(delta: float) -> void:
	_t += delta
	match _estado:
		1:
			_spr.position.x = -8.0 + sin(_t * 70.0) * 1.2
			if _t > 0.45:
				_estado = 2
				_vel = 20.0
				_spr.position.x = -8.0
				collision_mask = 1
		2:
			_vel += 700.0 * delta
			position.y += _vel * delta
			if position.y > _origem.y + 260.0:
				_quebrar()
		3:
			if _t > 5.0:
				position = _origem
				_spr.visible = true
				set_deferred("monitorable", true)
				collision_mask = 0
				_estado = 0


func _quebrar() -> void:
	_estado = 3
	_t = 0.0
	_spr.visible = false
	collision_mask = 0
	set_deferred("monitorable", false)
	Util.particulas(get_parent(), global_position + Vector2(0, 20), Color("#c8f0ff") if tema == 1 else Color("#c8a878"), 10, 30.0, 90.0, 0.5, 220.0, 2.0)
	Sons.tocar_var("estilhaco", -6.0)
