extends CanvasLayer

signal start_game

func show_message(text):
	$MessageLabel.text = text
	$MessageLabel.show()
	$MessageTimer.start()
	
func show_game_over():
	show_message("Game Over")
	await get_tree().create_timer(1000).timeout
	$MessageLabel.text = "A cliche way"
	$MessageLabel.show()
	await get_tree().create_timer(1000).timeout
	$StartButton.show()

func update_score(score):
	$ScoreLabel.text = str(score)
	
func _on_StartButton_pressed():
	$StartrButton.hide()
	emit_signal("start_game")
	
func _on_MessageTimer_timeout():
	$MessageLabel.hide()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://GameView.tscn")
