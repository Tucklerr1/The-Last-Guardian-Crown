extends Control
# Menu inicial: Jogar, Créditos e Sair — com logotipo, brilhos e botões que entram animados.

@onready var jogar: Button = $Conteudo/Caixa/Botoes/Jogar
@onready var creditos: Button = $Conteudo/Caixa/Botoes/Creditos
@onready var sair: Button = $Conteudo/Caixa/Botoes/Sair
@onready var titulo: Label = $Conteudo/Caixa/Titulo
@onready var conteudo: CenterContainer = $Conteudo
@onready var botoes: VBoxContainer = $Conteudo/Caixa/Botoes

var _logo: TextureRect
var _controles: Button
var _painel_ctrl: Control


func _ready() -> void:
	Jogo.restaurar_tempo()
	get_tree().paused = false
	Sons.musica("menu")
	Sons.ambiente("")
	titulo.visible = false
	conteudo.offset_top = 80
	_controles = Button.new()
	_controles.text = "Controles"
	botoes.add_child(_controles)
	botoes.move_child(_controles, 2)
	for b in [jogar, creditos, _controles, sair]:
		Util.estilo_botao(b, Color("#3a2a6a"), 14)
		b.custom_minimum_size = Vector2(170, 24)
	jogar.pressed.connect(_ao_jogar)
	creditos.pressed.connect(_ao_creditos)
	_controles.pressed.connect(_ao_controles)
	sair.pressed.connect(_ao_sair)
	_montar_logo()
	_montar_brilhos()
	_entrada_botoes()
	jogar.grab_focus()


func _montar_logo() -> void:
	_logo = TextureRect.new()
	_logo.texture = load("res://arte/ui/logo.png")
	_logo.position = Vector2(40, 8)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_logo.modulate.a = 0.0
	var entrada := create_tween().set_parallel(true)
	_logo.position.y = -20.0
	entrada.tween_property(_logo, "position:y", 8.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrada.tween_property(_logo, "modulate:a", 1.0, 0.5)
	var flutua := create_tween().set_loops()
	flutua.tween_interval(0.8)
	flutua.tween_property(_logo, "position:y", 5.0, 1.4).set_trans(Tween.TRANS_SINE)
	flutua.tween_property(_logo, "position:y", 9.0, 1.4).set_trans(Tween.TRANS_SINE)


func _montar_brilhos() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(240, 150)
	p.amount = 55
	p.lifetime = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(240, 110)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector2(0, -4)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.4
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 0.0))
	g.set_color(1, Color(1.0, 0.85, 0.4, 0.0))
	g.add_point(0.5, Color(1.0, 0.9, 0.5, 0.9))
	p.color_ramp = g
	p.emitting = true
	add_child(p)
	move_child(p, 1)


func _entrada_botoes() -> void:
	var i := 0
	for b in [jogar, creditos, _controles, sair]:
		b.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.5 + 0.12 * float(i))
		tw.tween_property(b, "modulate:a", 1.0, 0.3)
		i += 1


func _ao_jogar() -> void:
	Jogo.novo_jogo()


func _ao_creditos() -> void:
	get_tree().change_scene_to_file("res://cenas/creditos.tscn")


func _ao_controles() -> void:
	if _painel_ctrl and is_instance_valid(_painel_ctrl):
		_painel_ctrl.queue_free()
		_painel_ctrl = null
		return
	_painel_ctrl = Control.new()
	_painel_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sombra := ColorRect.new()
	sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
	sombra.color = Color(0, 0, 0, 0.7)
	_painel_ctrl.add_child(sombra)
	var caixa := Panel.new()
	caixa.position = Vector2(100, 40)
	caixa.size = Vector2(280, 190)
	caixa.add_theme_stylebox_override("panel", Util.caixa(Color(0.12, 0.08, 0.2, 0.95), Color("#8a70d0"), 2, 10))
	_painel_ctrl.add_child(caixa)
	var txt := Label.new()
	txt.text = "CONTROLES\n\nWASD ou setas  -  mover\nESPAÇO  -  pular\nCLIQUE ESQ  -  golpe\nTAB  -  ataque especial\nE  -  interagir / portas\nESC  -  pausar\nR  -  reviver (quando morrer)"
	txt.position = Vector2(16, 12)
	txt.size = Vector2(250, 160)
	Util.texto(txt, 10, Color("#fff4d0"))
	caixa.add_child(txt)
	var fechar := Button.new()
	fechar.text = "Fechar"
	fechar.position = Vector2(90, 155)
	fechar.custom_minimum_size = Vector2(100, 22)
	Util.estilo_botao(fechar, Color("#3a2a6a"), 12)
	fechar.pressed.connect(_ao_controles)
	caixa.add_child(fechar)
	add_child(_painel_ctrl)
	fechar.grab_focus()


func _ao_sair() -> void:
	get_tree().quit()
