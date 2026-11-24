extends Area2D
# Projétil criado durante o jogo: tiros dos inimigos/chefes e o ataque especial do herói.
# Cada "forma" usa uma imagem em arte/efeitos/ (com quadros animados quando frames > 1).

# forma: [quadros, gira_para_direção, tinge_com_cor, raio_de_colisão, deixa_rastro]
const FORMAS := {
	"bola": [1, false, true, 5.0, false],
	"onda": [1, false, true, 6.0, false],
	"gelo": [1, true, false, 5.0, true],
	"fogo": [3, false, false, 6.0, true],
	"espectro": [3, true, false, 5.0, true],
	"esporo": [3, false, false, 4.5, true],
	"bola_neve": [1, false, false, 4.0, false],
	"pedra": [1, false, false, 5.0, false],
	"flecha": [1, true, false, 4.0, false],
	"meteoro": [3, false, false, 7.0, true],
	"lamina": [3, false, false, 10.0, false],
	"veneno": [1, false, false, 3.5, true],
}

var vel := Vector2.ZERO
var dono := "inimigo"
var dano := 1
var gravidade := 0.0
var vida_util := 3.0
var cor := Color.WHITE
var forma := "bola"
var perfura := false
var teleguiado := 0.0         # graus por segundo (0 = não persegue)
var congela := false          # congela o jogador ao acertar
var escala := 1.0
var explode := ""             # efeito ao bater no chão ("" = nenhum)
var _t := 0.0
var _n := 1
var _alvo: Node2D

@onready var sprite: Sprite2D = $Sprite


func configurar(v: Vector2, quem: String, c: Color = Color.WHITE, f: String = "bola", g: float = 0.0, vu: float = 3.0, d: int = 1) -> void:
	vel = v
	dono = quem
	cor = c
	forma = f
	gravidade = g
	vida_util = vu
	dano = d


func _ready() -> void:
	var info: Array = FORMAS.get(forma, FORMAS["bola"])
	_n = info[0]
	var gira: bool = info[1]
	var tinge: bool = info[2]
	var raio: float = info[3]
	var rastro: bool = info[4]
	sprite.texture = load("res://arte/efeitos/%s.png" % forma)
	sprite.hframes = _n
	if tinge:
		sprite.modulate = cor
	sprite.scale = Vector2(escala, escala)
	var forma_col := CircleShape2D.new()
	forma_col.radius = raio * escala
	$Corpo.shape = forma_col
	if gira:
		rotation = vel.angle()
	else:
		sprite.flip_h = vel.x < 0.0
	if dono == "jogador":
		collision_layer = 8
		collision_mask = 1 | 4
		perfura = (forma == "onda")
	else:
		collision_layer = 0          # o dano é aplicado por este script (body_entered)
		collision_mask = 1 | 2
		_alvo = get_tree().get_first_node_in_group("jogador")
	if rastro:
		var p := CPUParticles2D.new()
		p.amount = 7
		p.lifetime = 0.3
		p.local_coords = false
		p.direction = Vector2.ZERO
		p.spread = 180.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 14.0
		p.gravity = Vector2.ZERO
		p.scale_amount_min = 1.5 * escala
		p.scale_amount_max = 2.6 * escala
		var g := Gradient.new()
		g.set_color(0, Color(cor.r, cor.g, cor.b, 0.9))
		g.set_color(1, Color(cor.r, cor.g, cor.b, 0.0))
		p.color_ramp = g
		p.emitting = true
		add_child(p)
	if forma in ["fogo", "espectro", "meteoro"]:
		Util.luz(self, Vector2.ZERO, cor, 0.6, 0.35 * escala)
	area_entered.connect(_ao_area)
	body_entered.connect(_ao_corpo)


func _physics_process(delta: float) -> void:
	_t += delta
	if teleguiado > 0.0 and _alvo and is_instance_valid(_alvo):
		var desejado := ((_alvo.global_position + Vector2(0, -6)) - global_position).angle()
		var atual := vel.angle()
		var d := angle_difference(atual, desejado)
		var passo := deg_to_rad(teleguiado) * delta
		vel = Vector2.from_angle(atual + clampf(d, -passo, passo)) * vel.length()
		rotation = vel.angle()
	vel.y += gravidade * delta
	position += vel * delta
	if _n > 1:
		sprite.frame = int(_t * 10.0) % _n
	vida_util -= delta
	if vida_util <= 0.0:
		queue_free()


func _ao_area(area: Area2D) -> void:
	if dono != "jogador":
		return
	var alvo = area.get_parent()
	if alvo.has_method("levar_dano"):
		var ok = alvo.levar_dano(dano, int(signf(vel.x)))
		if ok == true:
			Util.faiscas(get_parent(), global_position, cor)
			Sons.tocar_var("acerto", -3.0)
		if not perfura:
			queue_free()


func _ao_corpo(corpo: Node) -> void:
	if corpo.is_in_group("jogador"):
		if dono == "jogador":
			return
		var aplicou = corpo.levar_dano(int(signf(vel.x)))
		if aplicou == true:
			if congela and corpo.has_method("congelar_gelo"):
				corpo.congelar_gelo(1.8)
			queue_free()
		return
	_bater()


func _bater() -> void:
	if explode != "":
		Util.explosao(get_parent(), global_position, cor, 0.8)
		Sons.tocar_var("impacto", -8.0)
	elif forma in ["gelo", "bola_neve"]:
		Util.particulas(get_parent(), global_position, Color("#c8f0ff"), 6, 30.0, 80.0, 0.3, 150.0, 1.5)
	queue_free()
