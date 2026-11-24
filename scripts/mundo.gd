extends Node2D
# Monta cada lugar do jogo (saguão, sala do trono e as 5 fases) a partir de Jogo.mundo_atual.
# O cenário é pintado nas TileMapLayers; o TileSet é criado aqui a partir de arte/tiles/tileset.png.
# Cada mundo tem sua própria "arquitetura" (funções _fase_1 ... _fase_5) e sua própria atmosfera.

const TAM := 16
const ALTURA := 17
const LINHA_CHAO := 13
const LARG_ARENA := 40

const PORTA := preload("res://cenas/porta.tscn")
const INIMIGO := preload("res://cenas/inimigo.tscn")
const CHEFE := preload("res://cenas/chefe.tscn")
const TRONO := preload("res://cenas/trono.tscn")
const ITEM := preload("res://cenas/item.tscn")
const PERIGO := preload("res://scripts/ambiente/perigo.gd")
const GEISER := preload("res://scripts/ambiente/geiser.gd")
const ESTALACTITE := preload("res://scripts/ambiente/estalactite.gd")
const MOLA := preload("res://scripts/ambiente/mola.gd")
const MOVEL := preload("res://scripts/ambiente/plataforma_movel.gd")
const FRAGIL := preload("res://scripts/ambiente/plataforma_fragil.gd")
const SEGREDO := preload("res://scripts/ambiente/segredo.gd")
const ZONA_GELO := preload("res://scripts/ambiente/zona_gelo.gd")
const PORTAO := preload("res://scripts/ambiente/portao.gd")

const MUNDOS := [
	{"nome": "Floresta dos Cogumelos", "largura": 150, "chefe": "Rei Cogumelo", "mod": Color(0.90, 1.0, 0.94), "poeira": Color(0.62, 0.5, 0.36, 0.8), "amb": "amb_floresta"},
	{"nome": "Montanha Gelada", "largura": 150, "chefe": "Golem de Gelo", "mod": Color(0.86, 0.93, 1.06), "poeira": Color(0.9, 0.96, 1.0, 0.8), "amb": "amb_vento"},
	{"nome": "Deserto Ardente", "largura": 150, "chefe": "Escorpião Rei", "mod": Color(1.02, 0.94, 0.84), "poeira": Color(0.92, 0.78, 0.5, 0.8), "amb": "amb_deserto"},
	{"nome": "Castelo Assombrado", "largura": 150, "chefe": "Cavaleiro Fantasma", "mod": Color(0.66, 0.62, 0.84), "poeira": Color(0.6, 0.56, 0.8, 0.7), "amb": "amb_castelo"},
	{"nome": "Vulcão Infernal", "largura": 150, "chefe": "Dragão de Lava", "mod": Color(0.88, 0.74, 0.70), "poeira": Color(0.5, 0.36, 0.34, 0.8), "amb": "amb_fogo"},
]

# decorações pequenas que nascem no chão (colunas do tileset) e a que fica pendurada, por tema
const DECOR_CHAO := {
	0: [9, 9, 10, 11, 12, 15],
	1: [9, 10, 10, 11, 12, 15],
	2: [9, 10, 11, 12, 15, 15],
	3: [9, 10, 11, 15],
	4: [9, 10, 11, 12, 15],
}
const DECOR_PEND := {0: 14, 1: 14, 3: 14, 4: 14}

var largura := 0
var alturas: Array[int] = []
var _tema := 0
var _rng := RandomNumberGenerator.new()
var _ax := 0                       # coluna do portão da arena
var _portao: Node
var _cam: Camera2D

@onready var fundo: ParallaxBackground = $Fundo
@onready var cenario: Node2D = $Cenario
@onready var chao: TileMapLayer = $Cenario/Chao
@onready var decoracao: TileMapLayer = $Cenario/Decoracao
@onready var entidades: Node2D = $Entidades
@onready var jogador: CharacterBody2D = $Jogador

var props: Node2D


func _ready() -> void:
	var ts := _criar_tileset()
	chao.tile_set = ts
	decoracao.tile_set = ts
	props = Node2D.new()
	props.name = "Props"
	props.z_index = -1
	cenario.add_child(props)
	_cam = jogador.get_node("Camera")
	var musica := "hub"
	match Jogo.mundo_atual:
		"hub":
			_tema = 5
			_montar_saguao()
		"trono":
			_tema = 6
			musica = "trono"
			_montar_trono()
		_:
			var n := int(Jogo.mundo_atual)
			_tema = n - 1
			musica = "mundo_%d" % n
			_montar_fase(n)
	_montar_fundo(_tema)
	_atmosfera(_tema)
	var mod := Color(0.9, 0.88, 1.0)
	var amb := ""
	if _tema <= 4:
		mod = MUNDOS[_tema]["mod"]
		amb = MUNDOS[_tema]["amb"]
		jogador.cor_poeira = MUNDOS[_tema]["poeira"]
	elif _tema == 6:
		mod = Color(0.95, 0.82, 0.82)
		amb = "amb_castelo"
	var cm := CanvasModulate.new()
	cm.color = mod
	add_child(cm)
	Util.luz(jogador, Vector2(0, -6), Color(1.0, 0.95, 0.85), 0.55, 1.1)
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = largura * TAM
	_cam.limit_bottom = ALTURA * TAM
	jogador.ultimo_seguro = jogador.position
	_cam.reset_smoothing()
	Sons.musica(musica)
	Sons.ambiente(amb)


# ---------------- TileSet ----------------
func _criar_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TAM, TAM)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var fonte := TileSetAtlasSource.new()
	fonte.texture = load("res://arte/tiles/tileset.png")
	fonte.texture_region_size = Vector2i(TAM, TAM)
	ts.add_source(fonte, 0)
	var quadrado := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var laje := PackedVector2Array([Vector2(-8, -6), Vector2(8, -6), Vector2(8, 2), Vector2(-8, 2)])
	var ponte := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -4), Vector2(-8, -4)])
	for linha in 7:
		for coluna in 16:
			var c := Vector2i(coluna, linha)
			fonte.create_tile(c)
			# colunas 0-7 sólidas (2, 6 e 7 são lajes finas); 8 é ponte de mão única; 9-15 só decoração
			if coluna <= 8:
				var dados := fonte.get_tile_data(c, 0)
				dados.add_collision_polygon(0)
				if coluna == 8:
					dados.set_collision_polygon_points(0, 0, ponte)
					dados.set_collision_polygon_one_way(0, 0, true)
				elif coluna == 2 or coluna == 6 or coluna == 7:
					dados.set_collision_polygon_points(0, 0, laje)
				else:
					dados.set_collision_polygon_points(0, 0, quadrado)
	return ts


func _pintar(camada: TileMapLayer, x: int, y: int, coluna: int) -> void:
	camada.set_cell(Vector2i(x, y), 0, Vector2i(coluna, _tema))


func _livre(x: int, y: int) -> bool:
	return chao.get_cell_source_id(Vector2i(x, y)) == -1


# ---------------- ferramentas de construção (coordenadas em blocos de 16 px) ----------------
func _alturas_planas() -> void:
	alturas.clear()
	for x in largura:
		alturas.append(LINHA_CHAO)


func _trecho(x0: int, x1: int, y: int) -> void:
	for x in range(maxi(x0, 0), mini(x1, largura)):
		alturas[x] = y


func _buraco(x0: int, x1: int) -> void:
	_trecho(x0, x1, ALTURA)


func _pintar_terreno() -> void:
	for x in largura:
		var h := alturas[x]
		for y in range(h, ALTURA):
			var col := 1
			if y == h:
				col = 4 if _rng.randf() < 0.4 else 0
			elif _rng.randf() < 0.12:
				col = 5
			_pintar(chao, x, y, col)
	for y in ALTURA:   # paredes laterais
		_pintar(chao, -1, y, 3)
		_pintar(chao, largura, y, 3)


func _plat(x: int, y: int, w: int) -> void:
	if y < 3:
		return
	for i in w:
		if x + i < largura - 1:
			var col := 2
			if w >= 2 and i == 0:
				col = 6
			elif w >= 2 and i == w - 1:
				col = 7
			_pintar(chao, x + i, y, col)
	if _rng.randf() < 0.7 and w >= 2:
		var pend: int = DECOR_PEND.get(_tema, -1)
		if pend >= 0:
			_pintar(decoracao, x + _rng.randi_range(0, w - 1), y + 1, pend)


func _ponte(x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1):
		_pintar(chao, x, y, 8)


func _bloco(x0: int, y0: int, x1: int, y1: int, topo := true) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			_pintar(chao, x, y, (4 if x % 3 == 0 else 0) if (topo and y == y0) else (5 if (x + y) % 5 == 0 else 1))


func _parede(x0: int, y0: int, x1: int, y1: int) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			_pintar(chao, x, y, 3)


func _teto(x0: int, x1: int, linhas: int) -> void:
	for x in range(x0, x1):
		for y in linhas:
			_pintar(chao, x, y, 3)
		var pend: int = DECOR_PEND.get(_tema, -1)
		if pend >= 0 and _rng.randf() < 0.45:
			_pintar(decoracao, x, linhas, pend)


func _deco(x: int, y: int, col: int) -> void:
	_pintar(decoracao, x, y, col)


func _prop(nome: String, x: float, linha_base: int, z := -1, escala := 1.0) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://arte/props/m%d_%s.png" % [_tema + 1, nome])
	s.scale = Vector2(escala, escala)
	s.position = Vector2(x * TAM + 8.0, linha_base * TAM - s.texture.get_height() * 0.5 * escala)
	s.z_index = z
	props.add_child(s)


func _prop_de(mundo: int, nome: String, x: float, linha_base: int, z := -1) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://arte/props/m%d_%s.png" % [mundo, nome])
	s.position = Vector2(x * TAM + 8.0, linha_base * TAM - s.texture.get_height() * 0.5)
	s.z_index = z
	props.add_child(s)


func _luz_em(x_px: float, y_px: float, cor: Color, energia := 0.8, esc := 1.0) -> void:
	Util.luz(entidades, Vector2(x_px, y_px), cor, energia, esc)


func _tocha(x: int, y: int, col: int) -> void:
	_deco(x, y, col)
	_luz_em(x * TAM + 8.0, y * TAM + 6.0, Color(1.0, 0.7, 0.35), 0.85, 1.3)


# ---- objetos do cenário
func _moeda(x_px: float, y_px: float) -> void:
	var it = ITEM.instantiate()
	it.iniciar("moeda", 5, true)
	it.position = Vector2(x_px, y_px)
	entidades.add_child(it)


func _coracao(x_px: float, y_px: float) -> void:
	var it = ITEM.instantiate()
	it.iniciar("coracao", 1, true)
	it.position = Vector2(x_px, y_px)
	entidades.add_child(it)


func _linha_moedas(x_px: float, y_px: float, n: int, passo := 16.0) -> void:
	for i in n:
		_moeda(x_px + float(i) * passo, y_px)


func _arco_moedas(x_px: float, y_px: float, n: int, altura := 26.0) -> void:
	for i in n:
		var k := float(i) / float(maxi(n - 1, 1))
		_moeda(x_px + float(i) * 16.0, y_px - sin(k * PI) * altura)


func _inimigo(tipo: String, x: int) -> void:
	_inimigo_em(tipo, x, alturas[x])


func _inimigo_em(tipo: String, x: int, linha_chao: int) -> void:
	var e = INIMIGO.instantiate()
	e.tipo = tipo
	e.position = Vector2(x * TAM + 8, linha_chao * TAM)
	entidades.add_child(e)


func _voador(tipo: String, x: int, y_px: float) -> void:
	var e = INIMIGO.instantiate()
	e.tipo = tipo
	e.position = Vector2(x * TAM + 8, y_px)
	entidades.add_child(e)


func _fosso(x0: int, x1: int, tipo: String) -> void:
	_buraco(x0, x1)
	var p = PERIGO.new()
	p.modo = "lava" if tipo == "lava" else "espinho"
	p.tema = _tema
	p.larg = x1 - x0
	p.resgata = true
	p.position = Vector2(x0 * TAM, 15 * TAM)
	entidades.add_child(p)


func _espinhos(x: int, w: int, linha_chao := -1) -> void:
	var g := alturas[x] if linha_chao < 0 else linha_chao
	var p = PERIGO.new()
	p.modo = "espinho"
	p.tema = _tema
	p.larg = w
	p.position = Vector2(x * TAM, (g - 1) * TAM)
	entidades.add_child(p)


func _mola(x: int, linha_chao := -1) -> void:
	var g := alturas[x] if linha_chao < 0 else linha_chao
	var m = MOLA.new()
	m.tema = _tema
	m.position = Vector2(x * TAM, (g - 1) * TAM)
	entidades.add_child(m)


func _movel(x: float, linha: int, eixo: Vector2, amp: float, periodo: float, fase := 0.0) -> void:
	var p = MOVEL.new()
	p.tema = _tema
	p.eixo = eixo
	p.amplitude = amp
	p.periodo = periodo
	p.fase = fase
	p.position = Vector2(x * TAM, linha * TAM - 3)
	entidades.add_child(p)


func _fragil(x: int, linha: int) -> void:
	var p = FRAGIL.new()
	p.tema = _tema
	p.position = Vector2(x * TAM, linha * TAM - 3)
	entidades.add_child(p)


func _estalactite(x: int, linha: int) -> void:
	var e = ESTALACTITE.new()
	e.tema = _tema
	e.position = Vector2(x * TAM + 8, linha * TAM)
	entidades.add_child(e)


func _geiser(x: int, linha_chao: int, desloc: float, periodo := 3.6) -> void:
	var g = GEISER.new()
	g.desloc = desloc
	g.periodo = periodo
	g.position = Vector2(x * TAM + 8, linha_chao * TAM)
	entidades.add_child(g)


func _gelo(x: int, w: int) -> void:
	var z = ZONA_GELO.new()
	z.larg = w
	z.position = Vector2(x * TAM, alturas[x] * TAM)
	entidades.add_child(z)


# Sala secreta subterranea: entrada pequena no chao, camara embaixo com tesouro.
func _sala_secreta(x: int, w: int, linha_chao: int, coracao := false) -> void:
	var g := linha_chao
	var entrada_x := x + int(w / 2)
	# buraco de 1 bloco no chao
	chao.erase_cell(Vector2i(entrada_x, g - 1))
	chao.erase_cell(Vector2i(entrada_x, g))
	# cavar a camara embaixo
	for cx in range(x, x + w + 1):
		for cy in range(g + 1, g + 4):
			chao.erase_cell(Vector2i(cx, cy))
	# paredes e chao da camara
	for cx in range(x - 1, x + w + 2):
		_pintar(chao, cx, g + 4, 1)
	for cy in range(g + 1, g + 4):
		_pintar(chao, x - 1, cy, 1)
		_pintar(chao, x + w + 1, cy, 1)
	# parede falsa na entrada (some ao entrar)
	var s = SEGREDO.new()
	s.cel_w = 1
	s.cel_h = 2
	s.tema = _tema
	s.position = Vector2(entrada_x * TAM, (g - 1) * TAM)
	entidades.add_child(s)
	for i in w:
		_moeda((x + 0.5 + float(i)) * TAM + 8.0, (g + 3) * TAM + 4.0)
	if coracao:
		_coracao((x + w) * TAM + 4.0, (g + 3) * TAM + 4.0)


# ---------------- Saguão (5 portas + sala do trono) ----------------
func _criar_porta(x: int, destino: String, saida: int, cor: int, rotulo: String) -> void:
	var p = PORTA.instantiate()
	p.destino = destino
	p.saida_id = saida
	p.indice_cor = cor
	p.rotulo = rotulo
	p.position = Vector2((x + 0.5) * TAM, LINHA_CHAO * TAM)
	entidades.add_child(p)


func _criar_loja(x: int, nome: String, preco: int, tipo: String) -> void:
	var area = Area2D.new()
	area.set_script(load("res://scripts/ambiente/loja.gd"))
	area.nome = nome
	area.preco = preco
	area.tipo = tipo
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = Vector2((x + 0.5) * TAM, LINHA_CHAO * TAM)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(28, 32)
	cs.shape = r
	cs.position = Vector2(0, -16)
	area.add_child(cs)
	var lbl := Label.new()
	lbl.name = "Texto"
	lbl.position = Vector2(-40, -50)
	lbl.size = Vector2(80, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area.add_child(lbl)
	var dica := Label.new()
	dica.name = "Dica"
	dica.text = "[E]"
	dica.position = Vector2(-12, -60)
	area.add_child(dica)
	entidades.add_child(area)


func _montar_saguao() -> void:
	largura = 44
	_rng.seed = 777
	_alturas_planas()
	_pintar_terreno()
	_teto(0, largura, 2)
	var xs := [6, 12, 18, 24, 30]
	var cores := [Color("#7a3fb8"), Color("#7ee0ff"), Color("#e0a82a"), Color("#40ffb0"), Color("#ff7a1a")]
	var nomes_curtos := ["Floresta", "Neve", "Deserto", "Castelo", "Vulcão"]
	for i in 5:
		var nome: String = nomes_curtos[i]
		if Jogo.chefes_derrotados[i]:
			nome += " [OK]"
		_criar_porta(xs[i], str(i + 1), 0, i, nome)
		_luz_em((xs[i] + 0.5) * TAM, (LINHA_CHAO - 2) * TAM, cores[i], 0.9 if not Jogo.chefes_derrotados[i] else 0.45, 1.5)
	_criar_porta(39, "trono", 0, 5, "Sala do Trono")
	_luz_em(39.5 * TAM, (LINHA_CHAO - 2) * TAM, Color("#f4c23f"), 0.9, 1.6)
	for x in [3, 9, 15, 21, 27, 33, 36, 42]:
		_tocha(x, LINHA_CHAO - 1, 15)
	for x in [9, 15, 21, 27, 33]:
		_prop_de(4, "estandarte", x, 9, -2)
	for x in [3, 36, 42]:
		_prop_de(4, "coluna", x, LINHA_CHAO, -2)
	_prop_de(4, "armadura", 1, LINHA_CHAO, -2)
	_prop_de(4, "armadura", 43, LINHA_CHAO, -2)
	var spawn_x := 3.0
	if Jogo.porta_de_saida >= 1 and Jogo.porta_de_saida <= 5:
		spawn_x = xs[Jogo.porta_de_saida - 1] + 1.5
	elif Jogo.porta_de_saida == 6:
		spawn_x = 37.5
	jogador.position = Vector2(spawn_x * TAM, (LINHA_CHAO - 2) * TAM)
	Jogo.mensagem.emit("Escolha uma porta e derrote os 5 chefes!")


# ---------------- Sala do trono ----------------
func _montar_trono() -> void:
	largura = 30
	_rng.seed = 888
	_alturas_planas()
	_pintar_terreno()
	_teto(0, largura, 2)
	_criar_porta(2, "hub", 6, 5, "Saguão")
	for x in [8, 15, 26]:
		_tocha(x, LINHA_CHAO - 1, 15)
	for x in [10, 13, 24]:
		_prop_de(4, "estandarte", x, 9, -2)
	for x in [6, 17, 28]:
		_prop_de(4, "coluna", x, LINHA_CHAO, -2)
	_prop_de(4, "vitral", 20, 9, -3)
	var tr = TRONO.instantiate()
	tr.position = Vector2(20 * TAM, LINHA_CHAO * TAM)
	entidades.add_child(tr)
	_luz_em(20 * TAM + 8.0, (LINHA_CHAO - 3) * TAM, Color("#f4c23f"), 1.0, 2.0)
	_criar_loja(8, "Vida +1", 150, "vida")
	_criar_loja(12, "Dano +1", 250, "dano")
	_criar_loja(25, "Especial cheio", 200, "especial")
	jogador.position = Vector2(5 * TAM, (LINHA_CHAO - 2) * TAM)
	Jogo.mensagem.emit("A coroa está acorrentada... [E] para tentar. Lojas a esquerda!")


# ---------------- Fases ----------------
func _montar_fase(n: int) -> void:
	var cfg: Dictionary = MUNDOS[n - 1]
	largura = cfg["largura"]
	_ax = largura - LARG_ARENA
	_rng.seed = 4242 + n * 97
	_alturas_planas()
	_trecho(_ax - 3, largura, LINHA_CHAO)
	match n:
		1: _fase_1()
		2: _fase_2()
		3: _fase_3()
		4: _fase_4()
		5: _fase_5()
	_trecho(_ax - 3, largura, LINHA_CHAO)      # a arena é sempre plana
	_pintar_terreno()
	_construir_fase_pos(n)
	_arena(n)
	_decorar()
	_criar_porta(2, "hub", n, _tema, "Voltar")
	jogador.position = Vector2(5 * TAM, (LINHA_CHAO - 2) * TAM)
	Jogo.mensagem.emit(cfg["nome"])
	if not Jogo.chefes_derrotados[n - 1]:
		_criar_chefe(n, cfg["chefe"])


# Elementos que dependem de o terreno já estar pintado (pontes, plataformas, etc.).
func _construir_fase_pos(n: int) -> void:
	match n:
		1: _fase_1_pos()
		2: _fase_2_pos()
		3: _fase_3_pos()
		4: _fase_4_pos()
		5: _fase_5_pos()


# ================= 1. FLORESTA DOS COGUMELOS: colinas, copas, pontes de madeira, molas de cogumelo =================
func _fase_1() -> void:
	_trecho(15, 19, 12)
	_trecho(19, 25, 11)
	_trecho(25, 29, 12)
	_trecho(52, 56, 12)
	_trecho(56, 61, 11)
	_trecho(61, 64, 12)
	_trecho(70, 74, 12)
	_trecho(74, 82, 10)
	_trecho(82, 85, 11)
	_trecho(85, 88, 12)
	_buraco(34, 41)
	_buraco(96, 107)


func _fase_1_pos() -> void:
	_fosso(34, 41, "espinho")
	_ponte(34, 41, 13)
	_fosso(96, 107, "espinho")
	_ponte(96, 100, 13)
	_ponte(103, 107, 13)
	_plat(30, 10, 3)
	_plat(44, 10, 5)
	_plat(51, 7, 4)
	_plat(57, 6, 7)
	_plat(65, 9, 3)
	_plat(68, 5, 5)
	_plat(86, 7, 3)
	_mola(47)
	_mola(66)
	_mola(80, 10)
	_sala_secreta(20, 3, 11, true)
	_sala_secreta(89, 5, 13)
	# espinheiros no caminho
	_espinhos(58, 2)
	_espinhos(77, 2)
	# moedas: arcos sobre os fossos, trilhas nas copas
	_arco_moedas(36 * TAM, 12 * TAM, 4)
	_arco_moedas(98 * TAM, 11 * TAM, 6, 34.0)
	_linha_moedas(57 * TAM + 8, 5 * TAM + 4, 7)
	_linha_moedas(68 * TAM + 8, 4 * TAM + 4, 5)
	_linha_moedas(44 * TAM + 8, 9 * TAM + 4, 5)
	_linha_moedas(86 * TAM + 8, 6 * TAM + 4, 3)
	for x in [8, 32, 60, 84, 108]:
		_prop("arvore", x, alturas[x], -2)
	for x in [12, 29, 53, 71, 94]:
		_prop("cogumelo_v" if x % 2 == 0 else "cogumelo_r", x, alturas[x], -2)
	for x in [24, 62, 109]:
		_prop("toco", x, alturas[x], -1)
	for x in [18, 31, 43, 59, 67, 78, 87, 108]:
		_inimigo("cogumelo", x)
	_voador("vespa", 24, 9 * TAM)
	_voador("vespa", 47, 8 * TAM)
	_voador("vespa", 55, 5 * TAM)
	_voador("vespa", 72, 8 * TAM)
	_voador("vespa", 85, 7 * TAM)
	_voador("vespa", 98, 9 * TAM)
	_voador("vespa", 106, 9 * TAM)


# ================= 2. MONTANHA GELADA: gelo escorregadio, caverna de estalactites, pontes de gelo =================
func _fase_2() -> void:
	_trecho(16, 20, 12)
	_trecho(20, 24, 11)
	_trecho(24, 28, 12)
	_buraco(30, 39)
	_buraco(76, 90)
	_trecho(90, 92, 12)
	_trecho(92, 101, 11)
	_trecho(101, 103, 12)


func _fase_2_pos() -> void:
	_fosso(30, 39, "espinho")
	_movel(32, 13, Vector2.RIGHT, 24.0, 5.0, 0.0)
	_movel(36, 13, Vector2.RIGHT, 24.0, 5.0, 2.5)
	_teto(42, 72, 3)
	for x in [46, 50, 53, 58, 63, 68]:
		_estalactite(x, 3)
	_plat(48, 10, 4)
	_plat(56, 10, 4)
	_ponte(60, 68, 10)
	_fosso(76, 90, "espinho")
	_ponte(76, 82, 13)
	_ponte(84, 90, 13)
	_plat(82, 10, 2)
	_gelo(2, 12)
	_gelo(20, 8)
	_gelo(42, 28)
	_gelo(92, 9)
	_gelo(104, 6)
	_sala_secreta(94, 4, 11, true)
	_arco_moedas(31 * TAM, 12 * TAM, 7, 40.0)
	_linha_moedas(48 * TAM + 8, 9 * TAM + 4, 4)
	_linha_moedas(60 * TAM + 8, 9 * TAM + 4, 8)
	_arco_moedas(77 * TAM, 12 * TAM, 12, 36.0)
	for x in [10, 28, 72, 100]:
		_prop("pinheiro", x, alturas[x], -2)
	for x in [18, 40, 74, 92, 105]:
		_prop("cristal", x, alturas[x], -1)
	_prop("arco", 108, 13, -2)
	for x in [20, 43, 55, 71, 93, 103]:
		_inimigo("lobo", x)
	for x in [27, 66, 100, 106]:
		_inimigo("boneco", x)
	_inimigo_em("boneco", 50, 10)
	_inimigo_em("boneco", 58, 10)


# ================= 3. DESERTO ARDENTE: dunas, plataformas frágeis, templo com corredor e telhado =================
func _fase_3() -> void:
	for x in range(12, 64):
		alturas[x] = clampi(13 - int(round(1.6 * sin(float(x) * 0.22))), 11, 14)
	_trecho(24, 32, 13)
	_trecho(38, 40, 13)
	_trecho(52, 62, 13)
	_trecho(62, 64, 12)
	_buraco(40, 52)
	_trecho(64, 66, 12)
	_trecho(66, 68, 11)
	_trecho(68, 70, 10)
	_trecho(70, 98, 13)
	_trecho(98, 100, 11)
	_trecho(100, 102, 12)
	_buraco(102, 107)


func _fase_3_pos() -> void:
	_fosso(40, 52, "espinho")
	_fragil(41, 13)
	_fragil(45, 13)
	_fragil(49, 13)
	_fosso(102, 107, "espinho")
	_fragil(103, 13)
	# templo: telhado (2 blocos de espessura) sobre um corredor baixo com chão de areia
	_bloco(70, 9, 98, 11, true)
	_espinhos(80, 2, 9)         # cactos no telhado
	_plat(104, 9, 3)
	_sala_secreta(86, 4, 9, true)
	_sala_secreta(25, 3, 13)
	_linha_moedas(41 * TAM + 8, 10 * TAM, 9, 16.0)
	_linha_moedas(74 * TAM + 8, 12 * TAM + 4, 14)
	_linha_moedas(76 * TAM + 8, 8 * TAM + 4, 10)
	for x in [8, 30, 58, 62]:
		_prop("palmeira", x, alturas[x], -2)
	_prop("piramide", 20, alturas[20], -3)
	_prop("piramide", 48, 13, -3)
	for x in [14, 36, 67, 100]:
		_prop("obelisco", x, alturas[x], -2)
	for x in [4, 34, 109]:
		_prop("chacal", x, alturas[x], -2)
	for x in [22, 35, 57, 75, 90]:
		_inimigo("escaravelho", x)
	for x in [28, 54, 61, 81, 86, 108]:
		_inimigo("cobra", x)
	for x in [14, 33, 60]:
		_espinhos(x, 1)


# ================= 4. CASTELO ASSOMBRADO: salões, galeria superior, ponte levadiça, plataformas móveis =================
func _fase_4() -> void:
	_trecho(18, 20, 11)
	_trecho(20, 22, 9)
	_buraco(46, 56)
	_buraco(60, 78)
	_trecho(82, 84, 12)
	_trecho(84, 92, 11)
	_trecho(92, 94, 12)


func _fase_4_pos() -> void:
	_teto(8, _ax - 2, 2)
	_ponte(22, 38, 9)
	_plat(38, 9, 2)
	_fosso(46, 56, "espinho")
	_ponte(46, 56, 13)
	_fosso(60, 78, "espinho")
	_movel(62, 12, Vector2.RIGHT, 24.0, 4.5, 0.0)
	_movel(68, 11, Vector2.DOWN, 24.0, 4.0, 1.0)
	_movel(73, 12, Vector2.RIGHT, 24.0, 4.5, 2.2)
	_sala_secreta(86, 4, 11, true)
	_linha_moedas(24 * TAM + 8, 8 * TAM + 4, 12)
	_arco_moedas(47 * TAM, 12 * TAM, 9, 34.0)
	_linha_moedas(86 * TAM, 10 * TAM + 4, 4)
	for x in [14, 30, 44, 58, 80, 96, 104]:
		_prop("coluna", x, alturas[min(x, largura - 1)] if alturas[min(x, largura - 1)] < ALTURA else 13, -2)
	for x in [24, 36, 92]:
		_prop("estandarte", x, 7, -2)
	for x in [12, 100, 106]:
		_prop("armadura", x, alturas[x], -2)
	_prop("vitral", 40, 10, -3)
	_prop("vitral", 90, 10, -3)
	for x in [30, 70, 100]:
		_prop("lustre", x, 6, -1)
		_luz_em(x * TAM + 8.0, 5 * TAM, Color(1.0, 0.75, 0.4), 0.9, 1.8)
	_luz_em(40 * TAM + 8.0, 8 * TAM, Color(0.5, 0.6, 1.0), 0.7, 1.8)
	_luz_em(90 * TAM + 8.0, 8 * TAM, Color(1.0, 0.5, 0.6), 0.7, 1.8)
	for x in [12, 40, 82, 98, 106]:
		_tocha(x, alturas[x] - 1, 15)
	for x in [14, 42, 88, 100]:
		_inimigo("esqueleto", x)
	_inimigo_em("esqueleto", 27, 9)
	_inimigo_em("esqueleto", 34, 9)
	for x in [20, 40, 58, 70, 90, 104]:
		_voador("fantasma", x, 8 * TAM + (x % 3) * 8)


# ================= 5. VULCÃO INFERNAL: lava, gêiseres, degraus de basalto, ponte de pedra =================
func _fase_5() -> void:
	_buraco(22, 30)
	_buraco(40, 54)
	_trecho(58, 60, 12)
	_trecho(60, 62, 11)
	_trecho(62, 64, 10)
	_trecho(64, 66, 9)
	_trecho(66, 70, 9)
	_trecho(70, 72, 10)
	_trecho(72, 74, 11)
	_trecho(74, 76, 12)
	_buraco(90, 102)


func _fase_5_pos() -> void:
	_fosso(22, 30, "lava")
	_fragil(23, 13)
	_fragil(27, 13)
	_fosso(40, 54, "lava")
	_movel(42, 13, Vector2.RIGHT, 24.0, 4.5, 0.0)
	_fragil(46, 12)
	_movel(51, 12, Vector2.UP, 26.0, 4.0, 1.5)
	_fosso(90, 102, "lava")
	_ponte(90, 95, 13)
	_ponte(97, 102, 13)
	for i in 3:
		_geiser(78 + i * 4, 13, float(i) * 1.2)
	_geiser(34, 13, 0.0, 4.2)
	_geiser(67, 9, 1.0, 4.0)
	_sala_secreta(104, 3, 13, true)
	_arco_moedas(23 * TAM, 12 * TAM, 7, 32.0)
	_arco_moedas(41 * TAM, 11 * TAM, 13, 42.0)
	_linha_moedas(66 * TAM + 8, 8 * TAM + 4, 4)
	_arco_moedas(91 * TAM, 12 * TAM, 11, 34.0)
	for x in [10, 36, 56, 78, 108]:
		_prop("basalto", x, alturas[x], -2)
	for x in [18, 61, 84]:
		_prop("cristal", x, alturas[x], -1)
	for x in [8, 57]:
		_prop("costelas", x, alturas[x], -2)
	for x in [14, 58, 88]:
		_prop("obelisco", x, alturas[x], -2)
	_prop("morta", 32, 13, -2)
	for x in [16, 33, 56, 75, 84]:
		_inimigo("salamandra", x)
	for x in [26, 44, 62, 80, 96, 106]:
		_voador("morcego", x, 5 * TAM + (x % 4) * 6)
	for x in [10, 36, 68, 86]:
		_tocha(x, alturas[x] - 1, 13)


# ---------------- arena do chefe ----------------
func _arena(n: int) -> void:
	var ax := _ax
	var s := Sprite2D.new()
	s.texture = load("res://arte/fundos/arena_%d.png" % n)
	s.centered = false
	s.position = Vector2(ax * TAM, 0)
	s.z_index = -4
	props.add_child(s)
	match n:
		1:
			_plat(ax + 5, 8, 3)
			_plat(ax + 32, 8, 3)
			_mola(ax + 6)
			_mola(ax + 32)
			_prop("cogumelo_v", ax + 3, 13, -2)
			_prop("cogumelo_r", ax + 37, 13, -2)
			_luz_em((ax + 20) * TAM, 6 * TAM, Color(0.7, 0.5, 1.0), 0.6, 3.0)
		2:
			_plat(ax + 4, 8, 3)
			_plat(ax + 33, 8, 3)
			_gelo(ax + 1, LARG_ARENA - 2)
			_prop("cristal", ax + 4, 13, -2)
			_prop("cristal", ax + 36, 13, -2)
			_luz_em((ax + 20) * TAM, 6 * TAM, Color(0.5, 0.85, 1.0), 0.6, 3.0)
		3:
			_plat(ax + 5, 8, 3)
			_plat(ax + 32, 8, 3)
			_prop("obelisco", ax + 4, 13, -2)
			_prop("obelisco", ax + 36, 13, -2)
			_luz_em((ax + 20) * TAM, 7 * TAM, Color(1.0, 0.8, 0.5), 0.6, 3.0)
		4:
			_plat(ax + 4, 8, 3)
			_plat(ax + 33, 8, 3)
			_tocha(ax + 4, 12, 15)
			_tocha(ax + 36, 12, 15)
			_luz_em((ax + 20) * TAM, 6 * TAM, Color(0.6, 0.5, 1.0), 0.6, 3.0)
			_prop("lustre", ax + 12, 6, -1)
			_prop("lustre", ax + 28, 6, -1)
		5:
			_plat(ax + 4, 8, 3)
			_plat(ax + 33, 8, 3)
			_geiser(ax + 13, 13, 0.0, 4.6)
			_geiser(ax + 27, 13, 2.3, 4.6)
			_luz_em((ax + 20) * TAM, 8 * TAM, Color(1.0, 0.5, 0.2), 0.7, 3.0)


func _criar_chefe(n: int, nome_chefe: String) -> void:
	_portao = PORTAO.new()
	_portao.altura = float(LINHA_CHAO * TAM)
	_portao.position = Vector2((_ax + 0.5) * TAM, 0)
	entidades.add_child(_portao)
	var b = CHEFE.instantiate()
	b.tipo = n
	b.nome = nome_chefe
	b.frames_res = load("res://arte/frames/boss_%d.tres" % n)
	b.arena_min = (_ax + 1) * TAM
	b.arena_max = largura * TAM
	b.chao_y = LINHA_CHAO * TAM
	b.position = Vector2((largura - 9) * TAM, LINHA_CHAO * TAM - 20)
	entidades.add_child(b)
	b.intro_iniciada.connect(_ao_intro_chefe)
	b.derrotado.connect(_ao_chefe_derrotado)


func _ao_intro_chefe() -> void:
	_portao.fechar()
	_cam.limit_left = _ax * TAM
	_cam.limit_right = largura * TAM


func _ao_chefe_derrotado() -> void:
	_portao.abrir()
	_cam.limit_left = 0


# ---------------- decoração espalhada ----------------
func _decorar() -> void:
	var lista: Array = DECOR_CHAO.get(_tema, [9])
	for x in range(3, largura - 1):
		var topo := alturas[x] - 1
		if alturas[x] >= ALTURA or topo < 3:
			continue
		if not _livre(x, topo) or decoracao.get_cell_source_id(Vector2i(x, topo)) != -1:
			continue
		if _rng.randf() < 0.2:
			_deco(x, topo, lista[_rng.randi_range(0, lista.size() - 1)])


# ---------------- Fundo com parallax ----------------
func _montar_fundo(tema: int) -> void:
	var camadas := [["ceu", 0.0], ["longe", 0.15], ["perto", 0.4]]
	for c in camadas:
		var camada := ParallaxLayer.new()
		camada.motion_scale = Vector2(c[1], 0.0)
		camada.motion_mirroring = Vector2(480, 0)
		var s := Sprite2D.new()
		s.centered = false
		s.texture = load("res://arte/fundos/%s_%d.png" % [c[0], tema])
		camada.add_child(s)
		fundo.add_child(camada)


# ---------------- atmosfera: partículas ambientes que acompanham a câmera ----------------
func _rampa_pisca(cor: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(cor.r, cor.g, cor.b, 0.0))
	g.set_color(1, Color(cor.r, cor.g, cor.b, 0.0))
	g.add_point(0.5, cor)
	return g


func _atmosfera(tema: int) -> void:
	var p := CPUParticles2D.new()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(260, 150)
	p.position = Vector2(0, -20)
	p.local_coords = false
	p.z_index = 7
	match tema:
		0:   # vaga-lumes
			p.amount = 28
			p.lifetime = 5.0
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 10.0
			p.gravity = Vector2(0, -2)
			p.scale_amount_min = 1.6
			p.scale_amount_max = 2.4
			p.color_ramp = _rampa_pisca(Color(0.85, 1.0, 0.4, 0.95))
		1:   # neve
			p.amount = 90
			p.lifetime = 5.5
			p.direction = Vector2(0.25, 1)
			p.spread = 20.0
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 20.0
			p.gravity = Vector2(-6, 30)
			p.scale_amount_min = 1.2
			p.scale_amount_max = 2.2
			p.color = Color(1, 1, 1, 0.9)
		2:   # vento de areia
			p.amount = 55
			p.lifetime = 2.8
			p.direction = Vector2(1, 0.1)
			p.spread = 10.0
			p.initial_velocity_min = 70.0
			p.initial_velocity_max = 120.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 1.0
			p.scale_amount_max = 1.7
			p.color = Color(0.95, 0.8, 0.5, 0.5)
		3:   # poeira fantasmagórica
			p.amount = 26
			p.lifetime = 6.0
			p.direction = Vector2(1, -0.2)
			p.spread = 180.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 8.0
			p.gravity = Vector2(0, -2)
			p.scale_amount_min = 1.6
			p.scale_amount_max = 2.4
			p.color_ramp = _rampa_pisca(Color(0.72, 0.62, 1.0, 0.6))
		4:   # brasas
			p.amount = 50
			p.lifetime = 3.5
			p.direction = Vector2(0, -1)
			p.spread = 40.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 16.0
			p.gravity = Vector2(0, -26)
			p.scale_amount_min = 1.2
			p.scale_amount_max = 2.2
			var g := Gradient.new()
			g.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
			g.set_color(1, Color(1.0, 0.2, 0.1, 0.0))
			p.color_ramp = g
		_:   # saguão e trono: brilhos dourados
			p.amount = 22
			p.lifetime = 5.0
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 9.0
			p.gravity = Vector2(0, -3)
			p.scale_amount_min = 1.4
			p.scale_amount_max = 2.2
			p.color_ramp = _rampa_pisca(Color(1.0, 0.88, 0.45, 0.9))
	p.emitting = true
	jogador.add_child(p)
