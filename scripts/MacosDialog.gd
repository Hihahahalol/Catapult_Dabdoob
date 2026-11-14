extends WindowDialog

signal game_selected(game)

onready var _textBox := $Panel/Margin/VBox/MacosText

func open(active: Dictionary, saves: Array) -> void:
	if active["dda"] == "": $Panel/Margin/VBox/HBox/BtnDDA.hide()
	if active["eod"] == "": $Panel/Margin/VBox/HBox/BtnEOD.hide()
	if active["tish"] == "": $Panel/Margin/VBox/HBox/BtnTISH.hide()

	_textBox.clear()
	_textBox.append_bbcode(tr("str_macos_intro"))
	_textBox.append_bbcode(" ")
	_textBox.append_bbcode(tr("str_macos_question_played") if saves.size() == 0 else tr("str_macos_question_save"))
	if saves.size() > 0:
		_textBox.append_bbcode("\n\n")

	for save in saves:
		_textBox.append_bbcode(save)
		_textBox.append_bbcode("\n")

	rect_size = Vector2(1000, 600)
	popup_centered()

func _on_MacosText_meta_clicked(meta):
	OS.shell_open(str(meta))

func _on_MacosDialog_popup_hide():
	emit_signal("game_selected", "")
	hide()

func _on_BtnCloseMacos_pressed() -> void:
	emit_signal("game_selected", "")
	hide()

func _on_BtnDDA_pressed():
	emit_signal("game_selected", "dda")
	hide()

func _on_BtnEOD_pressed():
	emit_signal("game_selected", "eod")
	hide()

func _on_BtnTISH_pressed():
	emit_signal("game_selected", "tish")
	hide()
