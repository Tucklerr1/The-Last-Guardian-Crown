extends CanvasLayer
# Menu de pause (CanvasLayer). ESC abre e fecha.

@onready var raiz: Control = $Raiz
@onready var painel: PanelContainer = $Raiz/Centro/Painel
@onready var continuar: Button = $Raiz/Centro/Painel/Caixa/Continuar
@onready var menu: Button = $Raiz/Centro/Painel/Caixa/Menu
@onready var sair: Button = $Raiz/Centro/Painel/Caixa/Sair
@onready var titulo: Label = $Raiz/Centro/Painel/Caixa/Titulo
@onready var caixa: VBoxContainer = $Raiz/Centro/Painel/Caixa


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	painel.add_theme_stylebox_override("panel", Util.caixa(Color(0.07, 0.04, 0.13, 0.96), Color("#f4c430"), 2, 12))
	Util.texto(titulo, 18, Color("#f4c430"))
	for b in [continuar, menu, sair]:
		Util.estilo_botao(b)
		b.process_mode = Node.PROCESS_MODE_ALWAYS
	var dica := Label.new()
	dica.text = "WASD mover   ESPAÇO pular\nCLIQUE golpe   TAB especial\nE interagir   ESC pausar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Util.texto(dica, 8, Color("#a8a0c8"))
	caixa.add_child(dica)
	continuar.pressed.connect(_alternar)
	menu.pressed.connect(_ir_menu)
	sair.pressed.connect(func(): get_tree().quit())


func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausar") and not Jogo.fim_de_jogo:
		_alternar()
		get_viewport().set_input_as_handled()


func _alternar() -> void:
	visible = not visible
	get_tree().paused = visible
	Sons.abafar(visible)
	Sons.tocar("menu_ok" if visible else "menu_voltar")
	if visible:
		painel.pivot_offset = painel.size * 0.5
		painel.scale = Vector2(0.85, 0.85)
		raiz.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(painel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(raiz, "modulate:a", 1.0, 0.15)
		continuar.grab_focus()


func _ir_menu() -> void:
	get_tree().paused = false
	Sons.abafar(false)
	Jogo.restaurar_tempo()
	get_tree().change_scene_to_file("res://cenas/menu.tscn")
