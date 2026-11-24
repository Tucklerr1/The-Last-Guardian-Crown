class_name Util
extends RefCounted
# Funções de ajuda usadas em vários scripts: criação de itens, partículas, efeitos, luzes e estilos de interface.

static var _fontes := {}
static var _tex_luz: GradientTexture2D


# Adiciona um nó depois da física terminar (evita erros ao criar coisas dentro de colisões).
static func adicionar(pai: Node, filho: Node) -> void:
	pai.add_child.call_deferred(filho)


static func soltar_item(pai: Node, pos: Vector2, tipo: String, valor: int) -> void:
	var item = load("res://cenas/item.tscn").instantiate()
	item.iniciar(tipo, valor)
	item.position = pos
	adicionar(pai, item)


# ---------------------------------------------------------------- partículas e efeitos
static func particulas(pai: Node, pos: Vector2, cor: Color, qtd: int = 14, vel_min := 40.0, vel_max := 110.0, vida := 0.55, grav := 260.0, tam := 2.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = qtd
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.gravity = Vector2(0, grav)
	p.scale_amount_min = tam
	p.scale_amount_max = tam * 1.6
	var g := Gradient.new()
	g.set_color(0, cor)
	g.set_color(1, Color(cor.r, cor.g, cor.b, 0.0))
	p.color_ramp = g
	p.z_index = 6
	p.emitting = true
	p.finished.connect(p.queue_free)
	adicionar(pai, p)


static func fx(pai: Node, pos: Vector2, nome: String, frames: int, fps := 14.0, esc := 1.0, flip := false, cor := Color.WHITE, base := false) -> void:
	var s := FxAnim.new()
	s.configurar(nome, frames, fps, esc, flip, cor, base)
	s.position = pos
	adicionar(pai, s)


static func faiscas(pai: Node, pos: Vector2, cor := Color("#ffe27a")) -> void:
	fx(pai, pos, "faisca", 4, 22.0, 1.0)
	particulas(pai, pos, cor, 7, 50.0, 130.0, 0.3, 200.0, 1.5)


static func poeira(pai: Node, pos: Vector2, dir_x: float, cor := Color(0.82, 0.74, 0.62, 0.8), qtd := 5) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = qtd
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(-dir_x, -0.35)
	p.spread = 35.0
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 48.0
	p.gravity = Vector2(0, -20)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.2
	var g := Gradient.new()
	g.set_color(0, cor)
	g.set_color(1, Color(cor.r, cor.g, cor.b, 0.0))
	p.color_ramp = g
	p.emitting = true
	p.finished.connect(p.queue_free)
	adicionar(pai, p)


static func anel(pai: Node, pos: Vector2, cor: Color, esc := 1.0) -> void:
	fx(pai, pos, "anel", 4, 16.0, esc, false, cor)


static func explosao(pai: Node, pos: Vector2, cor: Color, esc := 1.0) -> void:
	particulas(pai, pos, cor, int(22 * esc), 50.0, 150.0 * esc, 0.6, 220.0, 2.4)
	particulas(pai, pos, Color(1, 1, 0.85), int(8 * esc), 20.0, 80.0, 0.35, 120.0, 2.0)
	anel(pai, pos + Vector2(0, 4), cor, esc)


static func luz(pai: Node, pos: Vector2, cor: Color, energia := 0.8, esc := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _textura_luz()
	l.color = cor
	l.energy = energia
	l.texture_scale = esc
	l.position = pos
	pai.add_child(l)
	return l


static func _textura_luz() -> GradientTexture2D:
	if _tex_luz == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_tex_luz = t
	return _tex_luz


static func aviso(pai: Node, pos: Vector2, forma: String, tam: Vector2, cor: Color, dur: float) -> void:
	var a := Aviso.new()
	a.configurar(forma, tam, cor, dur)
	a.position = pos
	adicionar(pai, a)


# ---------------------------------------------------------------- interface
static func escala_fonte(tam: int) -> int:
	if tam <= 10:
		return 1
	if tam <= 18:
		return 2
	return 3


static func fonte(tam: int) -> Font:
	var esc := escala_fonte(tam)
	if not _fontes.has(esc):
		_fontes[esc] = load("res://arte/fontes/pixel_%d.fnt" % esc)
	return _fontes[esc]


static func texto(rotulo: Label, tamanho: int = 12, cor: Color = Color.WHITE) -> void:
	var esc := escala_fonte(tamanho)
	rotulo.add_theme_font_override("font", fonte(tamanho))
	rotulo.add_theme_font_size_override("font_size", 10 * esc)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_shadow_color", Color("#140c1c"))
	rotulo.add_theme_constant_override("shadow_offset_x", esc)
	rotulo.add_theme_constant_override("shadow_offset_y", esc)
	rotulo.add_theme_constant_override("line_spacing", 0)


static func caixa(fundo: Color, borda: Color, largura_borda := 2, margem := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.set_border_width_all(largura_borda)
	s.border_color = borda
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margem)
	return s


static func estilo_botao(b: Button, cor: Color = Color("#3a2a6a"), tam := 14) -> void:
	var esc := escala_fonte(tam)
	var normal := caixa(cor, Color("#f4c430"), 2, 5)
	var hover := caixa(cor.lightened(0.28), Color("#fff2a0"), 2, 5)
	var apertado := caixa(cor.darkened(0.25), Color("#c8902a"), 2, 5)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", apertado)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_font_override("font", fonte(tam))
	b.add_theme_font_size_override("font_size", 10 * esc)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color("#fff2a0"))
	b.add_theme_color_override("font_focus_color", Color("#fff2a0"))
	b.add_theme_color_override("font_pressed_color", Color("#ffd24a"))
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(_botao_destacar.bind(b))
	b.focus_entered.connect(_botao_destacar.bind(b))
	b.pressed.connect(func(): Sons.tocar("menu_ok"))


static func _botao_destacar(b: Button) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	Sons.tocar("menu_mover")
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	b.scale = Vector2(1.0, 1.0)
	tw.tween_property(b, "scale", Vector2(1.06, 1.06), 0.08)
	tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.10)


static func estilo_barra(barra: ProgressBar, cor: Color) -> void:
	var fundo := caixa(Color("#140c1c"), Color("#f4f4ff"), 1, 0)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = cor
	barra.add_theme_stylebox_override("background", fundo)
	barra.add_theme_stylebox_override("fill", cheio)
	barra.show_percentage = false
