extends Area2D
# Porta: aperte E perto dela para entrar.

@export var destino := "hub"
@export var saida_id := 0
@export var indice_cor := 0
@export var rotulo := ""

var perto := false

@onready var sprite: Sprite2D = $Sprite
@onready var texto: Label = $Rotulo
@onready var dica: Label = $Dica


func _ready() -> void:
	sprite.frame = indice_cor
	texto.text = rotulo
	Util.texto(texto, 7)
	Util.texto(dica, 8, Color("#ffe060"))
	texto.visible = false
	dica.visible = false
	body_entered.connect(func(c): _mudar(c, true))
	body_exited.connect(func(c): _mudar(c, false))


func _mudar(corpo: Node, entrou: bool) -> void:
	if corpo.is_in_group("jogador"):
		perto = entrou
		dica.visible = entrou
		texto.visible = entrou


func _process(_delta: float) -> void:
	if perto and Input.is_action_just_pressed("interagir"):
		perto = false
		Sons.tocar("porta")
		Jogo.ir_para(destino, saida_id)
