extends Node
## Sons e música (gerados por tools/make_sounds.py). Sfx.play("pickup") toca um
## efeito; a música e o chiar do fogão são loops com volume próprio.

const SOUNDS := {
	"ui_move": preload("res://assets/audio/ui_move.wav"),
	"ui_confirm": preload("res://assets/audio/ui_confirm.wav"),
	"ui_back": preload("res://assets/audio/ui_back.wav"),
	"pickup": preload("res://assets/audio/pickup.wav"),
	"drop": preload("res://assets/audio/drop.wav"),
	"chop": preload("res://assets/audio/chop.wav"),
	"wash": preload("res://assets/audio/wash.wav"),
	"plate": preload("res://assets/audio/plate.wav"),
	"ding": preload("res://assets/audio/ding.wav"),
	"coin": preload("res://assets/audio/coin.wav"),
	"fail": preload("res://assets/audio/fail.wav"),
	"bell": preload("res://assets/audio/bell.wav"),
	"trash": preload("res://assets/audio/trash.wav"),
	"dash": preload("res://assets/audio/dash.wav"),
	"note": preload("res://assets/audio/note.wav"),
	"round_end": preload("res://assets/audio/round_end.wav"),
	"step1": preload("res://assets/audio/step1.wav"),
	"step2": preload("res://assets/audio/step2.wav"),
	"door": preload("res://assets/audio/door.wav"),
	"kaching": preload("res://assets/audio/kaching.wav"),
	"served": preload("res://assets/audio/served.wav"),
	"angry": preload("res://assets/audio/angry.wav"),
	"happy": preload("res://assets/audio/happy.wav"),
	"throw": preload("res://assets/audio/throw.wav"),
	"catch": preload("res://assets/audio/catch.wav"),
	"achievement": preload("res://assets/audio/achievement.wav"),
	"splash": preload("res://assets/audio/splash.wav"),
	"step_done": preload("res://assets/audio/step_done.wav"),
	"count": preload("res://assets/audio/count.wav"),
	"go": preload("res://assets/audio/go.wav"),
	"sparkle": preload("res://assets/audio/sparkle.wav"),
	"star": preload("res://assets/audio/star.wav"),
	"pop": preload("res://assets/audio/pop.wav"),
	"swoosh": preload("res://assets/audio/swoosh.wav"),
	"lid": preload("res://assets/audio/lid.wav"),
	"burn": preload("res://assets/audio/burn.wav"),
}
const MUSIC: AudioStreamWAV = preload("res://assets/audio/music.wav")
const MUSIC_MENU: AudioStreamWAV = preload("res://assets/audio/music_menu.wav")
const MUSIC_DB := -14.0
const SIZZLE: AudioStreamWAV = preload("res://assets/audio/sizzle.wav")
const MURMUR: AudioStreamWAV = preload("res://assets/audio/murmur.wav")
const VOICES := 14

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()
var _sizzle := AudioStreamPlayer.new()
var _sizzle_target := -80.0
var _murmur := AudioStreamPlayer.new()
var _murmur_target := -80.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for stream: AudioStreamWAV in [MUSIC, MUSIC_MENU, SIZZLE, MURMUR]:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
	_music.volume_db = MUSIC_DB
	_music.bus = "Music"
	add_child(_music)
	_sizzle.stream = SIZZLE
	_sizzle.volume_db = -80.0
	_sizzle.bus = "SFX"
	add_child(_sizzle)
	_murmur.stream = MURMUR
	_murmur.volume_db = -80.0
	_murmur.bus = "SFX"
	add_child(_murmur)


func play(name: String, volume_db := 0.0, pitch_spread := 0.06) -> void:
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = SOUNDS[name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.play()


## Toca a música do menu ("menu") ou da cozinha ("game"), com fade ao trocar.
func music_on(kind := "menu") -> void:
	var stream := MUSIC_MENU if kind == "menu" else MUSIC
	if _music.stream == stream and _music.playing:
		return
	if _music.playing:
		var t := create_tween()
		t.tween_property(_music, "volume_db", -40.0, 0.5)
		await t.finished
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 1.0)


## Chiar dos fogões: 0 (nenhum ao lume) a 1 (vários).
func set_sizzle(amount: float) -> void:
	_sizzle_target = -80.0 if amount <= 0.0 else lerpf(-18.0, -8.0, clampf(amount, 0.0, 1.0))


## Burburinho do salão: 0 (vazio) a 1 (cheio).
func set_murmur(amount: float) -> void:
	_murmur_target = -80.0 if amount <= 0.0 else lerpf(-26.0, -15.0, clampf(amount, 0.0, 1.0))


## Som num sítio do ecrã: mais baixo e com o tom um pouco diferente de cada vez.
func play_soft(name: String, volume_db := -6.0) -> void:
	play(name, volume_db, 0.12)


func _process(delta: float) -> void:
	_murmur.volume_db = move_toward(_murmur.volume_db, _murmur_target, delta * 30.0)
	if _murmur.volume_db > -79.0 and not _murmur.playing:
		_murmur.play()
	elif _murmur.volume_db <= -79.0 and _murmur.playing:
		_murmur.stop()
	_sizzle.volume_db = move_toward(_sizzle.volume_db, _sizzle_target, delta * 60.0)
	if _sizzle.volume_db > -79.0 and not _sizzle.playing:
		_sizzle.play()
	elif _sizzle.volume_db <= -79.0 and _sizzle.playing:
		_sizzle.stop()
