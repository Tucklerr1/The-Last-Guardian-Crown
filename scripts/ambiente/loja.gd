extends Area2D

var nome := ""
var preco := 100
var tipo := "vida"
var perto := false

@onready var dica: Label = $Dica
@onready var texto: Label = $Texto


func _ready() -> void:
	texto.text = nome + "\n" + str(preco) + " moedas"
	Util.texto(texto, 7, Color("#ffe27a"))
	Util.texto(dica, 8, Color("#ffe060"))
	dica.visible = false
	body_entered.connect(func(c):
		if c.is_in_group("jogador"):
			perto = true
			dica.visible = true
	)
	body_exited.connect(func(c):
		if c.is_in_group("jogador"):
			perto = false
			dica.visible = false
	)


func _process(_delta: float) -> void:
	if not perto or not Input.is_action_just_pressed("interagir"):
		return
	_comprar()


func _comprar() -> void:
	if tipo == "vida" and Jogo.upgrade_vida_comprado:
		Jogo.mensagem.emit("Vida extra ja comprada!")
		return
	if tipo == "dano" and Jogo.upgrade_dano_comprado:
		Jogo.mensagem.emit("Dano extra ja comprado!")
		return
	if tipo == "especial" and Jogo.upgrade_especial_comprado:
		Jogo.mensagem.emit("Ja comprou o especial!")
		return
	if Jogo.moedas < preco:
		Jogo.mensagem.emit("Moedas insuficientes (%d)" % preco)
		return
	Jogo.moedas -= preco
	Jogo.moedas_mudaram.emit()
	Sons.tocar("moeda")
	if tipo == "vida":
		Jogo.upgrade_vida_comprado = true
		Jogo.max_coracoes = mini(Jogo.max_coracoes + 1, Jogo.CORACOES_MAXIMOS)
		Jogo.coracoes = Jogo.max_coracoes
		Jogo.coracoes_mudaram.emit()
		Jogo.mensagem.emit("Vida maxima +1!")
	elif tipo == "dano":
		Jogo.upgrade_dano_comprado = true
		Jogo.dano_extra += 1
		Jogo.mensagem.emit("Seu dano aumentou!")
	elif tipo == "especial":
		Jogo.upgrade_especial_comprado = true
		Jogo.especial = 100.0
		Jogo.especial_mudou.emit()
		Jogo.mensagem.emit("Especial carregado!")
	texto.text = nome + "\nOK"
	dica.visible = false
	perto = false
