extends Node

const SERVER_PORT = 3000
const MAX_PLAYERS = 20
const SERVER_IP = "127.0.0.1"

func start_client():
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.server_disconnected.connect(_server_disconnected)
	multiplayer.connection_failed.connect(_connected_fail)

	var peer = ENetMultiplayerPeer.new()

	var err = peer.create_client(SERVER_IP, SERVER_PORT)
	if err != OK:
		get_node("/root/Control/Status").text = "failed to create client!"
		return

	multiplayer.multiplayer_peer = peer

	get_node("/root/Control/Status").text = "connecting..."
	get_node("/root/Control/Button_voice").disabled = false

func _connected_ok():
	get_node("/root/Control/Status").text = "connected ok"


func _connected_fail():
	get_node("/root/Control/Status").text = "failed to connect to server!"

func _server_disconnected():
	get_node("/root/Control/Status").text = "server disconnected"


################################
#SERVER
################################

func start_server():
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)

	var peer = ENetMultiplayerPeer.new()

	var err = peer.create_server(SERVER_PORT, MAX_PLAYERS)

	if err != OK:
		get_node("/root/Control/Status").text = "Failed to create server!"
		return

	multiplayer.multiplayer_peer = peer

	get_node("/root/Control/Status").text = "server started"
	get_node("/root/Control/Button_voice").disabled = false


func _player_connected(_id):
	get_node("/root/Control/Log").text += "player with id: %s connected\n" % _id

func _player_disconnected(_id):
	get_node("/root/Control/Log").text += "player with id: %s disconnected\n" % _id
