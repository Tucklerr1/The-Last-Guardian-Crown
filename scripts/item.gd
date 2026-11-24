extends CharacterBody2D
# Item que cai dos inimigos (ou fica no cenário): "moeda" ou "coracao" (vida extra).

var tipo := "moeda"
var valor := 5
var pronto := false
var estatico := false         # item colocado no cenário: flutua parado
var _t := 0.0
var _y0 := 0.0
var _espera := 0.35

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var coleta: Area2D = $Coleta


func iniciar(t: String, v: int, parado := false) -> void:
	tipo = t
	valor = v
	estatico = parado


func _ready() -> void:
	sprite.sprite_frames = load("res://arte/frames/item_%s.tres" % tipo)
	sprite.play("girar")
	sprite.frame = randi() % 4
	_y0 = position.y
	_t = randf() * TAU
	if estatico:
		velocity = Vector2.ZERO
		_espera = 0.0
		collision_mask = 0
	else:
		velocity = Vector2(randf_range(-60.0, 60.0), randf_range(-190.0, -110.0))


func _physics_process(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta
		if _espera <= 0.0:
			pronto = true
	if estatico:
		_t += delta * 3.0
		sprite.position.y = -4.0 + sin(_t) * 1.5
	else:
		velocity.y += 700.0 * delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
	if not pronto and not estatico:
		return
	for corpo in coleta.get_overlapping_bodies():
		if corpo.is_in_group("jogador"):
			_coletar()
			return


func _coletar() -> void:
	set_physics_process(false)
	if tipo == "moeda":
		Jogo.ganhar_moedas(valor)
		Sons.tocar("moeda", 0.0, randf_range(0.95, 1.12))
		Util.particulas(get_parent(), global_position, Color("#ffe27a"), 6, 30.0, 80.0, 0.35, 120.0, 1.6)
	else:
		Jogo.ganhar_coracao(valor)
		Sons.tocar("coracao")
		Util.particulas(get_parent(), global_position, Color("#ff6a8a"), 10, 30.0, 90.0, 0.5, 100.0, 2.0)
	queue_free()
