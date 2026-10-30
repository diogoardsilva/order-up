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
}
const MUSIC: AudioStreamWAV = preload("res://assets/audio/music.wav")
const SIZZLE: AudioStreamWAV = preload("res://assets/audio/sizzle.wav")
const VOICES := 10

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()
var _sizzle := AudioStreamPlayer.new()
var _sizzle_target := -80.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for stream: AudioStreamWAV in [MUSIC, SIZZLE]:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
	_music.stream = MUSIC
	_music.volume_db = -9.0
	_music.bus = "Music"
	add_child(_music)
	_sizzle.stream = SIZZLE
	_sizzle.volume_db = -80.0
	_sizzle.bus = "SFX"
	add_child(_sizzle)


func play(name: String, volume_db := 0.0, pitch_spread := 0.06) -> void:
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = SOUNDS[name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.play()


func music_on() -> void:
	if not _music.playing:
		_music.play()


## Chiar dos fogões: 0 (nenhum ao lume) a 1 (vários).
func set_sizzle(amount: float) -> void:
	_sizzle_target = -80.0 if amount <= 0.0 else lerpf(-18.0, -8.0, clampf(amount, 0.0, 1.0))


func _process(delta: float) -> void:
	_sizzle.volume_db = move_toward(_sizzle.volume_db, _sizzle_target, delta * 60.0)
	if _sizzle.volume_db > -79.0 and not _sizzle.playing:
		_sizzle.play()
	elif _sizzle.volume_db <= -79.0 and _sizzle.playing:
		_sizzle.stop()
