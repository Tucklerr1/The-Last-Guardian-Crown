extends Control
# Tela de créditos.

@onready var texto: Label = $Conteudo/Caixa/Texto
@onready var voltar: Button = $Conteudo/Caixa/Voltar


func _ready() -> void:
	Util.texto(texto, 10, Color("#fff4d0"))
	Util.estilo_botao(voltar, Color("#3a2a6a"), 14)
	voltar.custom_minimum_size = Vector2(130, 24)
	voltar.pressed.connect(func(): get_tree().change_scene_to_file("res://cenas/menu.tscn"))
	voltar.grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
