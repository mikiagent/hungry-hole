extends SceneTree
## Builds res://assets/fonts/fredoka_bold.tres (variable font pinned to weight 650) and a project theme using it.
func _init() -> void:
	var base: FontFile = load("res://assets/fonts/Fredoka.ttf")
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): 650}
	ResourceSaver.save(fv, "res://assets/fonts/fredoka_bold.tres")
	var th := Theme.new()
	th.default_font = load("res://assets/fonts/fredoka_bold.tres")
	th.default_font_size = 32
	ResourceSaver.save(th, "res://assets/fonts/game_theme.tres")
	print("font + theme saved")
	quit()
