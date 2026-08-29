extends AudioStreamPlayer

const MIN_PACKET_LENGTH = 1
const STREAM_IDLE_RESET = 0.5

var mic: AudioEffectRecord
var capture: AudioEffectCapture
var record
var recording = false
var streaming = false
var was_recording = false
var time_elapsed = 0.0
var since_last_packet = 0.0

@export var opusEncoderPath: NodePath
@onready var opusEncoder := get_node(opusEncoderPath)

@export var opusDecoderPath: NodePath
@onready var opusDecoder := get_node(opusDecoderPath)

@export var streamPlayerPath: NodePath
@onready var streamPlayer := get_node(streamPlayerPath)

func _ready():
	mic = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 0)
	capture = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 1)

@rpc("any_peer", "call_remote", "unreliable")
func _play(id, opusPackets, format, mix_rate, stereo):
	get_node("/root/Control/Log").text += "received audio from player with id: %s\n" % id

	# Decode the incoming packets into raw PCM data
	var pcmData = opusDecoder.decode(opusPackets)

	var audioStream = AudioStreamWAV.new()
	audioStream.data = pcmData
	audioStream.set_format(format)
	audioStream.set_mix_rate(mix_rate)
	audioStream.set_stereo(stereo)
	stream = audioStream
	play()

@rpc("any_peer", "call_remote", "unreliable")
func _stream_packet(_id, packet):
	since_last_packet = 0.0

	var frames = opusDecoder.decode_frame(packet)
	if frames.size() == 0:
		return

	if not streamPlayer.playing:
		streamPlayer.play()

	var playback = streamPlayer.get_stream_playback()
	if playback.can_push_buffer(frames.size()):
		playback.push_buffer(frames)

func _process(delta: float) -> void:
	if streaming:
		_process_streaming(delta)
		return

	if recording:
		if mic.is_recording_active():
			if time_elapsed >= MIN_PACKET_LENGTH:
				mic.set_recording_active(false)
				record = mic.get_recording()
				var pcmData = record.get_data()

				# Encode the raw PCM data to a stream of Opus Packets
				var opusEncoded = opusEncoder.encode(pcmData)

				_play.rpc(multiplayer.get_unique_id(), opusEncoded, record.get_format(), record.get_mix_rate(), record.is_stereo())
				get_node("/root/Control/Log").text += "send recording of size %s\n" % record.get_data().size()
				mic.set_recording_active(true)
				time_elapsed = 0.0

			time_elapsed += delta
		else:
			mic.set_recording_active(true)
	else:
		mic.set_recording_active(false)

func _process_streaming(delta: float) -> void:
	# The whole-clip recorder is not used while streaming
	if mic.is_recording_active():
		mic.set_recording_active(false)

	# End of a remote talk burst: stop playback and reset the decoder
	since_last_packet += delta
	if since_last_packet > STREAM_IDLE_RESET and streamPlayer.playing:
		streamPlayer.stop()
		opusDecoder.reset_stream()

	# Discard any mic audio captured before the button was pressed
	if recording and not was_recording:
		capture.clear_buffer()
		opusEncoder.reset_stream()
	was_recording = recording

	if recording:
		opusEncoder.push_audio(capture.get_buffer(capture.get_frames_available()))
		while opusEncoder.has_packet():
			var packet = opusEncoder.pop_packet()
			if packet.size() > 0:
				_stream_packet.rpc(multiplayer.get_unique_id(), packet)
