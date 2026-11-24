extends Node
# AUTOLOAD "Jogo": guarda o estado do jogo (moedas, corações, chefes) entre as cenas.

signal moedas_mudaram
signal coracoes_mudaram
signal especial_mudou
signal jogador_morreu
signal chefe_mudou
signal mensagem(texto: String)
signal vitoria
signal tremor(forca: float, tempo: float)          # tremor de câmera
signal chefe_intro(nome: String, titulo: String)   # faixa dramática de entrada do chefe
signal chefe_fase_mudou

const MOEDAS_PARA_COROA := 1000
const CORACOES_INICIAIS := 5
const CORACOES_MAXIMOS := 10

var moedas := 0
var coracoes := CORACOES_INICIAIS
var especial := 0.0
var chefes_derrotados: Array[bool] = [false, false, false, false, false]
var mundo_atual := "hub"
var porta_de_saida := 0
var fim_de_jogo := false
var dano_extra := 0
var max_coracoes := CORACOES_INICIAIS
var upgrade_dano_comprado := false
var upgrade_vida_comprado := false
var upgrade_especial_comprado := false

# dados do chefe que está lutando (usados pela barra de vida do HUD)
var chefe_ativo := false
var chefe_nome := ""
var chefe_vida := 0
var chefe_vida_max := 1
var chefe_fase := 1

var _congelado := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_registrar_entradas()


func _registrar_entradas() -> void:
	var teclas := {
		"esquerda": KEY_A, "direita": KEY_D, "cima": KEY_W, "baixo": KEY_S,
		"pular": KEY_SPACE, "interagir": KEY_E, "especial": KEY_TAB,
		"reviver": KEY_R, "pausar": KEY_ESCAPE,
	}
	for nome in teclas:
		if not InputMap.has_action(nome):
			InputMap.add_action(nome)
		var ev := InputEventKey.new()
		ev.physical_keycode = teclas[nome]
		InputMap.action_add_event(nome, ev)
	if not InputMap.has_action("atacar"):
		InputMap.add_action("atacar")
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("atacar", clique)


func novo_jogo() -> void:
	moedas = 0
	coracoes = CORACOES_INICIAIS
	especial = 0.0
	chefes_derrotados = [false, false, false, false, false]
	dano_extra = 0
	max_coracoes = CORACOES_INICIAIS
	upgrade_dano_comprado = false
	upgrade_vida_comprado = false
	upgrade_especial_comprado = false
	ir_para("hub", 0)


func reviver() -> void:
	coracoes = max_coracoes
	especial = 0.0
	ir_para("hub", 0)


func ir_para(mundo: String, porta := 0) -> void:
	mundo_atual = mundo
	porta_de_saida = porta
	fim_de_jogo = false
	chefe_ativo = false
	restaurar_tempo()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://cenas/mundo.tscn")


func restaurar_tempo() -> void:
	Engine.time_scale = 1.0
	_congelado = false


# Pausa rápida de impacto ("hit stop"): dá peso aos golpes.
func congelar(seg: float) -> void:
	if _congelado or seg <= 0.0:
		return
	_congelado = true
	Engine.time_scale = 0.05
	var t := get_tree().create_timer(seg, true, false, true)
	t.timeout.connect(restaurar_tempo)


func tremer(forca: float, tempo: float) -> void:
	tremor.emit(forca, tempo)


func ganhar_moedas(n: int) -> void:
	moedas += n
	moedas_mudaram.emit()


func ganhar_coracao(n := 1) -> void:
	coracoes = mini(coracoes + n, max_coracoes)
	coracoes_mudaram.emit()


func perder_coracao(n := 1) -> void:
	coracoes = maxi(coracoes - n, 0)
	coracoes_mudaram.emit()


func ganhar_especial(n: float) -> void:
	var antes := especial
	especial = minf(especial + n, 100.0)
	if antes < 100.0 and especial >= 100.0:
		Sons.tocar("pronto")
	especial_mudou.emit()


func gastar_especial() -> void:
	especial = 0.0
	especial_mudou.emit()


func total_chefes() -> int:
	return chefes_derrotados.count(true)


func coroa_liberada() -> bool:
	return total_chefes() == 5 and moedas >= MOEDAS_PARA_COROA
