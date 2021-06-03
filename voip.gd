extends AudioStreamPlayer

const MIN_PACKET_LENGTH = 1

var mic : AudioEffectRecord
var record
var recording = false
var time_elapsed = 0

export(NodePath) var opusEncoderPath
onready var opusEncoder := get_node(opusEncoderPath)

export(NodePath) var opusDecoderPath
onready var opusDecoder := get_node(opusDecoderPath)

func _ready():
	mic = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 0)

remote func _play(id, opusPackets, format, mix_rate, stereo):
	get_node("/root/Control/Log").text += "received audio from player with id: %s\n" % id

	# Decode the incoming packets into raw PCM data
	var pcmData = opusDecoder.decode(opusPackets)

	var audioStream = AudioStreamSample.new()
	audioStream.data = pcmData
	audioStream.set_format(format)
	audioStream.set_mix_rate(mix_rate)
	audioStream.set_stereo(stereo)
	stream = audioStream
	play()
	
func _process(delta: float) -> void:
	if recording:
		if mic.is_recording_active():
			if time_elapsed >= MIN_PACKET_LENGTH:
				mic.set_recording_active(false)
				record = mic.get_recording()
				var pcmData = record.get_data()
				
				# Encode the raw PCM data to a stream of Opus Packets
				var opusEncoded = opusEncoder.encode(pcmData)
				
				rpc_unreliable("_play",get_tree().get_network_unique_id(), opusEncoded, record.get_format(), record.get_mix_rate(), record.is_stereo())
				get_node("/root/Control/Log").text += "send recording of size %s\n" % record.get_data().size()
				mic.set_recording_active(true)
				time_elapsed = 0
				
			time_elapsed += delta
		else:
			mic.set_recording_active(true)
	else:
		mic.set_recording_active(false)
		

