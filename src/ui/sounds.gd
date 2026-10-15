class_name BuilderSounds
extends Node

var streams: Dictionary = {}
var player: AudioStreamPlayer
var enabled := true

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -14
	add_child(player)
	for kind in ["place", "remove", "select"]:
		var rate := 22050
		var duration := 0.16 if kind != "select" else 0.055
		var bytes := PackedByteArray()
		var rng := RandomNumberGenerator.new()
		rng.seed = 37
		for i in range(int(rate * duration)):
			var t := float(i) / rate
			var envelope := exp(-t * (32 if kind == "select" else 25))
			var tone := 150.0 if kind == "place" else (310.0 if kind == "remove" else 720.0)
			var value := (sin(TAU * tone * t) * 0.45 + rng.randf_range(-0.4, 0.4)) * envelope
			var pcm := int(clampf(value, -1, 1) * 32767)
			bytes.append(pcm & 255)
			bytes.append((pcm >> 8) & 255)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.data = bytes
		streams[kind] = stream

func play(kind: String) -> void:
	if enabled and streams.has(kind):
		player.stream = streams[kind]
		player.play()
