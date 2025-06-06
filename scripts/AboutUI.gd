extends VBoxContainer


onready var _version_label = $AppInfo/AppVersion
onready var _title_label = $AppInfo/AppTitle
onready var _description_label = $AppInfo/AppDescription
onready var _links_title = $Links/LinksTitle


func _ready() -> void:
	_set_localized_text()


func _set_localized_text() -> void:
	# Set the version dynamically
	var version = Settings.get_hardcoded_version()
	_version_label.text = "Version: " + version
	
	# Set localized text
	_title_label.text = tr("about_app_title")
	
	# Format description with colored "Dabdoob" text
	var desc_text = tr("about_app_desc")
	desc_text = desc_text.replace("Dabdoob", "[color=#CD853F]Dabdoob[/color]")
	_description_label.bbcode_text = desc_text
	
	_links_title.text = tr("about_links")


func _on_Tabs_tab_changed(tab: int) -> void:
	# About tab is index 7
	if tab == 7:
		_set_localized_text() 