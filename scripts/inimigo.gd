extends CharacterBody2D
# Inimigo comum. Cada "tipo" tem sprite, animações, atributos e comportamento próprios (ver DADOS).
# Quem cria define `tipo` antes de adicionar à cena (veja mundo.gd).
#   cogumelo: salta em arco | vespa: voa e solta esporos | lobo: uiva e investe | boneco: arremessa bolas de neve
#   escaravelho: escudo frontal | cobra: emboscada da areia | esqueleto: arqueiro que recua
#   fantasma: some e reaparece atirando | salamandra: cospe fogo em arco | morcego: mergulho em rasante

const GRAVIDADE := 900.0

const DADOS := {
	"cogumelo": {"frames": "m1_cogumelo", "vida": 2, "corpo": Vector2(14, 13), "moedas": 2, "cor": Color("#d6372f"), "base": "patrulha"},
	"vespa": {"frames": "m1_vespa", "vida": 2, "corpo": Vector2(12, 11), "moedas": 3, "cor": Color("#e8c32a"), "base": "voa", "voa": true},
	"lobo": {"frames": "m2_lobo", "vida": 3, "corpo": Vector2(22, 13), "moedas": 3, "cor": Color("#cfe0f2"), "base": "patrulha"},
	"boneco": {"frames": "m2_boneco", "vida": 3, "corpo": Vector2(13, 24), "moedas": 3, "cor": Color("#f2f8ff"), "base": "patrulha"},
	"escaravelho": {"frames": "m3_escaravelho", "vida": 4, "corpo": Vector2(22, 12), "moedas": 4, "cor": Color("#e0a82a"), "base": "andar"},
	"cobra": {"frames": "m3_cobra", "vida": 3, "corpo": Vector2(12, 24), "moedas": 4, "cor": Color("#7aa83a"), "base": "enterrada"},
	"esqueleto": {"frames": "m4_esqueleto", "vida": 3, "corpo": Vector2(10, 25), "moedas": 3, "cor": Color("#e6dfc8"), "base": "combate"},
	"fantasma": {"frames": "m4_fantasma", "vida": 2, "corpo": Vector2(12, 18), "moedas": 3, "cor": Color("#c9d4f2"), "base": "voa", "voa": true},
	"salamandra": {"frames": "m5_salamandra", "vida": 4, "corpo": Vector2(22, 12), "moedas": 4, "cor": Color("#ff7a1a"), "base": "patrulha"},
	"morcego": {"frames": "m5_morcego", "vida": 2, "corpo": Vector2(14, 12), "moedas": 3, "cor": Color("#e8662a"), "base": "paira", "voa": true},
}

var tipo := "cogumelo"
var vida := 0                    # 0 = usar a vida padrão do tipo
var dropa := true
var agressivo := false           # invocado por chefe: já nasce perseguindo
var estado := "patrulha"
var dir := -1
var morto := false
var t := 0.0
var cd := 0.0
var voa := false
var ancora := Vector2.ZERO
var escudo := false
var _info: Dictionary = {}
var _corpo_tam := Vector2(12, 12)
var _stun := 0.0
var _alvo_fixo := Vector2.ZERO
var _fez := false
var _giro := 0.0
var _fase := 0.0
var alvo: Node2D

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sensor: RayCast2D = $SensorBorda
@onready var hurtbox: Area2D = $HurtBox
@onready var contato: Area2D = $Ataque
@onready var corpo: CollisionShape2D = $Corpo


func _ready() -> void:
	add_to_group("inimigos")
	_info = DADOS[tipo]
	_corpo_tam = _info["corpo"]
	voa = _info.get("voa", false)
	estado = _info["base"]
	if vida <= 0:
		vida = _info["vida"]
	sprite.sprite_frames = load("res://arte/frames/%s.tres" % _info["frames"])
	_aplicar_formas()
	if voa:
		sprite.position = Vector2(0, 2)
	else:
		sprite.position = Vector2(0, _corpo_tam.y * 0.5 - 14.5)
		position.y -= _corpo_tam.y * 0.5          # quem cria informa a altura do chão
	ancora = position
	alvo = get_tree().get_first_node_in_group("jogador")
	dir = 1 if randf() < 0.5 else -1
	_fase = randf() * TAU
	_anim("parado" if sprite.sprite_frames.has_animation("parado") else sprite.sprite_frames.get_animation_names()[0])
	if tipo == "cobra":
		_ativar(false, false)
	if tipo == "escaravelho":
		escudo = true
	if agressivo and tipo == "fantasma":
		estado = "voa"


func _aplicar_formas() -> void:
	var f1 := RectangleShape2D.new()
	f1.size = _corpo_tam
	corpo.shape = f1
	var f2 := RectangleShape2D.new()
	f2.size = _corpo_tam + Vector2(4, 4)
	$HurtBox/CorpoHurt.shape = f2
	var f3 := RectangleShape2D.new()
	f3.size = _corpo_tam - Vector2(2, 2)
	$Ataque/CorpoAtaque.shape = f3
	sensor.target_position = Vector2(0, _corpo_tam.y * 0.5 + 9.0)
	sensor.position = Vector2(_corpo_tam.x * 0.5 + 3.0, _corpo_tam.y * 0.5 - 3.0)


func _physics_process(delta: float) -> void:
	if morto:
		return
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group("jogador")
		if alvo == null:
			return
	var d := alvo.global_position - global_position
	if absf(d.x) > 480.0 or absf(d.y) > 400.0:
		return   # longe da tela: dorme (economiza processamento)
	t += delta
	cd -= delta
	_giro -= delta
	if not voa:
		velocity.y += GRAVIDADE * delta
	if _stun > 0.0:
		_stun -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if voa:
			velocity.y = move_toward(velocity.y, 0.0, 300.0 * delta)
	else:
		match tipo:
			"cogumelo": _ia_cogumelo()
			"vespa": _ia_vespa(delta)
			"lobo": _ia_lobo()
			"boneco": _ia_boneco()
			"escaravelho": _ia_escaravelho()
			"cobra": _ia_cobra()
			"esqueleto": _ia_esqueleto()
			"fantasma": _ia_fantasma(delta)
			"salamandra": _ia_salamandra()
			"morcego": _ia_morcego(delta)
	move_and_slide()
	sprite.flip_h = dir < 0


# ------------------------------------------------------------------ utilidades
func _ir(novo: String) -> void:
	estado = novo
	t = 0.0
	_fez = false


func _anim(nome: String, vel := 1.0) -> void:
	sprite.speed_scale = vel
	if sprite.animation != nome:
		sprite.play(nome)
	elif not sprite.is_playing() and sprite.sprite_frames.get_animation_loop(nome):
		sprite.play(nome)


func _dx() -> float:
	return alvo.global_position.x - global_position.x


func _dy() -> float:
	return alvo.global_position.y - global_position.y


func _olhar() -> void:
	var s := signf(_dx())
	if s != 0.0:
		dir = int(s)


func _andar(vx: float) -> void:
	# anda sem cair de penhascos
	velocity.x = vx
	if vx != 0.0:
		sensor.position.x = signf(vx) * (_corpo_tam.x * 0.5 + 3.0)
		sensor.force_raycast_update()
		if is_on_floor() and not sensor.is_colliding():
			velocity.x = 0.0


func _patrulhar(vel: float) -> void:
	sensor.position.x = dir * (_corpo_tam.x * 0.5 + 3.0)
	sensor.force_raycast_update()
	velocity.x = dir * vel
	if is_on_floor() and (is_on_wall() or not sensor.is_colliding()):
		dir = -dir
		velocity.x = dir * vel


func _ativar(hurt: bool, dano_contato: bool) -> void:
	hurtbox.set_deferred("monitorable", hurt)
	contato.set_deferred("monitorable", dano_contato)


func _tiro(v: Vector2, forma: String, grav := 0.0, vida_util := 3.0, origem := Vector2.ZERO, cor := Color.WHITE) -> void:
	var p = load("res://cenas/projetil.tscn").instantiate()
	p.configurar(v, "inimigo", cor, forma, grav, vida_util)
	p.position = global_position + origem
	Util.adicionar(get_parent(), p)


func _linha_aviso(comp: float, dur: float) -> void:
	var a := Aviso.new()
	a.configurar("linha", Vector2(comp, 1.0), Color(1.0, 0.25, 0.2), dur)
	a.position = global_position + Vector2(dir * 8.0, -4.0)
	a.rotation = 0.0 if dir > 0 else PI
	Util.adicionar(get_parent(), a)


# ------------------------------------------------------------------ 1. cogumelo saltitante
func _ia_cogumelo() -> void:
	match estado:
		"patrulha":
			_patrulhar(20.0)
			_anim("andar")
			var d := absf(_dx())
			if (d < 150.0 or agressivo) and is_on_floor() and t > 0.6:
				_olhar()
				_ir("agacha")
		"agacha":
			velocity.x = 0.0
			_anim("agachar")
			if t > 0.35:
				_olhar()
				var forca := -300.0 if _dy() > -28.0 else -370.0
				velocity = Vector2(dir * clampf(absf(_dx()) * 1.2, 60.0, 125.0), forca)
				Sons.tocar_var("pulo", -10.0)
				_ir("ar")
		"ar":
			_anim("pular" if velocity.y < 0.0 else "cair")
			if is_on_floor() and t > 0.15:
				velocity.x = 0.0
				Util.poeira(get_parent(), global_position + Vector2(0, _corpo_tam.y * 0.5), 0.0, Color(0.6, 0.5, 0.4, 0.8), 5)
				_ir("pausa")
		"pausa":
			velocity.x = 0.0
			_anim("parado")
			if t > 0.8:
				_ir("patrulha")


# ------------------------------------------------------------------ 1. vespa-esporo
func _ia_vespa(delta: float) -> void:
	match estado:
		"voa":
			_anim("voar")
			var meta := Vector2(alvo.global_position.x + sin(t * 0.8 + _fase) * 45.0, clampf(alvo.global_position.y - 58.0, ancora.y - 40.0, ancora.y + 30.0) + sin(t * 3.0) * 4.0)
			var desejado := (meta - global_position) * 1.1
			velocity = velocity.move_toward(desejado.limit_length(52.0), 170.0 * delta)
			_olhar()
			if absf(_dx()) < 40.0 and cd <= 0.0 and _dy() > 14.0:
				_ir("solta")
		"solta":
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			_anim("atacar")
			if t > 0.3 and not _fez:
				_fez = true
				_tiro(Vector2(0, 25), "esporo", 190.0, 3.5, Vector2(4.0 * dir, 8.0), Color("#9be85a"))
				Sons.tocar_var("cuspe", -8.0)
			if t > 0.55:
				cd = 2.2
				_ir("voa")


# ------------------------------------------------------------------ 2. lobo da neve
func _ia_lobo() -> void:
	match estado:
		"patrulha":
			_patrulhar(30.0)
			_anim("correr", 0.5)
			if (absf(_dx()) < 170.0 or agressivo) and absf(_dy()) < 40.0 and cd <= 0.0 and is_on_floor():
				_olhar()
				_ir("uivo")
		"uivo":
			velocity.x = 0.0
			_anim("agachar")
			if t > 0.3 and not _fez:
				_fez = true
				Sons.tocar("rugido", -12.0, 1.7)
				Util.particulas(get_parent(), global_position + Vector2(dir * 8.0, -6.0), Color("#c8f0ff"), 6, 20.0, 50.0, 0.4, -20.0, 1.5)
			if t > 0.62:
				_ir("investe")
		"investe":
			_anim("investir")
			velocity.x = dir * 235.0
			if t > 0.12 and int(t * 40.0) % 4 == 0:
				Util.poeira(get_parent(), global_position + Vector2(-dir * 10.0, _corpo_tam.y * 0.5), float(dir), Color(0.9, 0.95, 1.0, 0.8), 2)
			sensor.position.x = dir * (_corpo_tam.x * 0.5 + 3.0)
			sensor.force_raycast_update()
			if t > 0.55 or is_on_wall() or (is_on_floor() and not sensor.is_colliding()):
				_ir("descansa")
		"descansa":
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * get_physics_process_delta_time())
			_anim("parado")
			if t > 0.9:
				cd = 1.4
				_ir("patrulha")


# ------------------------------------------------------------------ 2. boneco de neve arremessador
func _ia_boneco() -> void:
	match estado:
		"patrulha":
			var d := absf(_dx())
			if d < 220.0:
				_olhar()
			if d < 75.0:
				_andar(-dir * 26.0)
				_anim("andar")
			elif d > 190.0:
				_patrulhar(14.0)
				_anim("andar", 0.6)
			else:
				velocity.x = 0.0
				_anim("parado")
			if d > 60.0 and d < 200.0 and cd <= 0.0 and absf(_dy()) < 80.0 and is_on_floor():
				_ir("arremessa")
		"arremessa":
			velocity.x = 0.0
			_olhar()
			_anim("arremessar")
			if t > 0.27 and not _fez:
				_fez = true
				var origem := global_position + Vector2(dir * 8.0, -10.0)
				var dist := absf(_dx())
				var tv := clampf(dist / 130.0, 0.5, 1.0)
				var g := 500.0
				var dy := (alvo.global_position.y - 4.0) - origem.y
				var v := Vector2(_dx() / tv, (dy - 0.5 * g * tv * tv) / tv)
				_tiro(v, "bola_neve", g, 3.0, Vector2(dir * 8.0, -10.0))
				Sons.tocar_var("tiro", -6.0)
			if t > 0.5:
				cd = 2.2
				_ir("patrulha")


# ------------------------------------------------------------------ 3. escaravelho blindado
func _ia_escaravelho() -> void:
	match estado:
		"andar":
			escudo = true
			if absf(_dx()) < 220.0:
				if _giro <= 0.0:
					_olhar()
					_giro = 0.8
				_andar(dir * 26.0)
			else:
				_patrulhar(20.0)
			_anim("andar")
			if cd <= 0.0 and absf(_dx()) < 95.0 and absf(_dy()) < 30.0:
				_ir("abre")
		"abre":
			escudo = false
			velocity.x = 0.0
			_anim("aberto")
			sprite.self_modulate = Color(1.5, 0.8, 0.8)
			if t > 0.45:
				sprite.self_modulate = Color.WHITE
				_ir("investe")
		"investe":
			escudo = false
			_anim("aberto")
			_andar(dir * 150.0)
			if t > 0.5 or is_on_wall():
				_ir("exposto")
		"exposto":
			escudo = false
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * get_physics_process_delta_time())
			_anim("aberto")
			if t > 0.9:
				cd = 2.6 + randf() * 1.2
				_ir("andar")


# ------------------------------------------------------------------ 3. cobra das dunas
func _ia_cobra() -> void:
	match estado:
		"enterrada":
			velocity.x = 0.0
			_anim("enterrada")
			if cd <= 0.0 and absf(_dx()) < 110.0 and absf(_dy()) < 40.0:
				_olhar()
				_ir("emerge")
		"emerge":
			velocity.x = 0.0
			_anim("emergir")
			if t > 0.12 and not _fez:
				_fez = true
				Util.poeira(get_parent(), global_position + Vector2(0, 10), 0.0, Color(0.9, 0.78, 0.5, 0.9), 8)
				Sons.tocar_var("chiado", -6.0)
			if t > 0.3:
				_ativar(true, true)
				_ir("arma")
		"arma":
			_olhar()
			velocity.x = 0.0
			_anim("parado")
			if t > 0.4:
				_ir("bote")
		"bote":
			_anim("ataque")
			if not _fez:
				_fez = true
				velocity = Vector2(dir * 185.0, -110.0)
			if t > 0.3:
				velocity.x = 0.0
				_ir("exposta")
		"exposta":
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * get_physics_process_delta_time())
			_anim("parado")
			if t > 1.1:
				_ir("volta")
		"volta":
			velocity.x = 0.0
			_anim("voltar")
			if t > 0.3:
				_ativar(false, false)
				cd = 1.6
				_ir("enterrada")


# ------------------------------------------------------------------ 4. esqueleto arqueiro
func _ia_esqueleto() -> void:
	match estado:
		"combate":
			var d := absf(_dx())
			if d > 260.0 and not agressivo:
				_patrulhar(14.0)
				_anim("andar", 0.5)
			else:
				_olhar()
				if d < 85.0:
					_andar(-dir * 36.0)
					_anim("andar")
				elif d > 190.0:
					_andar(dir * 24.0)
					_anim("andar", 0.8)
				else:
					velocity.x = 0.0
					_anim("parado")
				if d >= 70.0 and cd <= 0.0 and absf(_dy()) < 55.0:
					_ir("mira")
		"mira":
			velocity.x = 0.0
			_olhar()
			_anim("mirar")
			if t < 0.05:
				_linha_aviso(150.0, 0.5)
			if t > 0.55:
				_ir("atira")
		"atira":
			velocity.x = 0.0
			_anim("atirar")
			if not _fez:
				_fez = true
				_tiro(Vector2(dir * 200.0, 0.0), "flecha", 0.0, 2.5, Vector2(dir * 10.0, -6.0))
				Sons.tocar_var("flecha", -4.0)
			if t > 0.3:
				cd = 1.7
				_ir("combate")


# ------------------------------------------------------------------ 4. fantasma lanterna
func _ia_fantasma(delta: float) -> void:
	match estado:
		"voa":
			_ativar(true, true)
			sprite.self_modulate = Color.WHITE
			_anim("voar")
			var meta := alvo.global_position + Vector2(sin(t * 1.2 + _fase) * 60.0, -30.0 + sin(t * 2.0) * 10.0)
			velocity = velocity.move_toward(((meta - global_position) * 1.0).limit_length(40.0), 120.0 * delta)
			_olhar()
			if t > 2.6:
				_ir("etereo")
		"etereo":
			_ativar(false, false)
			sprite.self_modulate = Color(1, 1, 1, 0.45)
			_anim("etereo")
			velocity = velocity.move_toward(((alvo.global_position + Vector2(0, -24) - global_position)).limit_length(72.0), 220.0 * delta)
			if t > 1.4:
				var lado := 1.0 if randf() < 0.5 else -1.0
				global_position = alvo.global_position + Vector2(lado * 58.0, -26.0)
				velocity = Vector2.ZERO
				Util.particulas(get_parent(), global_position, Color("#c9d4f2"), 8, 20.0, 60.0, 0.4, -30.0, 2.0)
				Sons.tocar_var("teleporte", -10.0)
				_ir("grita")
		"grita":
			_ativar(true, true)
			sprite.self_modulate = Color.WHITE
			velocity = Vector2.ZERO
			_olhar()
			_anim("atacar")
			if t > 0.25 and not _fez:
				_fez = true
				var p = load("res://cenas/projetil.tscn").instantiate()
				p.configurar(((alvo.global_position + Vector2(0, -6)) - global_position).normalized() * 70.0, "inimigo", Color("#40ffb0"), "espectro", 0.0, 3.5)
				p.teleguiado = 55.0
				p.position = global_position
				Util.adicionar(get_parent(), p)
				Sons.tocar_var("invocar", -10.0)
			if t > 0.6:
				_ir("voa")


# ------------------------------------------------------------------ 5. salamandra de magma
func _ia_salamandra() -> void:
	match estado:
		"patrulha":
			_patrulhar(22.0)
			_anim("andar")
			if (absf(_dx()) < 210.0 or agressivo) and absf(_dy()) < 60.0 and cd <= 0.0 and is_on_floor():
				_olhar()
				_ir("cospe")
		"cospe":
			velocity.x = 0.0
			_olhar()
			_anim("cuspir")
			if t > 0.25 and not _fez:
				_fez = true
				var vx := clampf(absf(_dx()) * 0.85, 70.0, 140.0) * dir
				_tiro(Vector2(vx, -140.0), "fogo", 280.0, 3.0, Vector2(dir * 14.0, -4.0), Color("#ff7a1a"))
				Sons.tocar_var("fogo", -8.0)
			if t > 0.6:
				cd = 2.4
				_ir("patrulha")


# ------------------------------------------------------------------ 5. morcego ígneo
func _ia_morcego(delta: float) -> void:
	match estado:
		"paira":
			_anim("voar")
			var meta := ancora + Vector2(sin(t * 1.3 + _fase) * 42.0, sin(t * 2.1) * 6.0)
			velocity = velocity.move_toward((meta - global_position).limit_length(40.0), 160.0 * delta)
			_olhar()
			if absf(_dx()) < 150.0 and _dy() > 20.0 and cd <= 0.0:
				_ir("mira")
		"mira":
			velocity = Vector2.ZERO
			_anim("voar", 1.6)
			sprite.self_modulate = Color(1.5, 0.7, 0.7)
			sprite.position = Vector2(randf_range(-1.0, 1.0), 2.0 + randf_range(-1.0, 1.0))
			if t > 0.5:
				sprite.self_modulate = Color.WHITE
				sprite.position = Vector2(0, 2)
				_alvo_fixo = alvo.global_position + Vector2(0, -4)
				Sons.tocar_var("asas", -4.0)
				_ir("mergulha")
		"mergulha":
			_anim("mergulho")
			var para := _alvo_fixo - global_position
			velocity = para.normalized() * 205.0
			if para.length() < 9.0 or t > 0.9 or is_on_wall() or is_on_floor():
				_ir("sobe")
		"sobe":
			_anim("voar")
			velocity = velocity.move_toward((ancora - global_position).limit_length(85.0), 400.0 * delta)
			if global_position.distance_to(ancora) < 10.0:
				cd = 1.6
				_ir("paira")


# ------------------------------------------------------------------ dano e morte
# Retorna true se o golpe causou dano (false = bloqueado ou inválido).
func levar_dano(dano: int, dir_golpe: int) -> bool:
	if morto:
		return false
	if tipo == "cobra" and (estado == "enterrada" or estado == "emerge"):
		return false
	if tipo == "fantasma" and estado == "etereo":
		return false
	if tipo == "escaravelho" and escudo and dano < 5 and dir_golpe == -dir:
		Sons.tocar_var("escudo", -2.0)
		Util.faiscas(get_parent(), global_position + Vector2(dir * 10.0, -2.0), Color("#9ae8ff"))
		velocity.x = dir_golpe * 50.0
		if randf() < 0.45 and cd <= 0.0:
			_ir("abre")
		return false
	vida -= dano
	Sons.tocar_var("dano", -4.0)
	_stun = 0.25
	velocity = Vector2(dir_golpe * 110.0, -30.0 if voa else -110.0)
	sprite.self_modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
	Util.particulas(get_parent(), global_position, _info["cor"], 6, 40.0, 100.0, 0.4, 220.0, 2.0)
	if vida <= 0:
		_morrer()
		return true
	_interromper()
	if sprite.sprite_frames.has_animation("dano"):
		sprite.speed_scale = 1.0
		sprite.play("dano")
	return true


func _interromper() -> void:
	if tipo in ["cobra", "fantasma", "escaravelho"]:
		return
	var base: String = _info["base"]
	if tipo == "morcego":
		base = "sobe"
	estado = base
	t = 0.0
	cd = maxf(cd, 0.7)
	agressivo = true


func _morrer() -> void:
	morto = true
	Sons.tocar_var("explosao", -4.0)
	Jogo.tremer(0.8, 0.1)
	Util.explosao(get_parent(), global_position, _info["cor"], 0.6)
	_ativar(false, false)
	collision_layer = 0
	collision_mask = 0
	sprite.self_modulate = Color.WHITE
	sprite.speed_scale = 1.0
	sprite.play("morte")
	if dropa:
		var n: int = int(_info["moedas"]) + randi_range(0, 1)
		for i in n:
			Util.soltar_item(get_parent(), global_position, "moeda", 5)
		if randf() < 0.08:
			Util.soltar_item(get_parent(), global_position, "coracao", 1)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(queue_free)
