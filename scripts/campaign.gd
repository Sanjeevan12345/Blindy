extends Node
## Persistent transition handshake: scene changes never replace the ENet session.
var continuing := false
var solo := false
var roles: Dictionary = {}
var local_role := 0
var loaded: Dictionary = {}
var launch_solo := false
var resume_three := false

func mark_loaded() -> void:
	if solo:
		start_loaded_session()
	elif multiplayer.is_server():
		loaded[1]=true
		try_start()
	else:
		peer_loaded.rpc_id(1)

@rpc("any_peer","call_remote","reliable")
func peer_loaded() -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_remote_sender_id()
		if id in roles:
			loaded[id]=true
			try_start()

func try_start() -> void:
	if loaded.size()==roles.size() and roles.size()==3:
		start_loaded_session.rpc()

@rpc("authority","call_local","reliable")
func start_loaded_session() -> void:
	continuing=false
	var scene := get_tree().current_scene
	if scene != null:
		scene.begin_session()
