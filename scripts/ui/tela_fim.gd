extends CanvasLayer
# Tela final: derrota (R reviver) ou vitória (com confete). Permite reiniciar ou voltar ao menu.

var venceu := false

@onready var raiz: Control = $Raiz
@onready var sombra: ColorRect = $Raiz/Sombra
@onready var painel: PanelContainer = $Raiz/Centro/Painel
@onready var titulo: Label = $Raiz/Centro/Painel/Caixa/Titulo
@onready var detalhe: Label = $Raiz/Centro/Painel/Caixa/Detalhe
@onready var principal: Button = $Raiz/Centro/Painel/Caixa/Principal
@onready var menu: Button = $Raiz/Centro/Painel/Caixa/Menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	Util.texto(titulo, 18, Color("#f4c430"))
	Util.texto(detalhe, 10)
	Util.estilo_botao(principal)
	Util.estilo_botao(menu)
	principal.process_mode = Node.PROCESS_MODE_ALWAYS
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	principal.pressed.connect(_ao_principal)
	menu.pressed.connect(_ao_menu)
	Jogo.jogador_morreu.connect(_ao_morrer)
	Jogo.vitoria.connect(_mostrar.bind(true))


func _ao_morrer() -> void:
	get_tree().create_timer(1.4).timeout.connect(_mostrar.bind(false))


func _mostrar(ganhou: bool) -> void:
	if visible:
		return
	venceu = ganhou
	Jogo.fim_de_jogo = true
	Jogo.restaurar_tempo()
	if ganhou:
		titulo.text = "VOCÊ É O REI DO MUNDO!"
		detalhe.text = "A coroa é sua.\nMoedas: %d    Chefes: 5/5" % Jogo.moedas
		principal.text = "Jogar de novo"
		painel.add_theme_stylebox_override("panel", Util.caixa(Color(0.10, 0.07, 0.02, 0.96), Color("#ffe27a"), 2, 14))
		sombra.color = Color(0.1, 0.06, 0.0, 0.7)
		_confete()
		Sons.musica("")
	else:
		titulo.text = "VOCÊ CAIU..."
		titulo.add_theme_color_override("font_color", Color("#ff6a6a"))
		detalhe.text = "Chefes derrotados: %d/5   Moedas: %d" % [Jogo.total_chefes(), Jogo.moedas]
		principal.text = "Reviver (R)"
		painel.add_theme_stylebox_override("panel", Util.caixa(Color(0.12, 0.03, 0.05, 0.96), Color("#e8344a"), 2, 14))
		sombra.color = Color(0.15, 0.0, 0.02, 0.7)
		Sons.abafar(true)
	visible = true
	get_tree().paused = true
	painel.pivot_offset = painel.size * 0.5
	painel.scale = Vector2(0.6, 0.6)
	raiz.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(painel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(raiz, "modulate:a", 1.0, 0.3)
	principal.grab_focus()


func _confete() -> void:
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.position = Vector2(240, -10)
	p.amount = 90
	p.lifetime = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(240, 4)
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 40)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	var g := Gradient.new()
	g.set_color(0, Color("#ff5a7a"))
	g.set_color(1, Color("#ffe27a"))
	g.add_point(0.5, Color("#7ad8ff"))
	p.color_initial_ramp = g
	p.emitting = true
	add_child(p)


func _input(evento: InputEvent) -> void:
	if visible and not venceu and evento.is_action_pressed("reviver"):
		_ao_principal()


func _ao_principal() -> void:
	Sons.abafar(false)
	if venceu:
		Jogo.novo_jogo()
	else:
		Jogo.reviver()


func _ao_menu() -> void:
	get_tree().paused = false
	Sons.abafar(false)
	Jogo.restaurar_tempo()
	get_tree().change_scene_to_file("res://cenas/menu.tscn")
