extends Node
## Test-only equivalent of the wheel player announcing the next teamwork task.
## Gameplay commands still originate from their assigned role clients.
var harness
var level
var sequence := 0
var accepted := 0
func publish(index: int) -> void:
	sequence+=1
	relay.rpc_id(1,index,sequence)
@rpc("any_peer","call_remote","reliable",3)
func relay(index: int,serial: int) -> void:
	if not multiplayer.is_server() or level.roles.get(multiplayer.get_remote_sender_id(),-1)!=2: return
	adopt(index,serial)
	adopt.rpc(index,serial)
@rpc("authority","call_remote","reliable",3)
func adopt(index: int,serial: int) -> void:
	if level.role==2 or serial<=accepted: return
	accepted=serial
	harness.task_index=index
	harness.waypoint=0
	harness.task_ticks=0
	if index<harness.tasks.size() and harness.tasks[index].kind=="drive": harness.jumped=false
