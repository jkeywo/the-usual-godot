class_name VillageAudio
extends Node

var muted: bool = false
var unlocked: bool = false
var place: int = -1
var players: Dictionary = {}
var ambience: AudioStreamPlayer


func _ready() -> void:
	for cue: String in ["click", "accept", "reject", "cancel", "complete", "notice", "step"]:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/original/audio/" + cue + ".wav")
		player.volume_db = -16 if cue == "step" else -10
		players[cue] = player
		add_child(player)
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -15
	add_child(ambience)


func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.setAttribute('data-audio-unlocked', 'true')", true)
	set_place(place, true)


func play(cue: String) -> void:
	if unlocked and not muted and DisplayServer.get_name() != "headless" and players.has(cue):
		players[cue].play()
		if OS.has_feature("web"):
			JavaScriptBridge.eval(
				(
					"document.body.setAttribute('data-audio-playing', '"
					+ str(players[cue].playing).to_lower()
					+ "')"
				),
				true
			)


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		stop()
	else:
		set_place(place, true)


func stop() -> void:
	for player: AudioStreamPlayer in players.values():
		player.stop()
	if ambience != null:
		ambience.stop()


func set_place(value: int, restart: bool = false) -> void:
	if value == place and not restart:
		return
	place = value
	if ambience == null or muted or not unlocked or DisplayServer.get_name() == "headless":
		return
	var stream: AudioStreamWAV = (
		load("res://assets/original/audio/" + ("outside" if place == 3 else "room") + ".wav")
		. duplicate()
	)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	ambience.stream = stream
	ambience.play()
