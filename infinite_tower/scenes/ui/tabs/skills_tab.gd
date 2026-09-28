extends MarginContainer
## Expedition "Skills" tab: the same Ragnarok-style job tree as the TALENTS
## menu panel, so both views stay in sync.

const TalentsPage = preload("res://scenes/ui/menu/pages/talents_page.gd")
const Ornate = preload("res://scenes/ui/menu/ornate.gd")


func _ready() -> void:
	var page = TalentsPage.new()
	page.theme = Ornate.theme()
	add_child(page)
