extends Control
## شاشة "انتهت اللعبة" — يملؤها HUD عند موت اللاعب

@onready var title_label: Label = $Center/VBox/TitleLabel
@onready var waves_label: Label = $Center/VBox/WavesLabel
@onready var kills_label: Label = $Center/VBox/KillsLabel
@onready var gold_label: Label = $Center/VBox/GoldLabel
@onready var restart_button: Button = $Center/VBox/RestartButton


func _ready() -> void:
	visible = false
	restart_button.pressed.connect(_on_restart_pressed)


func show_stats(waves: int, kills: int, gold: int) -> void:
	waves_label.text = "Waves Cleared: %d" % waves
	kills_label.text = "Total Kills: %d" % kills
	gold_label.text = "Gold Earned: %d" % gold
	visible = true
	restart_button.grab_focus()


func _on_restart_pressed() -> void:
	GM.reset_run()
	SceneTransition.reload_current()
