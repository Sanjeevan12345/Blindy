extends Node
var epoch := 0.0
@rpc("authority","call_local","reliable")
func begin(at: float) -> void: epoch=at
