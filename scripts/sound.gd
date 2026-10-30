class_name GameSound
extends Node

var effects: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var beat = 0.0
var note_index = 0
var notes = [220.0, 277.18, 329.63, 277.18, 196.0, 246.94, 293.66, 246.94]
var playing = false

func _ready() -> void:
	for i in range(6):
		var player = AudioStreamPlayer.new()
		add_child(player)
		effects.append(player)
	music = AudioStreamPlayer.new()
	music.volume_db = -24
	add_child(music)

func tone(frequency: float, duration: float, volume: float = 0.25) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data = PackedByteArray()
	var count = int(duration * 22050)
	data.resize(count * 2)
	for i in range(count):
		var envelope = minf(1.0, i / 100.0) * (1.0 - float(i) / count)
		var value = int(sin(TAU * frequency * i / 22050.0) * envelope * volume * 32767)
		data.encode_s16(i * 2, value)
	stream.data = data
	return stream

var cache: Dictionary = {}
func effect(name_value: String) -> void:
	var frequencies = {"jump": 440.0, "gold": 880.0, "energy": 660.0,
		"hit": 150.0, "death": 65.0, "shot": 240.0, "win": 1046.5}
	if not cache.has(name_value):
		cache[name_value] = tone(frequencies.get(name_value, 440.0), 0.16)
	for player in effects:
		if not player.playing:
			player.stream = cache[name_value]
			player.play()
			break

func _process(delta: float) -> void:
	if not playing:
		return
	beat -= delta
	if beat <= 0:
		beat += 0.3
		var key = "note%d" % note_index
		if not cache.has(key):
			cache[key] = tone(notes[note_index], 0.27)
		music.stream = cache[key]
		music.play()
		note_index = (note_index + 1) % notes.size()

func _exit_tree() -> void:
	playing = false
	for player in effects:
		player.stop()
		player.stream = null
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	cache.clear()
