extends CharacterBody2D
# Chefe. Cada um (tipo 1 a 5) tem sprites, ataques e inteligência de combate própria, em 3 fases:
# 1 Rei Cogumelo  = saltos esmagadores, chuva de esporos, rolada e raízes (aproveite os cogumelos-mola)
# 2 Golem de Gelo = leque e anéis de gelo, soco glacial, estalactites; o núcleo se expõe depois do anel
# 3 Escorpião Rei = investida, cauda, garras, entra na areia e emerge, defesa frontal (ataque por trás)
# 4 Cavaleiro Fantasma = teleporte, ilusões (só um é real), invocações, almas teleguiadas e lâminas
# 5 Dragão de Lava = voa disparando fogo, mergulha (fica vulnerável), sopro, cauda e chuva de meteoros
#
# Os ataques são listas de passos [duração, ao_começar, a_cada_quadro]; veja _seq().

signal intro_iniciada
signal derrotado

const GRAVIDADE := 900.0

const DADOS := {
	1: {"vida": 40, "corpo": Vector2(44, 56), "pe": 77.0, "quadro": Vector2(80, 80), "titulo": "O Soberano dos Esporos", "cor": Color("#b070ff"), "musica": "chefe_1", "pausa": 1.0, "vel": 34.0},
	2: {"vida": 40, "corpo": Vector2(40, 66), "pe": 93.0, "quadro": Vector2(80, 96), "titulo": "O Coração da Geada Eterna", "cor": Color("#7ee0ff"), "musica": "chefe_2", "pausa": 1.2, "vel": 22.0},
	3: {"vida": 40, "corpo": Vector2(62, 28), "pe": 70.0, "quadro": Vector2(128, 72), "titulo": "O Senhor das Areias Ardentes", "cor": Color("#ffb84a"), "musica": "chefe_3", "pausa": 0.9, "vel": 48.0},
	4: {"vida": 40, "corpo": Vector2(30, 56), "pe": 90.0, "quadro": Vector2(80, 96), "titulo": "A Sentinela Sem Descanso", "cor": Color("#40ffb0"), "musica": "chefe_4", "pausa": 0.8, "vel": 40.0},
	5: {"vida": 44, "corpo": Vector2(60, 40), "pe": 117.0, "quadro": Vector2(128, 120), "titulo": "A Fúria do Vulcão", "cor": Color("#ff7a1a"), "musica": "chefe_5", "pausa": 0.8, "vel": 0.0},
}

var tipo := 1
var nome := "Chefe"
var frames_res: SpriteFrames
var arena_min := 0.0
var arena_max := 0.0
var chao_y := 0.0
var vida := 40
var vida_max := 40
var fase := 1
var ativo := false
var morto := false
var vulneravel := false
var mult_dano := 1.0
var voando := false
var dir := -1
var alvo: Node2D

var _info: Dictionary = {}
var _tam := Vector2(40, 40)
var _passos: Array = []
var _passo_i := 0
var _passo_t := 0.0
var _passo_dur := 0.0
var _passo_upd := Callable()
var _agenda: Array = []
var _ocioso := 1.0
var _ultimo := ""
var _proximo := ""
var _em_intro := false
var _intang := false
var _bloqueio := false
var _bloqueios_feitos := 0
var _tx := 0.0
var _rol_dir := 1
var _rol_quicadas := 0
var _tempo_efeito := 0.0
var _hover_y := 0.0
var _clones: Array = []
var _t := 0.0
var _tinta := Color.WHITE

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Area2D = $HurtBox
@onready var contato: Area2D = $Ataque
@onready var corpo: CollisionShape2D = $Corpo


func _ready() -> void:
	add_to_group("chefes")
	_info = DADOS[tipo]
	_tam = _info["corpo"]
	vida_max = _info["vida"]
	vida = vida_max
	sprite.sprite_frames = frames_res
	sprite.play("parado" if sprite.sprite_frames.has_animation("parado") else "pousado")
	var f1 := RectangleShape2D.new()
	f1.size = _tam
	corpo.shape = f1
	var f2 := RectangleShape2D.new()
	f2.size = _tam + Vector2(8, 8)
	$HurtBox/CorpoHurt.shape = f2
	var f3 := RectangleShape2D.new()
	f3.size = _tam - Vector2(6, 6)
	$Ataque/CorpoAtaque.shape = f3
	var quadro: Vector2 = _info["quadro"]
	var pe: float = _info["pe"]
	sprite.position = Vector2(0, _tam.y * 0.5 - (pe - quadro.y * 0.5))
	if tipo == 4:
		_hover_y = chao_y - 50.0
		position.y = _hover_y
		sprite.position = Vector2(0, 4)
		voando = true
	else:
		position.y = chao_y - _tam.y * 0.5
	if tipo == 5:
		_hover_y = chao_y - 92.0
	alvo = get_tree().get_first_node_in_group("jogador")
	# o chefe só aparece e luta quando o jogador entra na arena
	sprite.visible = false
	_contato(false)
	hurtbox.set_deferred("monitorable", false)
	Util.luz(self, Vector2(0, -10), _info["cor"], 0.55, 1.6)


# ------------------------------------------------------------------ laço principal
func _physics_process(delta: float) -> void:
	_t += delta
	_tick_agenda(delta)
	if morto:
		return
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group("jogador")
		return
	if not ativo and not _em_intro:
		if alvo.global_position.x > arena_min + 56.0 and not alvo.morto:
			_iniciar_intro()
		return
	_tick_seq(delta)
	if ativo and _passos.is_empty():
		_ocioso -= delta
		_ia_ocioso(delta)
		if _ocioso <= 0.0 and not _intang:
			_escolher_ataque()
	if not voando:
		velocity.y += GRAVIDADE * delta
	move_and_slide()
	position.x = clampf(position.x, arena_min + _tam.x * 0.5, arena_max - _tam.x * 0.5)
	sprite.flip_h = dir < 0
	_atualizar_tinta()


func _atualizar_tinta() -> void:
	if _em_intro:
		return
	if _intang and ativo:
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.7)
	elif vulneravel:
		var k := 0.5 + 0.5 * sin(_t * 12.0)
		sprite.modulate = Color(1.0 + 0.25 * k, 1.0 + 0.25 * k, 1.35)
	else:
		sprite.modulate = _tinta


# ------------------------------------------------------------------ sequenciador de ataques
func _seq(lista: Array) -> void:
	_passos = lista
	_passo_i = -1
	_avancar()


func _avancar() -> void:
	while true:
		_passo_i += 1
		if _passo_i >= _passos.size():
			_passos = []
			_passo_upd = Callable()
			_ocioso = _pausa()
			return
		var p: Array = _passos[_passo_i]
		_passo_dur = float(p[0])
		_passo_t = 0.0
		if p.size() > 1 and p[1] is Callable:
			var ini: Callable = p[1]
			ini.call()
		_passo_upd = Callable()
		if p.size() > 2 and p[2] is Callable:
			_passo_upd = p[2]
		if _passo_dur > 0.0 or _passo_upd.is_valid():
			return


func _tick_seq(delta: float) -> void:
	if _passos.is_empty():
		return
	_passo_t += delta
	var fim := false
	if _passo_upd.is_valid():
		var r = _passo_upd.call(delta)
		if r == true:
			fim = true
	if fim or _passo_t >= _passo_dur:
		_avancar()


func _pausa() -> float:
	var base: float = _info["pausa"]
	return maxf(0.35, base - 0.2 * float(fase - 1))


func _depois(seg: float, f: Callable) -> void:
	_agenda.append([seg, f])


func _tick_agenda(delta: float) -> void:
	var i := _agenda.size() - 1
	while i >= 0:
		var item: Array = _agenda[i]
		item[0] = float(item[0]) - delta
		if float(item[0]) <= 0.0:
			_agenda.remove_at(i)
			var f: Callable = item[1]
			if f.is_valid():
				f.call()
		i -= 1


func _u_parar(delta: float) -> bool:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	return false


func _s_fim_vuln() -> void:
	vulneravel = false
	mult_dano = 1.0


func _vuln(m: float) -> void:
	mult_dano = m
	vulneravel = m > 1.0


# ------------------------------------------------------------------ utilidades
func _olhar() -> void:
	var s := signf(alvo.global_position.x - global_position.x)
	if s != 0.0:
		dir = int(s)


func _olhar_contra() -> void:
	_olhar()
	dir = -dir


func _anim(n: String) -> void:
	sprite.speed_scale = 1.0
	if sprite.animation != n:
		sprite.play(n)
	elif not sprite.is_playing() and sprite.sprite_frames.get_animation_loop(n):
		sprite.play(n)


func _tocar(n: String) -> void:
	sprite.speed_scale = 1.0
	sprite.stop()
	sprite.play(n)


func _pose(n: String, quadro: int) -> void:
	sprite.speed_scale = 1.0
	sprite.play(n)
	sprite.set_frame_and_progress(quadro, 0.0)
	sprite.pause()


func _contato(b: bool) -> void:
	contato.set_deferred("monitorable", b)


func _pe_y() -> float:
	return chao_y - _tam.y * 0.5


func _tiro(v: Vector2, cor: Color, forma := "bola", grav := 0.0, vida_util := 4.0, origem := Vector2(0, -6), extra := {}) -> void:
	var p = load("res://cenas/projetil.tscn").instantiate()
	p.configurar(v, "inimigo", cor, forma, grav, vida_util)
	for k in extra:
		p.set(k, extra[k])
	p.position = position + origem
	Util.adicionar(get_parent(), p)


func _hitbox(centro: Vector2, tam: Vector2, dur: float, atraso := 0.0) -> void:
	if atraso > 0.0:
		_depois(atraso, _criar_hitbox.bind(centro, tam, dur))
	else:
		_criar_hitbox(centro, tam, dur)


func _criar_hitbox(centro: Vector2, tam: Vector2, dur: float) -> void:
	var a := Area2D.new()
	a.collision_layer = 16
	a.collision_mask = 0
	a.position = centro
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = tam
	cs.shape = r
	a.add_child(cs)
	Util.adicionar(get_parent(), a)
	_depois(dur, _liberar.bind(a))


func _liberar(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()


# Erupção que nasce do chão: marca o local, espera `atraso` e então surge (com hitbox).
func _erupcao(x: float, fx_nome: String, tam: Vector2, atraso: float, cor := Color(1.0, 0.3, 0.2)) -> void:
	Util.aviso(get_parent(), Vector2(x, chao_y - 3.0), "retangulo", Vector2(maxf(tam.x, 12.0), 6.0), cor, maxf(atraso, 0.05))
	_depois(atraso, _surge.bind(x, fx_nome, tam))


func _surge(x: float, fx_nome: String, tam: Vector2) -> void:
	Util.fx(get_parent(), Vector2(x, chao_y), fx_nome, 4, 14.0, 1.0, false, Color.WHITE, true)
	_criar_hitbox(Vector2(x, chao_y - tam.y * 0.5), tam, 0.3)
	Util.poeira(get_parent(), Vector2(x, chao_y - 2.0), 0.0, Color(0.8, 0.75, 0.7, 0.8), 4)
	Sons.tocar_var("raiz" if tipo == 1 else ("gelo" if tipo == 2 else "geiser"), -6.0)
	Jogo.tremer(1.2, 0.1)


func _linha_aviso(origem: Vector2, comp: float, dir_x: int, dur: float, cor := Color(1.0, 0.25, 0.2)) -> void:
	var a := Aviso.new()
	a.configurar("linha", Vector2(comp, 2.0), cor, dur)
	a.position = origem
	a.rotation = 0.0 if dir_x > 0 else PI
	Util.adicionar(get_parent(), a)


func _invocar_inimigo(t_inimigo: String, pos: Vector2, vida_inim := 1) -> void:
	var e = load("res://cenas/inimigo.tscn").instantiate()
	e.tipo = t_inimigo
	e.vida = vida_inim
	e.dropa = false
	e.agressivo = true
	e.position = pos
	Util.adicionar(get_parent(), e)
	Util.particulas(get_parent(), pos, _info["cor"], 10, 30.0, 80.0, 0.5, -20.0, 2.0)


# ------------------------------------------------------------------ entrada dramática
func _iniciar_intro() -> void:
	_em_intro = true
	intro_iniciada.emit()
	alvo.congelado = true
	Sons.musica("")
	Sons.tocar("entrada_chefe")
	sprite.visible = true
	match tipo:
		1:
			_seq([[0.01, _i1_cair], [3.0, null, _u_esperar_chao], [0.6, _i_impacto], [1.7, _i_banner], [0.0, _i_fim]])
		2:
			_seq([[0.01, _i2_formar], [1.1, null, _u_fade_in], [0.5, _i_impacto], [1.7, _i_banner], [0.0, _i_fim]])
		3:
			_seq([[0.01, _i3_emergir], [0.9, null], [0.5, _i_impacto], [1.7, _i_banner], [0.0, _i_fim]])
		4:
			_seq([[0.01, _i4_aparecer], [1.0, null], [1.7, _i_banner], [0.0, _i_fim]])
		5:
			_seq([[0.01, _i5_chegar], [3.0, null, _u_i5_pousar], [0.5, _i_impacto], [1.7, _i_banner], [0.0, _i_fim]])


func _i1_cair() -> void:
	position.y = chao_y - 230.0
	velocity = Vector2.ZERO
	_tocar("cair")
	_olhar()


func _u_esperar_chao(_delta: float) -> bool:
	if velocity.y > 0.0 and sprite.sprite_frames.has_animation("cair"):
		_anim("cair")
	return is_on_floor() and _passo_t > 0.2


func _i2_formar() -> void:
	sprite.modulate = Color(1, 1, 1, 0.0)
	_olhar()
	_anim("parado")
	Util.particulas(get_parent(), global_position, Color("#bfe6ff"), 40, 40.0, 140.0, 1.0, -30.0, 2.5)
	Sons.tocar("gelo")


func _u_fade_in(_delta: float) -> bool:
	sprite.modulate = Color(1, 1, 1, clampf(_passo_t / 0.9, 0.0, 1.0))
	if int(_passo_t * 30.0) % 3 == 0:
		Util.particulas(get_parent(), global_position + Vector2(randf_range(-30, 30), randf_range(-40, 20)), Color("#e8f8ff"), 2, 10.0, 30.0, 0.4, 0.0, 1.5)
	return false


func _i3_emergir() -> void:
	_olhar()
	sprite.play_backwards("afundar")
	Util.fx(get_parent(), Vector2(global_position.x - 20.0, chao_y), "areia_jato", 4, 12.0, 1.0, false, Color.WHITE, true)
	Util.fx(get_parent(), Vector2(global_position.x + 20.0, chao_y), "areia_jato", 4, 12.0, 1.0, true, Color.WHITE, true)
	Sons.tocar("desmoronar")
	Jogo.tremer(2.0, 0.5)


func _i4_aparecer() -> void:
	_olhar()
	_tocar("aparecer")
	Util.particulas(get_parent(), global_position, Color("#40ffb0"), 30, 30.0, 110.0, 0.9, -20.0, 2.5)
	Sons.tocar("teleporte")
	Jogo.tremer(1.5, 0.4)


func _i5_chegar() -> void:
	position = Vector2(arena_max - 20.0, chao_y - 230.0)
	voando = true
	_olhar()
	dir = -1
	_anim("voar")
	Sons.tocar("asas")


func _u_i5_pousar(delta: float) -> bool:
	position.x = move_toward(position.x, (arena_min + arena_max) * 0.5, 120.0 * delta)
	position.y = move_toward(position.y, _pe_y(), 140.0 * delta)
	_anim("voar")
	if position.y >= _pe_y() - 1.0:
		voando = false
		velocity = Vector2.ZERO
		return true
	return false


func _i_impacto() -> void:
	Jogo.tremer(4.0, 0.4)
	Util.anel(get_parent(), Vector2(global_position.x, chao_y - 4.0), Color(_info["cor"]), 2.0)
	Util.poeira(get_parent(), Vector2(global_position.x, chao_y - 2.0), 0.0, Color(0.85, 0.8, 0.7, 0.8), 10)
	Sons.tocar("impacto")
	match tipo:
		1:
			_tocar("pouso")
		5:
			_tocar("pouso")
		2:
			_tocar("carregar")
		3:
			_tocar("aviso")


func _i_banner() -> void:
	Jogo.chefe_intro.emit(nome.to_upper(), _info["titulo"])
	Sons.tocar("rugido")
	Jogo.tremer(2.5, 0.8)
	match tipo:
		1: _tocar("esporos")
		2: _tocar("disparo")
		3: _tocar("aviso")
		4: _tocar("invocar")
		5: _tocar("rugido")


func _i_fim() -> void:
	_em_intro = false
	ativo = true
	alvo.congelado = false
	_contato(true)
	hurtbox.set_deferred("monitorable", true)
	sprite.modulate = Color.WHITE
	Jogo.chefe_ativo = true
	Jogo.chefe_nome = nome
	Jogo.chefe_vida = vida
	Jogo.chefe_vida_max = vida_max
	Jogo.chefe_fase = 1
	Jogo.chefe_mudou.emit()
	Jogo.chefe_fase_mudou.emit()
	Sons.musica(_info["musica"])
	_ocioso = 0.6


# ------------------------------------------------------------------ dano, fases e derrota
# Retorna true se o golpe causou dano.
func levar_dano(dano: int, dir_golpe: int) -> bool:
	if morto or not ativo or _intang:
		return false
	if _bloqueio and dir_golpe == -dir and dano < 5:
		Sons.tocar_var("escudo")
		Util.faiscas(get_parent(), global_position + Vector2(dir * 26.0, -8.0), Color("#9ae8ff"))
		_bloqueios_feitos += 1
		return false
	var total := int(round(float(dano) * mult_dano))
	vida -= maxi(total, 1)
	Jogo.chefe_vida = maxi(vida, 0)
	Jogo.chefe_mudou.emit()
	Sons.tocar_var("acerto_forte" if vulneravel else "dano", -2.0)
	sprite.self_modulate = Color(3, 3, 3)
	create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.2)
	Util.particulas(get_parent(), global_position + Vector2(0, -8), _info["cor"], 8, 40.0, 110.0, 0.45, 200.0, 2.2)
	if vida <= 0:
		_derrotar()
		return true
	_checar_fase()
	return true


func _checar_fase() -> void:
	var nova := 1
	if vida <= int(vida_max * 0.33):
		nova = 3
	elif vida <= int(vida_max * 0.66):
		nova = 2
	if nova > fase:
		fase = nova
		Jogo.chefe_fase = fase
		Jogo.chefe_fase_mudou.emit()
		_transicao_fase()


func _transicao_fase() -> void:
	_passos = []
	_agenda.clear()
	_bloqueio = false
	_s_fim_vuln()
	_contato(true)
	velocity.x = 0.0
	_intang = true
	_tinta = Color.WHITE
	_limpar_clones()
	sprite.visible = true
	_seq([[1.2, _s_fase_ini], [0.0, _s_fase_fim]])


func _s_fase_ini() -> void:
	match tipo:
		1: _tocar("esporos")
		2: _tocar("carregar")
		3: _tocar("aviso")
		4: _tocar("invocar")
		5: _tocar("rugido")
	Sons.tocar("rugido")
	Sons.tocar("aviso")
	Jogo.tremer(3.5, 0.7)
	Util.anel(get_parent(), global_position + Vector2(0, 10), _info["cor"], 2.0)
	Util.explosao(get_parent(), global_position, _info["cor"], 1.0)
	Jogo.mensagem.emit("%s está furioso!" % nome)


func _s_fase_fim() -> void:
	_intang = false


func _derrotar() -> void:
	morto = true
	ativo = false
	_passos = []
	_agenda.clear()
	_limpar_clones()
	_contato(false)
	hurtbox.set_deferred("monitorable", false)
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.visible = true
	sprite.self_modulate = Color.WHITE
	Jogo.chefes_derrotados[tipo - 1] = true
	Jogo.chefe_ativo = false
	Jogo.chefe_mudou.emit()
	Sons.musica("")
	Sons.tocar("morte_chefe")
	Jogo.tremer(4.0, 1.6)
	Jogo.congelar(0.2)
	sprite.stop()
	sprite.play("morte")
	if alvo and is_instance_valid(alvo):
		alvo.comemorar()
	for i in 9:
		_depois(0.2 * float(i), _boom)
	_depois(2.3, _fim_morte)


func _boom() -> void:
	Util.explosao(get_parent(), global_position + Vector2(randf_range(-_tam.x * 0.6, _tam.x * 0.6), randf_range(-_tam.y * 0.7, _tam.y * 0.3)), _info["cor"], 1.0)
	Sons.tocar_var("explosao", -4.0)
	Jogo.tremer(2.5, 0.2)


func _fim_morte() -> void:
	for i in 20:
		Util.soltar_item(get_parent(), global_position + Vector2(randf_range(-24, 24), -10), "moeda", 10)
	for i in randi_range(1, 3):
		Util.soltar_item(get_parent(), global_position + Vector2(randf_range(-16, 16), -16), "coracao", 1)
	Jogo.mensagem.emit("%s derrotado! Saia pela porta da esquerda do mundo." % nome)
	if alvo and is_instance_valid(alvo):
		alvo.pose_vitoria = false
		alvo.congelado = false
	Sons.musica("mundo_%d" % tipo)
	derrotado.emit()
	queue_free()


func _limpar_clones() -> void:
	for c in _clones:
		if is_instance_valid(c):
			c.queue_free()
	_clones.clear()


# ================================================================== escolha de ataque e comportamento parado
func _opcoes() -> Array:
	var o: Array = []
	match tipo:
		1:
			o = ["_a1_salto", "_a1_esporos", "_a1_rolada"]
			if fase >= 2:
				o.append("_a1_raizes")
			if fase >= 3:
				o.append("_a1_invocar")
		2:
			o = ["_a2_leque", "_a2_anel", "_a2_soco"]
			if fase >= 2:
				o.append("_a2_estalactites")
		3:
			o = ["_a3_investida", "_a3_cauda", "_a3_enterrar"]
			if absf(alvo.global_position.x - global_position.x) < 120.0:
				o.append("_a3_garras")
				o.append("_a3_garras")
			if fase >= 2:
				o.append("_a3_defesa")
		4:
			o = ["_a4_corte", "_a4_laminas", "_a4_barragem"]
			if fase >= 2:
				o.append("_a4_ilusoes")
			if fase >= 3:
				o.append("_a4_invocar")
		5:
			if voando:
				o = ["_a5_fogo", "_a5_mergulho"]
				if fase >= 2:
					o.append("_a5_meteoros")
			else:
				o = ["_a5_decolar", "_a5_sopro"]
				if absf(alvo.global_position.x - global_position.x) < 130.0:
					o.append("_a5_cauda")
					o.append("_a5_cauda")
				if fase >= 2:
					o.append("_a5_meteoros")
	return o


func _escolher_ataque() -> void:
	if _proximo != "":
		var forcado := _proximo
		_proximo = ""
		_ultimo = forcado
		call(forcado)
		return
	var opcoes := _opcoes()
	if opcoes.size() > 1:
		opcoes.erase(_ultimo)
	var escolhido: String = opcoes[randi() % opcoes.size()]
	_ultimo = escolhido
	call(escolhido)


func _ia_ocioso(delta: float) -> void:
	match tipo:
		1, 2, 3:
			_olhar()
			var d := absf(alvo.global_position.x - global_position.x)
			var v: float = _info["vel"]
			if d > 90.0 and is_on_floor():
				velocity.x = dir * v
				_anim("andar")
			else:
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
				_anim("parado")
		4:
			_olhar()
			position.y = _hover_y + sin(_t * 2.2) * 5.0
			var d := absf(alvo.global_position.x - global_position.x)
			velocity.x = dir * 38.0 if d > 120.0 else move_toward(velocity.x, 0.0, 300.0 * delta)
			_anim("parado")
		5:
			_olhar()
			if voando:
				position.y = _hover_y + sin(_t * 2.6) * 6.0
				var alvo_x := clampf(alvo.global_position.x, arena_min + 60.0, arena_max - 60.0)
				position.x = move_toward(position.x, alvo_x, 40.0 * delta)
				_anim("voar")
			else:
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
				_anim("pousado")


# ================================================================== 1. REI COGUMELO
# Salto esmagador: pula onde você estava; ao pousar solta ondas no chão (pule por cima!) e fica tonto.
func _a1_salto() -> void:
	_seq([[0.5, _s1_agachar], [0.01, _s1_saltar], [3.0, null, _u_esperar_chao], [0.95, _s1_pouso, _u_parar], [0.0, _s_fim_vuln]])


func _s1_agachar() -> void:
	_olhar()
	_tocar("agachar")
	_tx = clampf(alvo.global_position.x, arena_min + 40.0, arena_max - 40.0)
	Util.aviso(get_parent(), Vector2(_tx, chao_y - 2.0), "circulo", Vector2(46, 46), Color(1.0, 0.3, 0.3), 0.55 + 0.95)
	Sons.tocar("aviso", -6.0)
	_tinta = Color(1.2, 0.9, 0.9)


func _s1_saltar() -> void:
	_tinta = Color.WHITE
	var tv := 0.96
	velocity = Vector2(clampf((_tx - position.x) / tv, -250.0, 250.0), -430.0)
	_tocar("pular")
	Sons.tocar("pulo", -4.0, 0.7)


func _s1_pouso() -> void:
	velocity.x = 0.0
	_tocar("pouso")
	_vuln(2.0)
	Jogo.tremer(3.5, 0.3)
	Util.anel(get_parent(), Vector2(global_position.x, chao_y - 4.0), Color("#ffe070"), 1.5)
	Util.poeira(get_parent(), Vector2(global_position.x, chao_y - 2.0), 0.0, Color(0.7, 0.55, 0.4, 0.8), 8)
	Sons.tocar("impacto")
	_ondas(130.0)
	if fase >= 2:
		_depois(0.4, _ondas.bind(175.0))
	if fase >= 3:
		_depois(0.8, _ondas.bind(120.0))


func _ondas(vel: float) -> void:
	for lado in [-1, 1]:
		_tiro(Vector2(lado * vel, 0.0), Color("#ffe070"), "onda", 0.0, 1.6, Vector2(lado * 14.0, _tam.y * 0.5 - 6.0))
	Sons.tocar_var("explosao", -8.0)


# Chuva de esporos: lançados para o alto, caem em arco espalhados pela arena.
func _a1_esporos() -> void:
	_seq([[0.7, _s1_esp_carregar], [0.9, _s1_esp_disparo], [0.4, _s1_esp_fim]])


func _s1_esp_carregar() -> void:
	_olhar()
	_tocar("esporos")
	_tinta = Color(0.85, 1.3, 0.85)
	Sons.tocar("invocar", -4.0)


func _s1_esp_disparo() -> void:
	var n := 5 + 2 * (fase - 1)
	for i in n:
		_depois(0.1 * float(i), _esporo)
	Sons.tocar("cuspe")
	Jogo.tremer(1.5, 0.2)


func _esporo() -> void:
	var vx := randf_range(-110.0, 110.0)
	_tiro(Vector2(vx, randf_range(-250.0, -170.0)), Color("#9be85a"), "esporo", 230.0, 4.0, Vector2(0.0, -28.0))


func _s1_esp_fim() -> void:
	_tinta = Color.WHITE


# Rolada: vira uma bola de espinhos e atravessa a arena; ao bater na parede fica tonto.
func _a1_rolada() -> void:
	_seq([[0.75, _s1_rolar_aviso], [4.0, _s1_rolar_ini, _u_rolar], [1.8, _s1_atordoar, _u_parar], [0.0, _s_fim_vuln]])


func _s1_rolar_aviso() -> void:
	_olhar()
	_tocar("agachar")
	var parede := arena_max if dir > 0 else arena_min
	var larg := absf(parede - position.x)
	Util.aviso(get_parent(), Vector2((position.x + parede) * 0.5, chao_y - 3.0), "retangulo", Vector2(larg, 6.0), Color(1.0, 0.3, 0.3), 0.75)
	Sons.tocar("aviso")
	_tinta = Color(1.4, 0.8, 0.8)


func _s1_rolar_ini() -> void:
	_tinta = Color.WHITE
	_tocar("rolar")
	_rol_dir = dir
	_rol_quicadas = 0
	Sons.tocar("rugido", -8.0, 1.4)


func _u_rolar(_delta: float) -> bool:
	velocity.x = _rol_dir * (205.0 + 35.0 * float(fase))
	if int(_passo_t * 25.0) % 3 == 0:
		Util.poeira(get_parent(), Vector2(global_position.x, chao_y - 2.0), float(_rol_dir), Color(0.7, 0.55, 0.4, 0.8), 2)
	var na_parede := is_on_wall() or position.x <= arena_min + _tam.x * 0.5 + 2.0 or position.x >= arena_max - _tam.x * 0.5 - 2.0
	if na_parede and _passo_t > 0.25:
		if fase >= 2 and _rol_quicadas < 1:
			_rol_dir = -_rol_dir
			_rol_quicadas += 1
			Jogo.tremer(2.0, 0.12)
			Sons.tocar_var("impacto", -8.0)
			_passo_t = 0.3
			return false
		return true
	return false


func _s1_atordoar() -> void:
	velocity.x = 0.0
	_tocar("atordoado")
	_vuln(3.0)
	Jogo.tremer(3.0, 0.25)
	Sons.tocar("impacto")
	Util.particulas(get_parent(), global_position + Vector2(0, -_tam.y * 0.5), Color("#ffe27a"), 10, 30.0, 90.0, 0.7, 120.0, 2.0)


# Raízes: surgem do chão sob você (plataformas e cogumelos-mola são seguros).
func _a1_raizes() -> void:
	_seq([[0.5, _s1_raiz_ini], [1.0, _s1_raiz_surge], [0.3]])


func _s1_raiz_ini() -> void:
	_olhar()
	_tocar("raizes")
	Sons.tocar("aviso", -6.0)


func _s1_raiz_surge() -> void:
	var px := alvo.global_position.x
	var offs: Array = [0.0, -46.0, 46.0]
	if fase >= 3:
		offs = [0.0, -46.0, 46.0, -92.0, 92.0]
	var i := 0
	for o in offs:
		_erupcao(clampf(px + float(o), arena_min + 12.0, arena_max - 12.0), "raiz", Vector2(16, 34), 0.75 + 0.12 * float(i), Color(0.5, 1.0, 0.3))
		i += 1


# Invocação (fase 3): chama cogumelinhos saltitantes.
func _a1_invocar() -> void:
	_seq([[0.9, _s1_inv_ini], [0.01, _s1_inv_spawn], [0.6, _s1_inv_fim]])


func _s1_inv_ini() -> void:
	_tocar("invocar")
	Sons.tocar("invocar")
	_tinta = Color(1.2, 0.9, 1.4)
	for x in [arena_min + 70.0, arena_max - 70.0]:
		Util.aviso(get_parent(), Vector2(x, chao_y - 2.0), "circulo", Vector2(30, 30), Color(0.8, 0.4, 1.0), 0.9)


func _s1_inv_spawn() -> void:
	if get_tree().get_nodes_in_group("inimigos").size() < 3:
		for x in [arena_min + 70.0, arena_max - 70.0]:
			_invocar_inimigo("cogumelo", Vector2(x, chao_y), 2)


func _s1_inv_fim() -> void:
	_tinta = Color.WHITE


# ================================================================== 2. GOLEM DE GELO
# Leque de estilhaços que congelam (lentidão). Fica mais denso a cada fase.
func _a2_leque() -> void:
	var lista: Array = [[0.6, _s2_carregar], [0.01, _s2_leque_tiro], [0.55], [0.01, _s2_leque_tiro], [0.5]]
	if fase >= 3:
		lista = [[0.6, _s2_carregar], [0.01, _s2_leque_tiro], [0.45], [0.01, _s2_leque_tiro], [0.45], [0.01, _s2_leque_tiro], [0.5]]
	_seq(lista)


func _s2_carregar() -> void:
	_olhar()
	_tocar("carregar")
	Sons.tocar("gelo", -4.0)
	var origem := global_position + Vector2(0, -26)
	var d := (alvo.global_position + Vector2(0, -6) - origem)
	var a := Aviso.new()
	a.configurar("linha", Vector2(190, 2), Color(0.5, 0.9, 1.0), 0.6)
	a.position = origem
	a.rotation = d.angle()
	Util.adicionar(get_parent(), a)


func _s2_leque_tiro() -> void:
	_olhar()
	_tocar("disparo")
	var n := 3 + 2 * (fase - 1)
	var origem := Vector2(0, -26)
	var aim := (alvo.global_position + Vector2(0, -6) - (position + origem)).normalized()
	for i in n:
		var ang := (float(i) - float(n - 1) * 0.5) * 0.26
		_tiro(aim.rotated(ang) * 135.0, Color("#9ae8ff"), "gelo", 0.0, 4.0, origem, {"congela": true})
	Sons.tocar_var("gelo")
	Jogo.tremer(1.0, 0.1)


# Anéis de orbes que se expandem. Depois do último, o núcleo fica exposto (dano x3).
func _a2_anel() -> void:
	var lista: Array = [[0.8, _s2_anel_carregar], [0.01, _s2_anel_onda.bind(0.0)], [0.6], [0.01, _s2_anel_onda.bind(0.22)], [0.6]]
	if fase >= 3:
		lista += [[0.01, _s2_anel_onda.bind(0.11)], [0.6]]
	lista += [[2.4, _s2_aberto, _u_parar], [0.0, _s_fim_vuln]]
	_seq(lista)


func _s2_anel_carregar() -> void:
	_tocar("carregar")
	Sons.tocar("invocar", -4.0)
	Util.anel(get_parent(), global_position + Vector2(0, -26), Color("#bfe6ff"), 1.5)


func _s2_anel_onda(desloc: float) -> void:
	_pose("carregar", 2)
	var n := 14
	for i in n:
		var ang := desloc + float(i) * TAU / float(n)
		_tiro(Vector2.RIGHT.rotated(ang) * (68.0 + 10.0 * float(fase)), Color.WHITE, "bola_neve", 0.0, 5.0, Vector2(0, -26), {"congela": true})
	Sons.tocar_var("gelo", -2.0)
	Jogo.tremer(1.5, 0.15)


func _s2_aberto() -> void:
	_tocar("aberto")
	_vuln(3.0)
	Sons.tocar("aviso")
	Util.particulas(get_parent(), global_position + Vector2(0, -20), Color("#5affee"), 14, 30.0, 90.0, 0.8, -40.0, 2.0)


# Soco glacial: espinhos de gelo explodem do chão em linha, afastando-se do golem.
func _a2_soco() -> void:
	_seq([[0.65, _s2_soco_carregar], [0.45, _s2_soco_golpe], [1.0, _s2_soco_fim, _u_parar], [0.0, _s_fim_vuln]])


func _s2_soco_carregar() -> void:
	_olhar()
	_tocar("carregar")
	var n := 6 if fase < 2 else 8
	Util.aviso(get_parent(), Vector2(position.x + dir * (34.0 + 15.0 * float(n - 1)), chao_y - 3.0), "retangulo", Vector2(30.0 * float(n), 6.0), Color(0.5, 0.9, 1.0), 0.65)
	Sons.tocar("aviso", -6.0)


func _s2_soco_golpe() -> void:
	_tocar("soco")
	var n := 6 if fase < 2 else 8
	for i in n:
		_erupcao(position.x + dir * (34.0 + 30.0 * float(i)), "gelo_espinho", Vector2(16, 32), 0.1 + 0.11 * float(i), Color(0.5, 0.9, 1.0))
	Jogo.tremer(3.0, 0.3)
	Sons.tocar("impacto")
	Util.anel(get_parent(), Vector2(position.x + dir * 30.0, chao_y - 4.0), Color("#bfe6ff"), 1.2)


func _s2_soco_fim() -> void:
	_vuln(2.0)
	_pose("soco", 2)


# Estalactites (fase 2+): caem do teto onde as marcas aparecem.
func _a2_estalactites() -> void:
	_seq([[0.75, _s2_est_aviso], [1.2, _s2_est_fim]])


func _s2_est_aviso() -> void:
	_tocar("carregar")
	Sons.tocar("gelo")
	var n := 4 + fase
	var xs: Array = [clampf(alvo.global_position.x, arena_min + 20.0, arena_max - 20.0)]
	for i in n - 1:
		xs.append(randf_range(arena_min + 30.0, arena_max - 30.0))
	var k := 0
	for x in xs:
		Util.aviso(get_parent(), Vector2(float(x), chao_y - 2.0), "circulo", Vector2(26, 26), Color(0.6, 0.9, 1.0), 0.85 + 0.08 * float(k))
		_depois(0.85 + 0.08 * float(k), _gota.bind(float(x)))
		k += 1
	Jogo.tremer(1.5, 0.5)


func _gota(x: float) -> void:
	_tiro(Vector2(0, 270.0), Color("#bfe6ff"), "gelo", 0.0, 2.0, Vector2(x - position.x, (chao_y - 240.0) - position.y), {"congela": true, "escala": 1.6})


func _s2_est_fim() -> void:
	_anim("parado")


# ================================================================== 3. ESCORPIÃO REI
# Investida: avisa (cauda erguida, olhos brancos), dispara até a parede e fica atordoado.
func _a3_investida() -> void:
	_seq([[0.85, _s3_aviso], [4.0, _s3_investir_ini, _u_investir], [1.7, _s3_atordoar, _u_parar], [0.0, _s_fim_vuln]])


func _s3_aviso() -> void:
	_olhar()
	_tocar("aviso")
	var parede := arena_max if dir > 0 else arena_min
	Util.aviso(get_parent(), Vector2((position.x + parede) * 0.5, chao_y - 3.0), "retangulo", Vector2(absf(parede - position.x), 6.0), Color(1.0, 0.35, 0.25), 0.85)
	Sons.tocar("aviso")
	Sons.tocar("chiado", -4.0)


func _s3_investir_ini() -> void:
	_tocar("investida")
	_rol_dir = dir


func _u_investir(_delta: float) -> bool:
	velocity.x = _rol_dir * (250.0 + 35.0 * float(fase - 1))
	if int(_passo_t * 25.0) % 3 == 0:
		Util.poeira(get_parent(), Vector2(global_position.x - _rol_dir * 26.0, chao_y - 2.0), float(_rol_dir), Color(0.9, 0.78, 0.5, 0.8), 2)
	var na_parede := is_on_wall() or position.x <= arena_min + _tam.x * 0.5 + 2.0 or position.x >= arena_max - _tam.x * 0.5 - 2.0
	return na_parede and _passo_t > 0.3


func _s3_atordoar() -> void:
	velocity.x = 0.0
	_tocar("atordoado")
	_vuln(3.0)
	Jogo.tremer(3.5, 0.3)
	Sons.tocar("impacto")
	Util.particulas(get_parent(), global_position + Vector2(_rol_dir * 28.0, -6.0), Color("#e8c888"), 14, 40.0, 110.0, 0.6, 220.0, 2.2)


# Golpe de cauda: a cauda desce à frente e cospe veneno em arco.
func _a3_cauda() -> void:
	_seq([[0.75, _s3_cauda_recuo], [0.01, _s3_cauda_golpe], [0.7, _s3_cauda_pos], [0.0, _s_fim_vuln]])


func _s3_cauda_recuo() -> void:
	_olhar()
	_pose("cauda", 0)
	Util.aviso(get_parent(), Vector2(position.x + dir * 72.0, chao_y - 20.0), "retangulo", Vector2(96, 40), Color(1.0, 0.35, 0.45), 0.75)
	Sons.tocar("aviso", -4.0)


func _s3_cauda_golpe() -> void:
	_pose("cauda", 1)
	_depois(0.1, _pose.bind("cauda", 2))
	_hitbox(Vector2(position.x + dir * 72.0, chao_y - 24.0), Vector2(60, 50), 0.28)
	for i in 3:
		_tiro(Vector2(dir * (60.0 + 45.0 * float(i)), -170.0 - 25.0 * float(i)), Color("#7aff3a"), "veneno", 340.0, 3.0, Vector2(dir * 66.0, -14.0))
	Jogo.tremer(2.5, 0.2)
	Sons.tocar("impacto", -4.0)
	Sons.tocar_var("cuspe")
	Util.poeira(get_parent(), Vector2(position.x + dir * 76.0, chao_y - 2.0), float(dir), Color(0.9, 0.78, 0.5, 0.8), 6)


func _s3_cauda_pos() -> void:
	_vuln(2.0)


# Garras: pinçada curta e rápida; nas fases 2+ emenda um golpe de cauda.
func _a3_garras() -> void:
	var lista: Array = [[0.5, _s3_garra_aviso], [0.01, _s3_garra_golpe], [0.45]]
	if fase >= 2:
		lista += [[0.65, _s3_cauda_recuo], [0.01, _s3_cauda_golpe], [0.6, _s3_cauda_pos], [0.0, _s_fim_vuln]]
	_seq(lista)


func _s3_garra_aviso() -> void:
	_olhar()
	_pose("garras", 0)
	Util.aviso(get_parent(), Vector2(position.x + dir * 52.0, chao_y - 15.0), "retangulo", Vector2(84, 28), Color(1.0, 0.45, 0.2), 0.5)
	Sons.tocar("aviso", -8.0)


func _s3_garra_golpe() -> void:
	_pose("garras", 1)
	_hitbox(Vector2(position.x + dir * 52.0, chao_y - 15.0), Vector2(84, 28), 0.2)
	Sons.tocar_var("golpe2", 2.0)
	Jogo.tremer(1.5, 0.1)


# Enterrar: some na areia, persegue por baixo, marca o ponto e emerge sob você (depois fica vulnerável).
func _a3_enterrar() -> void:
	_seq([[0.55, _s3_afundar], [1.7, _s3_subterraneo, _u_subterraneo], [0.85, _s3_marcar], [0.01, _s3_emergir], [1.2, _s3_emergido, _u_parar], [0.0, _s_fim_vuln]])


func _s3_afundar() -> void:
	_tocar("afundar")
	_intang = true
	_contato(false)
	Sons.tocar("desmoronar")
	Util.poeira(get_parent(), Vector2(global_position.x, chao_y - 2.0), 0.0, Color(0.9, 0.78, 0.5, 0.9), 10)


func _s3_subterraneo() -> void:
	sprite.visible = false
	velocity = Vector2.ZERO


func _u_subterraneo(delta: float) -> bool:
	var meta := clampf(alvo.global_position.x, arena_min + _tam.x * 0.5, arena_max - _tam.x * 0.5)
	position.x = move_toward(position.x, meta, 175.0 * delta)
	if int(_passo_t * 14.0) % 2 == 0:
		Util.poeira(get_parent(), Vector2(global_position.x, chao_y - 2.0), 0.0, Color(0.9, 0.78, 0.5, 0.9), 2)
	return false


func _s3_marcar() -> void:
	_tx = clampf(alvo.global_position.x, arena_min + 32.0, arena_max - 32.0)
	position.x = _tx
	Util.aviso(get_parent(), Vector2(_tx, chao_y - 2.0), "circulo", Vector2(62, 62), Color(1.0, 0.4, 0.2), 0.85)
	Sons.tocar("aviso")


func _s3_emergir() -> void:
	sprite.visible = true
	_olhar()
	sprite.speed_scale = 1.0
	sprite.play_backwards("afundar")
	_intang = false
	_contato(true)
	Util.fx(get_parent(), Vector2(_tx, chao_y), "areia_jato", 4, 14.0, 1.2, false, Color.WHITE, true)
	_hitbox(Vector2(_tx, chao_y - 20.0), Vector2(70, 48), 0.3)
	Jogo.tremer(3.0, 0.3)
	Sons.tocar("impacto")


func _s3_emergido() -> void:
	_vuln(2.0)
	_tocar("atordoado")


# Defesa (fase 2+): garras cruzadas bloqueiam golpes frontais. Ataque por trás (pule!) ou espere.
func _a3_defesa() -> void:
	_seq([[0.4, _s3_def_ini], [2.4, _s3_def_guarda, _u_def], [0.01, _s3_def_fim]])


func _s3_def_ini() -> void:
	_olhar()
	_tocar("defesa")
	_bloqueios_feitos = 0
	Sons.tocar("aviso", -6.0)


func _s3_def_guarda() -> void:
	_bloqueio = true
	_tinta = Color(1.25, 1.2, 1.4)


func _u_def(delta: float) -> bool:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _passo_t > 0.5:
		var a := signf(alvo.global_position.x - global_position.x)
		if a != 0.0 and int(a) != dir:
			dir = int(a)      # gira devagar, deixando uma brecha para quem fica atrás
			_bloqueios_feitos = 0
			_passo_t = maxf(_passo_t, 1.4)
	return _bloqueios_feitos >= 2


func _s3_def_fim() -> void:
	_bloqueio = false
	_tinta = Color.WHITE
	if _bloqueios_feitos > 0:
		_proximo = "_a3_garras"      # contra-ataque


# ================================================================== 4. CAVALEIRO FANTASMA
# Teleporte: some, marca onde vai surgir (atrás de você), reaparece e golpeia com onda de lâmina.
func _a4_corte() -> void:
	_seq([[0.4, _s4_sumir], [0.75, _s4_marcar], [0.01, _s4_aparecer], [0.5, _s4_preparar], [0.01, _s4_corte], [0.6, _s4_pos], [0.0, _s_fim_vuln]])


func _s4_sumir() -> void:
	_tocar("sumir")
	_intang = true
	_contato(false)
	Sons.tocar("teleporte")
	Util.particulas(get_parent(), global_position, Color("#40ffb0"), 14, 30.0, 90.0, 0.6, -30.0, 2.0)


func _s4_marcar() -> void:
	sprite.visible = false
	var lado: int = int(alvo.direcao)
	_tx = clampf(alvo.global_position.x - float(lado) * 58.0, arena_min + 30.0, arena_max - 30.0)
	Util.aviso(get_parent(), Vector2(_tx, chao_y - 2.0), "circulo", Vector2(40, 40), Color(0.3, 1.0, 0.7), 0.75)
	Sons.tocar("aviso", -8.0)


func _s4_aparecer() -> void:
	position.x = _tx
	position.y = _hover_y
	sprite.visible = true
	_olhar()
	_tocar("aparecer")
	_intang = false
	_contato(true)
	Sons.tocar("teleporte")
	Util.particulas(get_parent(), global_position, Color("#40ffb0"), 16, 30.0, 100.0, 0.5, -30.0, 2.0)


func _s4_preparar() -> void:
	_olhar()
	_tocar("preparar")
	Util.aviso(get_parent(), Vector2(position.x + dir * 40.0, position.y), "retangulo", Vector2(76, 58), Color(0.3, 1.0, 0.7), 0.5)


func _s4_corte() -> void:
	_tocar("corte")
	_hitbox(Vector2(position.x + dir * 40.0, position.y), Vector2(76, 58), 0.22)
	_onda_lamina(dir, chao_y - 12.0)
	if fase >= 2:
		_onda_lamina(-dir, chao_y - 12.0)
	Jogo.tremer(2.0, 0.15)
	Sons.tocar_var("golpe2", 2.0)


func _onda_lamina(d: int, y_abs: float) -> void:
	_tiro(Vector2(d * 165.0, 0.0), Color("#40ffb0"), "lamina", 0.0, 3.5, Vector2(d * 34.0, y_abs - position.y))


func _s4_pos() -> void:
	_vuln(2.0)
	_pose("corte", 2)


# Ilusões: surgem cópias; só uma é real. As falsas somem com um golpe; todas atacam juntas.
func _a4_ilusoes() -> void:
	_seq([[0.4, _s4_sumir], [0.6, _s4_ilusoes_criar], [1.7, _s4_ilusoes_espera], [0.5, _s4_ilusoes_preparar], [0.01, _s4_ilusoes_corte], [0.9, _s4_ilusoes_pos], [0.0, _s_fim_vuln]])


func _s4_ilusoes_criar() -> void:
	sprite.visible = false
	_limpar_clones()
	var n := 3 if fase < 3 else 4
	var xs: Array = []
	for i in n:
		xs.append(arena_min + 70.0 + (arena_max - arena_min - 140.0) * float(i) / float(n - 1))
	xs.shuffle()
	var real := randi() % n
	for i in n:
		var x: float = xs[i]
		if i == real:
			position.x = x
			position.y = _hover_y
			sprite.visible = true
			_olhar()
			_tocar("aparecer")
			_intang = false
			_contato(true)
		else:
			var c := ClonePrimitivo.new()
			c.frames = frames_res
			c.position = Vector2(x, _hover_y)
			c.dir = 1 if alvo.global_position.x > x else -1
			c.chao_y = chao_y
			Util.adicionar(get_parent(), c)
			_clones.append(c)
		Util.aviso(get_parent(), Vector2(x, chao_y - 2.0), "circulo", Vector2(36, 36), Color(0.3, 1.0, 0.7), 2.2)
	Sons.tocar("invocar")
	Jogo.tremer(1.5, 0.2)


func _s4_ilusoes_espera() -> void:
	_anim("parado")


func _s4_ilusoes_preparar() -> void:
	_olhar()
	_tocar("preparar")
	for c in _clones:
		if is_instance_valid(c):
			c.preparar()
	Sons.tocar("aviso", -4.0)


func _s4_ilusoes_corte() -> void:
	_s4_corte()
	for c in _clones:
		if is_instance_valid(c):
			c.cortar()


func _s4_ilusoes_pos() -> void:
	_vuln(2.0)
	_pose("corte", 2)
	for c in _clones:
		if is_instance_valid(c):
			c.desfazer()
	_clones.clear()


# Invocação (fase 3): chama dois fantasmas lanterna.
func _a4_invocar() -> void:
	_seq([[0.9, _s4_inv_ini], [0.01, _s4_inv_spawn], [1.0, _s4_inv_pos]])


func _s4_inv_ini() -> void:
	_tocar("invocar")
	Sons.tocar("invocar")
	for lado in [-1.0, 1.0]:
		var x := clampf(alvo.global_position.x + lado * 90.0, arena_min + 30.0, arena_max - 30.0)
		Util.aviso(get_parent(), Vector2(x, _hover_y - 10.0), "circulo", Vector2(30, 30), Color(0.3, 1.0, 0.7), 0.9)
		_depois(0.9, _fantasma_em.bind(x))


func _fantasma_em(x: float) -> void:
	if get_tree().get_nodes_in_group("inimigos").size() < 4:
		_invocar_inimigo("fantasma", Vector2(x, _hover_y - 10.0), 1)


func _s4_inv_spawn() -> void:
	pass


func _s4_inv_pos() -> void:
	_vuln(2.0)


# Barragem de almas: orbes em espiral que depois perseguem você (viram devagar).
func _a4_barragem() -> void:
	var lista: Array = [[0.8, _s4_bar_ini], [0.01, _s4_bar_orbes.bind(0.0)], [1.3]]
	if fase >= 3:
		lista += [[0.01, _s4_bar_orbes.bind(0.4)], [1.2]]
	_seq(lista)


func _s4_bar_ini() -> void:
	_tocar("invocar")
	Sons.tocar("invocar", -2.0)
	Util.anel(get_parent(), global_position, Color("#40ffb0"), 1.4)


func _s4_bar_orbes(desloc: float) -> void:
	var n := 8 if fase < 3 else 10
	for i in n:
		_depois(0.07 * float(i), _orbe.bind(desloc + float(i) * TAU / float(n)))
	Jogo.tremer(1.0, 0.2)


func _orbe(ang: float) -> void:
	_tiro(Vector2.RIGHT.rotated(ang) * 88.0, Color("#40ffb0"), "espectro", 0.0, 4.5, Vector2.RIGHT.rotated(ang) * 26.0, {"teleguiado": 42.0})
	Sons.tocar_var("tiro", -10.0)


# Lâminas duplas: uma rente ao chão (pule) e outra na altura de quem pula (fique no chão).
func _a4_laminas() -> void:
	var lista: Array = [[0.65, _s4_lam_ini], [0.01, _s4_lam_disp], [0.8]]
	if fase >= 2:
		lista += [[0.01, _s4_lam_disp], [0.7]]
	_seq(lista)


func _s4_lam_ini() -> void:
	_olhar()
	_tocar("preparar")
	_linha_aviso(Vector2(position.x, chao_y - 12.0), 300.0, dir, 0.65, Color(0.3, 1.0, 0.7))
	_linha_aviso(Vector2(position.x, chao_y - 44.0), 300.0, dir, 0.65, Color(0.3, 1.0, 0.7))
	Sons.tocar("aviso", -6.0)


func _s4_lam_disp() -> void:
	_olhar()
	_tocar("corte")
	_onda_lamina(dir, chao_y - 12.0)
	_depois(0.18, _onda_lamina.bind(dir, chao_y - 46.0))
	Sons.tocar_var("golpe2")
	Jogo.tremer(1.5, 0.1)


# ================================================================== 5. DRAGÃO DE LAVA
# Decolar: sobe e passa a atacar do ar.
func _a5_decolar() -> void:
	_seq([[0.6, _s5_decolar_ini], [2.0, null, _u_subir]])


func _s5_decolar_ini() -> void:
	_olhar()
	_tocar("rugido")
	voando = true
	velocity = Vector2.ZERO
	Sons.tocar("asas")
	Util.poeira(get_parent(), Vector2(global_position.x, chao_y - 2.0), 0.0, Color(0.5, 0.4, 0.4, 0.8), 10)
	Jogo.tremer(2.0, 0.4)


func _u_subir(delta: float) -> bool:
	_anim("voar")
	position.y = move_toward(position.y, _hover_y, 150.0 * delta)
	return position.y <= _hover_y + 1.0


# Chuva de fogo: cruza a arena de um lado a outro disparando bolas de fogo em arco.
func _a5_fogo() -> void:
	_seq([[0.5, _s5_fogo_ini], [5.0, null, _u_strafe], [0.3]])


func _s5_fogo_ini() -> void:
	var meio := (arena_min + arena_max) * 0.5
	_tx = arena_min + 60.0 if position.x > meio else arena_max - 60.0
	dir = 1 if _tx > position.x else -1
	_anim("voar")
	_rol_quicadas = 0
	Sons.tocar("rugido", -6.0)
	Util.aviso(get_parent(), Vector2((position.x + _tx) * 0.5, chao_y - 3.0), "retangulo", Vector2(absf(_tx - position.x), 4.0), Color(1.0, 0.5, 0.15), 0.5)


func _u_strafe(delta: float) -> bool:
	position.x = move_toward(position.x, _tx, (125.0 + 20.0 * float(fase)) * delta)
	position.y = _hover_y + sin(_passo_t * 5.0) * 5.0
	_anim("voar")
	var passo := 0.42 if fase < 3 else 0.32
	if int(_passo_t / passo) > _rol_quicadas:
		_rol_quicadas = int(_passo_t / passo)
		_tiro(Vector2(dir * 55.0 + randf_range(-20.0, 20.0), 85.0), Color("#ff7a1a"), "fogo", 170.0, 3.5, Vector2(dir * 30.0, 18.0))
		Sons.tocar_var("fogo", -6.0)
	return absf(position.x - _tx) < 2.0


# Mergulho: acompanha você, marca o ponto, despenca e causa erupções; depois fica caído (dano x3).
func _a5_mergulho() -> void:
	_seq([[0.55, null, _u_seguir_x], [0.6, _s5_mergulho_marcar], [2.0, _s5_mergulho_ini, _u_mergulhar], [0.01, _s5_impacto], [2.2, _s5_atordoado, _u_parar], [0.0, _s_fim_vuln]])


func _u_seguir_x(delta: float) -> bool:
	_olhar()
	_anim("voar")
	position.x = move_toward(position.x, clampf(alvo.global_position.x, arena_min + 40.0, arena_max - 40.0), 140.0 * delta)
	position.y = _hover_y + sin(_t * 4.0) * 4.0
	return false


func _s5_mergulho_marcar() -> void:
	_tx = clampf(alvo.global_position.x, arena_min + 40.0, arena_max - 40.0)
	position.x = _tx
	Util.aviso(get_parent(), Vector2(_tx, chao_y - 2.0), "circulo", Vector2(64, 64), Color(1.0, 0.35, 0.1), 0.6)
	_tocar("rugido")
	Sons.tocar("aviso")
	Sons.tocar("rugido", -4.0)


func _s5_mergulho_ini() -> void:
	_tocar("mergulho")
	Sons.tocar("asas")


func _u_mergulhar(delta: float) -> bool:
	position.y = move_toward(position.y, _pe_y(), 380.0 * delta)
	return position.y >= _pe_y() - 0.5


func _s5_impacto() -> void:
	voando = false
	position.y = _pe_y()
	velocity = Vector2.ZERO
	var offs: Array = [0.0, 34.0, -34.0, 68.0, -68.0]
	if fase >= 3:
		offs = [0.0, 34.0, -34.0, 68.0, -68.0, 102.0, -102.0]
	var i := 0
	for o in offs:
		_erupcao(clampf(position.x + float(o), arena_min + 10.0, arena_max - 10.0), "jato", Vector2(20, 44), 0.05 + 0.07 * float(i), Color(1.0, 0.5, 0.1))
		i += 1
	Jogo.tremer(5.0, 0.5)
	Util.explosao(get_parent(), Vector2(position.x, chao_y - 6.0), Color("#ff7a1a"), 1.6)
	Sons.tocar("impacto")


func _s5_atordoado() -> void:
	_tocar("atordoado")
	_vuln(3.0)


# Sopro de fogo: inspira (marca o alcance) e varre de baixo para cima, atingindo perto e depois longe.
func _a5_sopro() -> void:
	_seq([[0.85, _s5_sopro_prep], [1.35, _s5_sopro_ini, _u_sopro], [0.5]])


func _s5_sopro_prep() -> void:
	_olhar()
	_tocar("sopro_prep")
	Util.aviso(get_parent(), Vector2(position.x + dir * 110.0, chao_y - 14.0), "retangulo", Vector2(190, 28), Color(1.0, 0.4, 0.1), 0.85)
	Sons.tocar("aviso")
	Sons.tocar("rugido", -8.0, 1.3)


func _s5_sopro_ini() -> void:
	_tocar("sopro")
	_rol_quicadas = 0


func _u_sopro(_delta: float) -> bool:
	_anim("sopro")
	var k := clampf(_passo_t / 1.3, 0.0, 1.0)
	var passos := int(_passo_t / 0.055)
	if passos > _rol_quicadas:
		_rol_quicadas = passos
		var ang := deg_to_rad(lerpf(24.0, -10.0, k))
		var v := Vector2(dir * cos(ang), sin(ang)) * 215.0
		_tiro(v, Color("#ff8a1a"), "fogo", 0.0, 1.3, Vector2(dir * 56.0, -14.0))
		if passos % 5 == 0:
			Sons.tocar_var("fogo", -8.0)
			Jogo.tremer(1.0, 0.08)
	return false


# Cauda: gira de costas e varre o chão atrás de si (quem fica colado leva).
func _a5_cauda() -> void:
	_seq([[0.6, _s5_cauda_aviso], [0.01, _s5_cauda_golpe], [0.7, _s5_cauda_pos], [0.0, _s_fim_vuln]])


func _s5_cauda_aviso() -> void:
	_olhar_contra()
	_pose("cauda", 0)
	Util.aviso(get_parent(), Vector2(position.x - dir * 68.0, chao_y - 15.0), "retangulo", Vector2(120, 30), Color(1.0, 0.35, 0.2), 0.6)
	Sons.tocar("aviso", -4.0)


func _s5_cauda_golpe() -> void:
	_pose("cauda", 1)
	_depois(0.12, _pose.bind("cauda", 2))
	_hitbox(Vector2(position.x - dir * 68.0, chao_y - 15.0), Vector2(120, 30), 0.3)
	Jogo.tremer(3.0, 0.25)
	Sons.tocar_var("golpe2", 3.0)
	Util.poeira(get_parent(), Vector2(position.x - dir * 90.0, chao_y - 2.0), float(-dir), Color(0.6, 0.4, 0.35, 0.8), 8)


func _s5_cauda_pos() -> void:
	_vuln(2.0)


# Meteoros (fase 2+): círculos no chão mostram onde cada rocha vai cair.
func _a5_meteoros() -> void:
	_seq([[0.9, _s5_met_ini], [2.4, _s5_met_chuva], [0.3]])


func _s5_met_ini() -> void:
	_tocar("rugido")
	Sons.tocar("rugido")
	Jogo.tremer(2.5, 0.8)


func _s5_met_chuva() -> void:
	var n := 6 if fase < 3 else 9
	var xs: Array = [clampf(alvo.global_position.x, arena_min + 20.0, arena_max - 20.0)]
	for i in n - 1:
		xs.append(randf_range(arena_min + 24.0, arena_max - 24.0))
	var k := 0
	for x in xs:
		_depois(0.14 * float(k), _meteoro_aviso.bind(float(x)))
		k += 1


func _meteoro_aviso(x: float) -> void:
	Util.aviso(get_parent(), Vector2(x, chao_y - 2.0), "circulo", Vector2(30, 30), Color(1.0, 0.35, 0.1), 0.8)
	_depois(0.8, _meteoro.bind(x))


func _meteoro(x: float) -> void:
	_tiro(Vector2(0.0, 300.0), Color("#ff7a1a"), "meteoro", 0.0, 2.5, Vector2(x - position.x, (chao_y - 250.0) - position.y), {"explode": "fogo"})
	Sons.tocar_var("fogo", -6.0)
