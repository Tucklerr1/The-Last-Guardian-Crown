extends CanvasLayer
# HUD: corações, moedas, chefes derrotados, barra do especial, barra de vida do chefe, mensagens e a faixa
# dramática de entrada dos chefes. Tudo é montado por código com a fonte pixel art.

const TEX_CHEIO := preload("res://arte/ui/coracao_cheio.png")
const TEX_VAZIO := preload("res://arte/ui/coracao_vazio.png")
const TEX_MOEDA := preload("res://arte/ui/moeda_icone.png")
const TEX_CHEFES := preload("res://arte/ui/chefes.png")
const COR_BORDA := Color("#f4c430")

var _raiz: Control
var _coracoes: Array[TextureRect] = []
var _moeda_icone: TextureRect
var _moeda_atlas: AtlasTexture
var _moeda_rotulo: Label
var _moeda_barra: ProgressBar
var _icones_chefes: Array[TextureRect] = []
var _especial_rotulo: Label
var _especial_barra: ProgressBar
var _especial_painel: PanelContainer
var _chefe_caixa: PanelContainer
var _chefe_nome: Label
var _chefe_barra: ProgressBar
var _chefe_rastro: ProgressBar
var _chefe_pips: Array[ColorRect] = []
var _mensagem: Label
var _msg_painel: PanelContainer
var _faixa_cima: ColorRect
var _faixa_baixo: ColorRect
var _banner_nome: Label
var _banner_titulo: Label
var _tween_msg: Tween
var _tween_banner: Tween
var _t := 0.0
var _coracoes_antes := -1
var _moedas_antes := -1


func _ready() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_montar_esquerda()
	_montar_direita()
	_montar_chefe()
	_montar_mensagem()
	_montar_banner()
	Jogo.moedas_mudaram.connect(_atualizar)
	Jogo.coracoes_mudaram.connect(_atualizar)
	Jogo.especial_mudou.connect(_atualizar)
	Jogo.chefe_mudou.connect(_atualizar_chefe)
	Jogo.chefe_fase_mudou.connect(_atualizar_fase)
	Jogo.mensagem.connect(_mostrar_mensagem)
	Jogo.chefe_intro.connect(_mostrar_banner)
	_atualizar()
	_atualizar_chefe()


func _painel(cor_fundo := Color(0.06, 0.04, 0.12, 0.78)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Util.caixa(cor_fundo, COR_BORDA, 1, 4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _montar_esquerda() -> void:
	var p := _painel()
	p.position = Vector2(4, 4)
	_raiz.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 1)
	v.add_child(linha)
	for i in Jogo.CORACOES_MAXIMOS:
		var t := TextureRect.new()
		t.texture = TEX_CHEIO
		t.custom_minimum_size = Vector2(16, 16)
		t.pivot_offset = Vector2(8, 8)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(t)
		_coracoes.append(t)
	var esp := HBoxContainer.new()
	esp.add_theme_constant_override("separation", 4)
	v.add_child(esp)
	_especial_rotulo = Label.new()
	Util.texto(_especial_rotulo, 8, Color("#9ae8ff"))
	esp.add_child(_especial_rotulo)
	_especial_barra = ProgressBar.new()
	_especial_barra.custom_minimum_size = Vector2(70, 7)
	_especial_barra.max_value = 100.0
	Util.estilo_barra(_especial_barra, Color("#7ad8ff"))
	_especial_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	esp.add_child(_especial_barra)
	_especial_painel = p


func _montar_direita() -> void:
	var p := _painel()
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -118
	p.offset_right = -4
	p.offset_top = 4
	_raiz.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)
	v.add_child(linha)
	_moeda_atlas = AtlasTexture.new()
	_moeda_atlas.atlas = TEX_MOEDA
	_moeda_atlas.region = Rect2(0, 0, 14, 14)
	_moeda_icone = TextureRect.new()
	_moeda_icone.texture = _moeda_atlas
	_moeda_icone.custom_minimum_size = Vector2(14, 14)
	_moeda_icone.pivot_offset = Vector2(7, 7)
	linha.add_child(_moeda_icone)
	_moeda_rotulo = Label.new()
	Util.texto(_moeda_rotulo, 10, Color("#ffe060"))
	_moeda_rotulo.pivot_offset = Vector2(20, 5)
	linha.add_child(_moeda_rotulo)
	_moeda_barra = ProgressBar.new()
	_moeda_barra.custom_minimum_size = Vector2(100, 4)
	_moeda_barra.max_value = Jogo.MOEDAS_PARA_COROA
	Util.estilo_barra(_moeda_barra, Color("#f6c83a"))
	v.add_child(_moeda_barra)
	var icones := HBoxContainer.new()
	icones.add_theme_constant_override("separation", 4)
	icones.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(icones)
	for i in 5:
		var at := AtlasTexture.new()
		at.atlas = TEX_CHEFES
		at.region = Rect2(i * 16, 0, 16, 16)
		var t := TextureRect.new()
		t.texture = at
		t.custom_minimum_size = Vector2(16, 16)
		t.pivot_offset = Vector2(8, 8)
		icones.add_child(t)
		_icones_chefes.append(t)


func _montar_chefe() -> void:
	_chefe_caixa = _painel(Color(0.08, 0.03, 0.08, 0.85))
	_chefe_caixa.anchor_left = 0.5
	_chefe_caixa.anchor_right = 0.5
	_chefe_caixa.anchor_top = 1.0
	_chefe_caixa.anchor_bottom = 1.0
	_chefe_caixa.offset_left = -140
	_chefe_caixa.offset_right = 140
	_chefe_caixa.offset_top = -42
	_chefe_caixa.offset_bottom = -6
	_chefe_caixa.visible = false
	_raiz.add_child(_chefe_caixa)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_chefe_caixa.add_child(v)
	var topo := HBoxContainer.new()
	v.add_child(topo)
	_chefe_nome = Label.new()
	Util.texto(_chefe_nome, 8, Color("#ffd0d0"))
	_chefe_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_chefe_nome)
	for i in 3:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(8, 6)
		pip.color = Color("#e83a4a")
		topo.add_child(pip)
		_chefe_pips.append(pip)
	var area := Control.new()
	area.custom_minimum_size = Vector2(262, 12)
	v.add_child(area)
	_chefe_rastro = ProgressBar.new()
	_chefe_rastro.set_anchors_preset(Control.PRESET_FULL_RECT)
	Util.estilo_barra(_chefe_rastro, Color("#ffffff"))
	area.add_child(_chefe_rastro)
	_chefe_barra = ProgressBar.new()
	_chefe_barra.set_anchors_preset(Control.PRESET_FULL_RECT)
	Util.estilo_barra(_chefe_barra, Color("#e83a4a"))
	var vazio := StyleBoxEmpty.new()
	_chefe_barra.add_theme_stylebox_override("background", vazio)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = Color("#e83a4a")
	cheio.border_width_bottom = 3
	cheio.border_color = Color("#a82030")
	_chefe_barra.add_theme_stylebox_override("fill", cheio)
	area.add_child(_chefe_barra)


func _montar_mensagem() -> void:
	_msg_painel = _painel(Color(0.06, 0.04, 0.12, 0.85))
	_msg_painel.anchor_left = 0.5
	_msg_painel.anchor_right = 0.5
	_msg_painel.offset_left = -170
	_msg_painel.offset_right = 170
	_msg_painel.offset_top = 40
	_msg_painel.modulate.a = 0.0
	_raiz.add_child(_msg_painel)
	_mensagem = Label.new()
	_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Util.texto(_mensagem, 8)
	_msg_painel.add_child(_mensagem)


func _montar_banner() -> void:
	_faixa_cima = ColorRect.new()
	_faixa_cima.color = Color(0, 0, 0, 0.92)
	_faixa_cima.anchor_right = 1.0
	_faixa_cima.offset_bottom = 0
	_faixa_cima.offset_top = -26
	_faixa_cima.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_faixa_cima)
	_faixa_baixo = ColorRect.new()
	_faixa_baixo.color = Color(0, 0, 0, 0.92)
	_faixa_baixo.anchor_right = 1.0
	_faixa_baixo.anchor_top = 1.0
	_faixa_baixo.anchor_bottom = 1.0
	_faixa_baixo.offset_top = 0
	_faixa_baixo.offset_bottom = 26
	_faixa_baixo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_faixa_baixo)
	_banner_nome = Label.new()
	_banner_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_nome.anchor_right = 1.0
	_banner_nome.offset_top = 100
	_banner_nome.offset_bottom = 134
	Util.texto(_banner_nome, 26, Color("#ffd24a"))
	_banner_nome.modulate.a = 0.0
	_raiz.add_child(_banner_nome)
	_banner_titulo = Label.new()
	_banner_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_titulo.anchor_right = 1.0
	_banner_titulo.offset_top = 138
	_banner_titulo.offset_bottom = 160
	Util.texto(_banner_titulo, 14, Color("#ffffff"))
	_banner_titulo.modulate.a = 0.0
	_raiz.add_child(_banner_titulo)


func _process(delta: float) -> void:
	_t += delta
	var f := int(_t * 8.0) % 6
	_moeda_atlas.region = Rect2(f * 14, 0, 14, 14)
	# barra do especial pulsa quando está pronta
	if Jogo.especial >= 100.0:
		var k := 0.75 + 0.25 * sin(_t * 8.0)
		_especial_barra.modulate = Color(k + 0.3, k + 0.3, 1.4)
	else:
		_especial_barra.modulate = Color.WHITE
	# rastro da barra do chefe (mostra quanto de vida foi perdido)
	if _chefe_caixa.visible:
		_chefe_rastro.value = move_toward(_chefe_rastro.value, _chefe_barra.value, _chefe_barra.max_value * 0.35 * delta)


func _atualizar() -> void:
	var slots := maxi(Jogo.CORACOES_INICIAIS, Jogo.coracoes)
	for i in _coracoes.size():
		var h := _coracoes[i]
		h.visible = i < slots
		h.texture = TEX_CHEIO if i < Jogo.coracoes else TEX_VAZIO
		if _coracoes_antes >= 0 and i == Jogo.coracoes and Jogo.coracoes < _coracoes_antes:
			_pulso(h, 1.6)
		elif _coracoes_antes >= 0 and i == Jogo.coracoes - 1 and Jogo.coracoes > _coracoes_antes:
			_pulso(h, 1.6)
	_coracoes_antes = Jogo.coracoes
	_moeda_rotulo.text = "%d/%d" % [Jogo.moedas, Jogo.MOEDAS_PARA_COROA]
	_moeda_barra.value = Jogo.moedas
	if _moedas_antes >= 0 and Jogo.moedas > _moedas_antes:
		_pulso(_moeda_rotulo, 1.25)
		_pulso(_moeda_icone, 1.3)
	_moedas_antes = Jogo.moedas
	for i in 5:
		var at: AtlasTexture = _icones_chefes[i].texture
		at.region = Rect2((i + (5 if Jogo.chefes_derrotados[i] else 0)) * 16, 0, 16, 16)
	_especial_barra.value = Jogo.especial
	_especial_rotulo.text = "PRONTO [TAB]" if Jogo.especial >= 100.0 else "ESPECIAL"


func _pulso(c: Control, forca: float) -> void:
	var tw := create_tween()
	c.scale = Vector2(forca, forca)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _atualizar_chefe() -> void:
	var antes := _chefe_caixa.visible
	_chefe_caixa.visible = Jogo.chefe_ativo
	_chefe_nome.text = Jogo.chefe_nome.to_upper()
	_chefe_barra.max_value = Jogo.chefe_vida_max
	_chefe_rastro.max_value = Jogo.chefe_vida_max
	_chefe_barra.value = Jogo.chefe_vida
	if Jogo.chefe_ativo and not antes:
		_chefe_rastro.value = Jogo.chefe_vida
		_chefe_caixa.modulate.a = 0.0
		create_tween().tween_property(_chefe_caixa, "modulate:a", 1.0, 0.5)
		_atualizar_fase()


func _atualizar_fase() -> void:
	for i in 3:
		_chefe_pips[i].color = Color("#e83a4a") if i < Jogo.chefe_fase else Color("#3a2a3a")
	if Jogo.chefe_ativo:
		var tw := create_tween()
		_chefe_barra.modulate = Color(2.5, 2.5, 2.5)
		tw.tween_property(_chefe_barra, "modulate", Color.WHITE, 0.4)


func _mostrar_mensagem(texto: String) -> void:
	_mensagem.text = texto
	_msg_painel.modulate.a = 1.0
	_msg_painel.offset_top = 34
	if _tween_msg:
		_tween_msg.kill()
	_tween_msg = create_tween()
	_tween_msg.tween_property(_msg_painel, "offset_top", 40.0, 0.2)
	_tween_msg.tween_interval(3.0)
	_tween_msg.tween_property(_msg_painel, "modulate:a", 0.0, 0.6)


func _mostrar_banner(nome: String, titulo: String) -> void:
	_banner_nome.text = nome
	_banner_titulo.text = titulo
	_banner_nome.modulate.a = 0.0
	_banner_titulo.modulate.a = 0.0
	_banner_nome.scale = Vector2(1.5, 1.5)
	_banner_nome.pivot_offset = Vector2(240, 17)
	_faixa_cima.offset_top = -26
	_faixa_cima.offset_bottom = 0
	_faixa_baixo.offset_top = 0
	_faixa_baixo.offset_bottom = 26
	if _tween_banner:
		_tween_banner.kill()
	_tween_banner = create_tween()
	_tween_banner.set_parallel(true)
	_tween_banner.tween_property(_faixa_cima, "offset_top", 0.0, 0.3)
	_tween_banner.tween_property(_faixa_cima, "offset_bottom", 26.0, 0.3)
	_tween_banner.tween_property(_faixa_baixo, "offset_top", -26.0, 0.3)
	_tween_banner.tween_property(_faixa_baixo, "offset_bottom", 0.0, 0.3)
	_tween_banner.tween_property(_banner_nome, "modulate:a", 1.0, 0.3).set_delay(0.2)
	_tween_banner.tween_property(_banner_nome, "scale", Vector2.ONE, 0.45).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_banner.tween_property(_banner_titulo, "modulate:a", 1.0, 0.4).set_delay(0.6)
	_tween_banner.chain().tween_interval(1.2)
	_tween_banner.chain().set_parallel(true)
	_tween_banner.tween_property(_banner_nome, "modulate:a", 0.0, 0.4)
	_tween_banner.tween_property(_banner_titulo, "modulate:a", 0.0, 0.4)
	_tween_banner.tween_property(_faixa_cima, "offset_top", -26.0, 0.4)
	_tween_banner.tween_property(_faixa_cima, "offset_bottom", 0.0, 0.4)
	_tween_banner.tween_property(_faixa_baixo, "offset_top", 0.0, 0.4)
	_tween_banner.tween_property(_faixa_baixo, "offset_bottom", 26.0, 0.4)
