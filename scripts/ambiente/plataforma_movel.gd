extends AnimatableBody2D
# Plataforma que vai e volta (horizontal ou vertical). Dá para atravessar por baixo (colisão de mão única).
# Origem = canto superior esquerdo (48x16 px).

var tema := 0
var eixo := Vector2.RIGHT
var amplitude := 40.0
var periodo := 4.0
var fase := 0.0
var _origem := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	z_index = 1
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	_origem = position
	_t = fase
	var spr := Sprite2D.new()
	spr.texture = load("res://arte/objetos/plataforma_movel.png")
	spr.region_enabled = true
	spr.region_rect = Rect2(0, tema * 16, 48, 16)
	spr.centered = false
	add_child(spr)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(46.0, 7.0)
	cs.shape = r
	cs.position = Vector2(24, 6.5)
	cs.one_way_collision = true
	add_child(cs)


func _physics_process(delta: float) -> void:
	_t += delta
	position = _origem + eixo * amplitude * sin(_t * TAU / periodo)
