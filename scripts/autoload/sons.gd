extends Node
# AUTOLOAD "Sons": efeitos (Sons.tocar("pulo")), música (Sons.musica("mundo_1")) e ambiente.
# Se algum arquivo de áudio não existir, o jogo simplesmente ignora o som (sem erro).

const SFX_RAIZ := ["pulo", "golpe", "dano", "moeda", "coracao", "explosao", "especial", "porta", "vitoria"]
const SFX_NOVOS := [
	"menu_mover", "menu_ok", "menu_voltar", "aterrissar", "golpe2", "acerto", "acerto_forte", "escudo",
	"rugido", "aviso", "entrada_chefe", "impacto", "fogo", "gelo", "estilhaco", "teleporte", "invocar",
	"congelar", "tiro", "flecha", "cuspe", "mola", "desmoronar", "segredo", "chiado", "asas",
	"morte_chefe", "pronto", "moeda_coleta", "raiz", "geiser", "espinho",
]
const VOZES := 4                     # quantos sons iguais podem tocar ao mesmo tempo
const VOL_MUSICA := -9.0
const VOL_AMBIENTE := -17.0

var _bancos := {}                    # nome -> {"fluxo": AudioStream, "players": Array, "i": int}
var _musica_a: AudioStreamPlayer
var _musica_b: AudioStreamPlayer
var _ambiente: AudioStreamPlayer
var _musica_atual := ""
var _ambiente_atual := ""
var _vol_extra := 0.0
var _tween_musica: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for nome in SFX_RAIZ:
		_registrar(nome, "res://audio/%s.wav" % nome)
	for nome in SFX_NOVOS:
		_registrar(nome, "res://audio/sfx/%s.wav" % nome)
	_musica_a = _criar_player(VOL_MUSICA)
	_musica_b = _criar_player(-80.0)
	_ambiente = _criar_player(-80.0)


func _criar_player(vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = vol
	add_child(p)
	return p


func _registrar(nome: String, caminho: String) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var fluxo: AudioStream = load(caminho)
	var lista: Array = []
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		p.stream = fluxo
		p.volume_db = -6.0
		add_child(p)
		lista.append(p)
	_bancos[nome] = {"players": lista, "i": 0}


func tocar(nome: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not _bancos.has(nome):
		return
	var banco: Dictionary = _bancos[nome]
	var lista: Array = banco["players"]
	var i: int = banco["i"]
	var p: AudioStreamPlayer = lista[i]
	banco["i"] = (i + 1) % lista.size()
	p.volume_db = -6.0 + vol_db
	p.pitch_scale = pitch
	p.play()


# Toca com variação aleatória de tom (evita repetição cansativa).
func tocar_var(nome: String, vol_db := 0.0) -> void:
	tocar(nome, vol_db, randf_range(0.92, 1.08))


func _ligar_loop(fluxo: AudioStream) -> void:
	if fluxo is AudioStreamWAV:
		var w := fluxo as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		var bytes := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
		if w.stereo:
			bytes *= 2
		w.loop_end = int(w.data.size() / bytes)


func musica(nome: String) -> void:
	if nome == _musica_atual:
		return
	_musica_atual = nome
	var caminho := "res://audio/musica/%s.wav" % nome
	var novo := _musica_b if _musica_a.playing and _musica_a.volume_db > -60.0 else _musica_a
	var velho := _musica_a if novo == _musica_b else _musica_b
	if nome != "" and ResourceLoader.exists(caminho):
		var fluxo: AudioStream = load(caminho)
		_ligar_loop(fluxo)
		novo.stream = fluxo
		novo.volume_db = -60.0
		novo.play()
	if _tween_musica:
		_tween_musica.kill()
	_tween_musica = create_tween().set_parallel(true)
	if novo.playing:
		_tween_musica.tween_property(novo, "volume_db", VOL_MUSICA + _vol_extra, 1.0)
	_tween_musica.tween_property(velho, "volume_db", -60.0, 1.0)
	_tween_musica.chain().tween_callback(velho.stop)


func parar_musica() -> void:
	musica("")


func ambiente(nome: String) -> void:
	if nome == _ambiente_atual:
		return
	_ambiente_atual = nome
	var caminho := "res://audio/ambiente/%s.wav" % nome
	if nome != "" and ResourceLoader.exists(caminho):
		var fluxo: AudioStream = load(caminho)
		_ligar_loop(fluxo)
		_ambiente.stream = fluxo
		_ambiente.volume_db = VOL_AMBIENTE
		_ambiente.play()
	else:
		_ambiente.stop()


# Abafa a música (menu de pausa).
func abafar(sim: bool) -> void:
	_vol_extra = -8.0 if sim else 0.0
	var alvo := _musica_a if _musica_a.volume_db > _musica_b.volume_db else _musica_b
	if alvo.playing:
		alvo.volume_db = VOL_MUSICA + _vol_extra
