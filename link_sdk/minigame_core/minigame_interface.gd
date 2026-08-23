extends Node
class_name IMinigame

# Signal indicating minigame completion
signal finished(minigame_inst: IMinigame) 

# Initialize minigame with start parameters
func init(_params: StartParams) -> void:
	push_error("Not implemented")

# Stop minigame and return results
func stop() -> EndParams:
	push_error("Not implemented")
	return null

# Pause minigame. Returns true if successfully paused
func pause() -> bool:
	push_error("Not implemented")
	return false

# Resume minigame after pause. Returns true if successfully resumed
func resume() -> bool:
	push_error("Not implemented")
	return false
