extends Node
## Thin wrapper around ENet. The host is always slot 1 and the player who joins is slot 2.
## Quick Duel runs on the default offline peer, where this machine acts as the host.

signal connected
signal connect_failed(reason: String)
signal opponent_left

const MAX_CLIENTS := 1
const MENU_SCENE := "res://scenes/menu/MainMenu.tscn"


func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): connected.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(func(): opponent_left.emit())
	multiplayer.peer_disconnected.connect(func(_id: int): opponent_left.emit())


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(Config.NET_PORT, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func join(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, Config.NET_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func go_offline() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func leave_to_menu() -> void:
	go_offline()
	get_tree().change_scene_to_file(MENU_SCENE)


func slot_of(peer_id: int) -> int:
	return 1 if peer_id == 1 else 2


func local_slot() -> int:
	return slot_of(multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	go_offline()
	connect_failed.emit("Could not reach the host.")
