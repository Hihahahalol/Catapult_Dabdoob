extends VBoxContainer


@onready var _description_label = $AppInfo/AppDescription
@onready var _links_title = $Links/LinksTitle
@onready var _thank_you_title = $ThankYou/ThankYouTitle
@onready var _thank_you_content = $ThankYou/ThankYouContent


func _ready() -> void:
	_set_localized_text()


func _set_localized_text() -> void:
	# Format description with colored "Dabdoob" text
	var desc_text = tr("about_app_desc")
	desc_text = desc_text.replace("Dabdoob", "[color=#CD853F]Dabdoob[/color]")
	_description_label.text = desc_text
	
	_links_title.text = tr("about_links")
	
	# Set thank you section text
	_thank_you_title.text = tr("thank_you_title")
	_thank_you_content.text = tr("thank_you_message")


func _on_Tabs_tab_changed(tab: int) -> void:
	# About tab is index 7
	if tab == 7:
		_set_localized_text() 