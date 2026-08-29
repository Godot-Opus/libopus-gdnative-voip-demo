extends Node

const SERVER_PORT = 3000
const MAX_PLAYERS = 20
const DEFAULT_SERVER_IP = "127.0.0.1"

func start_client(server_ip: String = ""):
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.server_disconnected.connect(_server_disconnected)
	multiplayer.connection_failed.connect(_connected_fail)

	if server_ip.strip_edges().is_empty():
		server_ip = DEFAULT_SERVER_IP

	var peer = ENetMultiplayerPeer.new()

	var err = peer.create_client(server_ip.strip_edges(), SERVER_PORT)
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
	get_node("/root/Control/Log").text += "clients can connect to: %s (port %d)\n" % [", ".join(get_lan_addresses()), SERVER_PORT]

# Non-loopback IPv4 addresses of this machine, for other computers to connect to
func get_lan_addresses() -> Array:
	var addresses = []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127."):
			addresses.append(address)
	return addresses


func _player_connected(_id):
	get_node("/root/Control/Log").text += "player with id: %s connected\n" % _id

func _player_disconnected(_id):
	get_node("/root/Control/Log").text += "player with id: %s disconnected\n" % _id
