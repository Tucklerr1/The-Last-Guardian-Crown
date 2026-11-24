extends Area2D
# Trono com a coroa acorrentada. Só abre com os 5 chefes derrotados e 1.000 moedas.

var perto := false

@onready var coroa: Sprite2D = $Coroa
@onready var dica: Label = $Dica


func _ready() -> void:
	Util.texto(dica, 8, Color("#ffe060"))
	dica.visible = false
	body_entered.connect(func(c): _mudar(c, true))
	body_exited.connect(func(c): _mudar(c, false))
	var t := create_tween().set_loops()
	t.tween_property(coroa, "position:y", coroa.position.y - 3.0, 0.8)
	t.tween_property(coroa, "position:y", coroa.position.y, 0.8)


func _mudar(corpo: Node, entrou: bool) -> void:
	if corpo.is_in_group("jogador"):
		perto = entrou
		dica.visible = entrou


func _process(_delta: float) -> void:
	if not perto or not Input.is_action_just_pressed("interagir"):
		return
	if Jogo.coroa_liberada():
		perto = false
		Sons.tocar("vitoria")
		Jogo.fim_de_jogo = true
		var jog = get_tree().get_first_node_in_group("jogador")
		if jog:
			jog.pose_vitoria = true
			jog.congelado = true
		var tw = create_tween()
		tw.tween_property(coroa, "position:y", coroa.position.y - 40.0, 1.2).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(coroa, "modulate", Color(2, 2, 1.2, 1), 1.0)
		tw.tween_callback(func():
			Util.particulas(get_parent(), coroa.global_position, Color("#ffe27a"), 40, 40.0, 120.0, 1.2, 80.0, 3.0)
			Jogo.vitoria.emit()
		)
	else:
		Jogo.mensagem.emit("As correntes resistem... Chefes: %d/5  Moedas: %d/%d" % [Jogo.total_chefes(), Jogo.moedas, Jogo.MOEDAS_PARA_COROA])
