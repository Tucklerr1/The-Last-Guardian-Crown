class_name ClonePrimitivo
extends Node2D
# Ilusão do Cavaleiro Fantasma: parece o chefe, mas some com um golpe e não causa dano ao chefe real.
# Ainda assim ataca junto com o verdadeiro, então vale eliminar as falsas ou saber qual é a real.

var frames: SpriteFrames
var dir := 1
var chao_y := 0.0
var _sprite: AnimatedSprite2D
var _hurt: Area2D
var _morto := false
var _t := 0.0


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.position = Vector2(0, 4)
	_sprite.flip_h = dir < 0
	_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_sprite)
	_sprite.play("aparecer")
	_hurt = Area2D.new()
	_hurt.collision_layer = 4
	_hurt.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(38, 64)
	cs.shape = r
	_hurt.add_child(cs)
	add_child(_hurt)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.88, 0.35)


func _process(delta: float) -> void:
	_t += delta
	if _sprite and not _morto:
		_sprite.modulate.a = 0.82 + 0.08 * sin(_t * 9.0)       # leve tremulação denuncia a cópia


func preparar() -> void:
	if _sprite and not _morto:
		_sprite.play("preparar")


func cortar() -> void:
	if _morto:
		return
	_sprite.play("corte")
	var hit := Area2D.new()
	hit.collision_layer = 16
	hit.collision_mask = 0
	hit.position = Vector2(dir * 40.0, 0)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(76, 58)
	cs.shape = r
	hit.add_child(cs)
	add_child(hit)
	var tw := create_tween()
	tw.tween_interval(0.22)
	tw.tween_callback(hit.queue_free)
	var p = load("res://cenas/projetil.tscn").instantiate()
	p.configurar(Vector2(dir * 165.0, 0.0), "inimigo", Color("#40ffb0"), "lamina", 0.0, 3.0)
	p.position = Vector2(position.x + dir * 34.0, chao_y - 12.0)
	Util.adicionar(get_parent(), p)


func desfazer() -> void:
	if _morto:
		return
	_morto = true
	Util.particulas(get_parent(), global_position, Color("#40ffb0"), 14, 30.0, 90.0, 0.6, -30.0, 2.0)
	queue_free()


func levar_dano(_dano: int, _dir: int) -> bool:
	if _morto:
		return false
	_morto = true
	Sons.tocar_var("estilhaco", -6.0)
	Util.explosao(get_parent(), global_position, Color("#40ffb0"), 0.8)
	Jogo.mensagem.emit("Era uma ilusão!")
	queue_free()
	return true
