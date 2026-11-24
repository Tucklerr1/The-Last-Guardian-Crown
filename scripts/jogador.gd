extends CharacterBody2D
# O herói. WASD move, ESPAÇO pula, clique esquerdo bate (combo de 2 golpes), TAB usa o ataque especial.

const VEL_CORRIDA := 105.0
const VEL_CAMINHADA := 64.0
const FORCA_PULO := -330.0
const GRAVIDADE := 900.0
const TEMPO_INVENCIVEL := 1.0
const TEMPO_GOLPE := 0.18
const RECARGA_GOLPE := 0.30
const COYOTE := 0.10
const BUFFER_PULO := 0.12
const PE_Y := 9.0
const LIMITE_QUEDA := 17 * 16 + 40

var direcao := 1
var invencivel := 0.0
var recarga := 0.0
var golpe_restante := 0.0
var morto := false
var congelado := false          # em cena: não recebe comandos (entrada de chefe)
var pose_vitoria := false
var lento := 0.0                # tempo restante de congelamento (gelo)
var sobre_gelo := 0             # quantas zonas de gelo estão embaixo do herói
var combo := 0
var tempo_combo := 0.0
var coyote := 0.0
var buffer_pulo := 0.0
var tempo_correndo := 0.0
var especial_restante := 0.0
var especial_pendente := false
var cor_poeira := Color(0.82, 0.74, 0.62, 0.8)
var ultimo_seguro := Vector2.ZERO

var _bloqueio_anim := 0.0
var _vy_antes := 0.0
var _tempo_poeira := 0.0
var _tempo_seguro := 0.0
var _tremor_forca := 0.0
var _tremor_tempo := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera
@onready var hurtbox: Area2D = $HurtBox
@onready var ataque: Area2D = $Ataque
@onready var efeito_golpe: Sprite2D = $Golpe


func _ready() -> void:
	add_to_group("jogador")
	ataque.area_entered.connect(_ao_acertar)
	Jogo.tremor.connect(_tremer)


func _tremer(forca: float, tempo: float) -> void:
	_tremor_forca = maxf(_tremor_forca, forca)
	_tremor_tempo = maxf(_tremor_tempo, tempo)


func _process(delta: float) -> void:
	if _tremor_tempo > 0.0:
		_tremor_tempo -= delta
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _tremor_forca
	else:
		_tremor_forca = 0.0
		camera.offset = Vector2.ZERO
	# a câmera olha um pouco à frente
	var alvo_x := 0.0 if morto else direcao * 22.0 * clampf(absf(velocity.x) / VEL_CORRIDA, 0.0, 1.0)
	camera.position.x = lerpf(camera.position.x, alvo_x, minf(3.0 * delta, 1.0))


func _physics_process(delta: float) -> void:
	velocity.y += GRAVIDADE * delta
	if ultimo_seguro == Vector2.ZERO:
		ultimo_seguro = global_position
	if morto:
		move_and_slide()
		return

	lento = maxf(lento - delta, 0.0)
	recarga -= delta
	tempo_combo -= delta
	_bloqueio_anim -= delta
	especial_restante -= delta
	var no_chao := is_on_floor()

	var eixo := 0.0
	if not congelado:
		eixo = Input.get_axis("esquerda", "direita")
	if especial_restante > 0.0:
		eixo *= 0.25

	if eixo != 0.0:
		tempo_correndo += delta
	elif no_chao:
		tempo_correndo = 0.0
	var vmax := VEL_CORRIDA if tempo_correndo > 0.3 else VEL_CAMINHADA
	if lento > 0.0:
		vmax *= 0.5
	var acel := 900.0 if no_chao else 650.0
	if sobre_gelo > 0 and no_chao:
		acel = 260.0 if eixo != 0.0 else 90.0
	velocity.x = move_toward(velocity.x, eixo * vmax, acel * delta)

	# pulo com "coyote time" e buffer (perdoa apertos fora de hora)
	coyote = COYOTE if no_chao else coyote - delta
	if not congelado and Input.is_action_just_pressed("pular"):
		buffer_pulo = BUFFER_PULO
	else:
		buffer_pulo -= delta
	if buffer_pulo > 0.0 and coyote > 0.0:
		_pular()
	if not congelado and Input.is_action_just_released("pular") and velocity.y < -120.0:
		velocity.y *= 0.5   # soltar o pulo cedo = pulo mais baixo

	if not congelado:
		if Input.is_action_just_pressed("atacar") and recarga <= 0.0 and especial_restante <= 0.0:
			_golpear()
		if Input.is_action_just_pressed("especial"):
			_usar_especial()
	if golpe_restante > 0.0:
		golpe_restante -= delta
		efeito_golpe.frame = clampi(int((1.0 - golpe_restante / TEMPO_GOLPE) * 4.0), 0, 3)
		if golpe_restante <= 0.0:
			ataque.set_deferred("monitoring", false)
			efeito_golpe.visible = false
	if especial_pendente and especial_restante <= 0.1:
		_disparar_especial()

	if eixo != 0.0 and golpe_restante <= 0.0 and especial_restante <= 0.0:
		direcao = 1 if eixo > 0.0 else -1
	_vy_antes = velocity.y
	move_and_slide()

	# aterrissagem e poeira
	if is_on_floor() and not no_chao and _vy_antes > 140.0:
		Util.poeira(get_parent(), global_position + Vector2(0, PE_Y), 0.0, cor_poeira, 8)
		Sons.tocar_var("aterrissar", -6.0)
	if is_on_floor() and absf(velocity.x) > 78.0:
		_tempo_poeira -= delta
		if _tempo_poeira <= 0.0:
			_tempo_poeira = 0.13
			Util.poeira(get_parent(), global_position + Vector2(-direcao * 4.0, PE_Y), float(direcao), cor_poeira, 3)

	_registrar_ponto_seguro(delta)
	if global_position.y > LIMITE_QUEDA:
		resgatar()
	_animar()
	_checar_dano(delta)


func _pular(forca := FORCA_PULO) -> void:
	velocity.y = forca
	coyote = 0.0
	buffer_pulo = 0.0
	Sons.tocar_var("pulo", -2.0)
	Util.poeira(get_parent(), global_position + Vector2(0, PE_Y), 0.0, cor_poeira, 4)


# Usado por molas e plataformas: lança o herói para cima.
func impulso(v: float) -> void:
	velocity.y = v
	coyote = 0.0
	_bloqueio_anim = 0.0


func _golpear() -> void:
	combo = 2 if (tempo_combo > 0.0 and combo == 1) else 1
	tempo_combo = 0.55
	recarga = RECARGA_GOLPE
	golpe_restante = TEMPO_GOLPE
	direcao = 1 if get_global_mouse_position().x >= global_position.x else -1
	ataque.position.x = 14.0 * direcao
	ataque.set_deferred("monitoring", true)
	efeito_golpe.position = Vector2(14.0 * direcao, -3.0)
	efeito_golpe.flip_h = direcao < 0
	efeito_golpe.flip_v = (combo == 2)
	efeito_golpe.frame = 0
	efeito_golpe.visible = true
	_bloqueio_anim = 0.26
	sprite.stop()
	sprite.play("golpe1" if combo == 1 else "golpe2")
	if is_on_floor():
		velocity.x += direcao * 55.0
	Sons.tocar_var("golpe" if combo == 1 else "golpe2", -2.0)


func _ao_acertar(area: Area2D) -> void:
	var alvo = area.get_parent()
	if alvo.has_method("levar_dano"):
		var dmg := 1 + Jogo.dano_extra
		var ok = alvo.levar_dano(dmg, direcao)
		if ok == true:
			Jogo.ganhar_especial(10.0)
			Sons.tocar_var("acerto")
			Util.faiscas(get_parent(), global_position.lerp(area.global_position, 0.75))
			Jogo.congelar(0.04)
			Jogo.tremer(1.2, 0.08)


func _usar_especial() -> void:
	if especial_pendente or especial_restante > 0.0:
		return
	if Jogo.especial < 100.0:
		Jogo.mensagem.emit("Especial ainda carregando (acerte inimigos!)")
		Sons.tocar("menu_voltar", -6.0)
		return
	Jogo.gastar_especial()
	Sons.tocar("especial")
	especial_restante = 0.45
	especial_pendente = true
	_bloqueio_anim = 0.5
	sprite.stop()
	sprite.play("especial")
	Util.anel(get_parent(), global_position + Vector2(0, 8), Color("#7ad8ff"), 1.0)
	Util.particulas(get_parent(), global_position, Color("#7ad8ff"), 14, 30.0, 90.0, 0.5, -60.0, 2.0)


func _disparar_especial() -> void:
	especial_pendente = false
	var p = load("res://cenas/projetil.tscn").instantiate()
	p.configurar(Vector2(240.0 * direcao, 0.0), "jogador", Color("#7ad8ff"), "onda", 0.0, 1.6, 5)
	p.escala = 1.6
	p.position = position + Vector2(12.0 * direcao, -2.0)
	Util.adicionar(get_parent(), p)
	Jogo.tremer(2.0, 0.15)


func _checar_dano(delta: float) -> void:
	var cor_base := Color(0.62, 0.86, 1.3) if lento > 0.0 else Color.WHITE
	if invencivel > 0.0:
		invencivel -= delta
		var a := 0.35 if int(invencivel * 20.0) % 2 == 0 else 1.0
		sprite.modulate = Color(cor_base.r, cor_base.g, cor_base.b, a)
		if invencivel <= 0.0:
			sprite.modulate = cor_base
		return
	sprite.modulate = cor_base
	if congelado:
		return
	for area in hurtbox.get_overlapping_areas():
		levar_dano(signi(int(global_position.x - area.global_position.x)))
		return


# Retorna true se o dano foi aplicado.
func levar_dano(empurrao: int, _qtd := 1) -> bool:
	if invencivel > 0.0 or morto:
		return false
	Jogo.perder_coracao()
	Sons.tocar("dano")
	invencivel = TEMPO_INVENCIVEL
	velocity = Vector2(empurrao * 130.0, -170.0)
	Util.particulas(get_parent(), global_position, Color("#e8344a"), 10, 40.0, 110.0, 0.45, 260.0, 2.0)
	Jogo.tremer(2.5, 0.15)
	Jogo.congelar(0.07)
	if Jogo.coracoes <= 0:
		_morrer()
	else:
		_bloqueio_anim = 0.3
		sprite.stop()
		sprite.play("dano")
	return true


func congelar_gelo(seg: float) -> void:
	lento = seg
	Sons.tocar("congelar")
	Util.particulas(get_parent(), global_position, Color("#c8f0ff"), 12, 20.0, 70.0, 0.5, 40.0, 2.0)


# Cai em abismo/lava: perde um coração e volta ao último ponto seguro.
func resgatar() -> void:
	if morto:
		return
	Jogo.perder_coracao()
	Sons.tocar("dano")
	if Jogo.coracoes <= 0:
		_morrer()
		return
	invencivel = 1.4
	velocity = Vector2.ZERO
	global_position = ultimo_seguro + Vector2(0, -2)
	camera.reset_smoothing()
	Jogo.tremer(2.0, 0.12)


func _registrar_ponto_seguro(delta: float) -> void:
	if not is_on_floor():
		_tempo_seguro = 0.0
		return
	_tempo_seguro += delta
	if _tempo_seguro > 0.25 and _tem_chao(-12.0) and _tem_chao(12.0):
		ultimo_seguro = global_position
		_tempo_seguro = 0.0


func _tem_chao(dx: float) -> bool:
	var espaco := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(dx, 0.0), global_position + Vector2(dx, 26.0))
	q.collision_mask = 1
	return not espaco.intersect_ray(q).is_empty()


func _morrer() -> void:
	morto = true
	sprite.modulate = Color(0.85, 0.85, 0.95)
	sprite.stop()
	sprite.play("morte")
	velocity = Vector2(-direcao * 40.0, -220.0)
	$Corpo.set_deferred("disabled", true)
	Jogo.tremer(3.0, 0.3)
	Jogo.jogador_morreu.emit()


# Chamado pelos chefes ao serem derrotados.
func comemorar() -> void:
	if morto:
		return
	pose_vitoria = true
	congelado = true


func _animar() -> void:
	sprite.flip_h = direcao < 0
	if morto:
		return
	if pose_vitoria:
		sprite.play("vitoria")
		return
	if _bloqueio_anim > 0.0:
		return
	if not is_on_floor():
		sprite.play("pulo" if velocity.y < 0.0 else "queda")
	elif absf(velocity.x) > 78.0:
		sprite.play("correr")
	elif absf(velocity.x) > 8.0:
		sprite.play("andar")
	else:
		sprite.play("parado")
