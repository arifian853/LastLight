extends Control

signal upgrade_chosen(id: StringName)

const UpgradeData = preload("res://scripts/progression/upgrade_data.gd")

var _options: Array[UpgradeData] = []
var _locked: bool = true
@onready var cards: Array[Button] = [$Center/Content/Cards/First, $Center/Content/Cards/Second, $Center/Content/Cards/Third]


func _ready() -> void:
	for index in range(cards.size()):
		cards[index].pressed.connect(_choose.bind(index))


func show_choices(options: Array[UpgradeData], ranks: Dictionary, new_level: int) -> void:
	_options = options.duplicate()
	_locked = false
	$Center/Content/Heading.text = "THE LIGHT GROWS  /  LEVEL %d" % new_level
	for index in range(cards.size()):
		var option := _options[index]
		var rank: int = int(ranks.get(option.id, 0)) + 1
		var rank_text := "Rank %d" % rank if option.max_level == 0 else "Rank %d / %d" % [rank, option.max_level]
		cards[index].text = "%d\n\n%s\n%s\n\n%s" % [index + 1, option.display_name, rank_text, option.description]
	show()
	cards[0].grab_focus()


func _choose(index: int) -> void:
	if not visible or _locked or index < 0 or index >= _options.size():
		return
	_locked = true
	upgrade_chosen.emit(_options[index].id)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index: int = event.keycode - KEY_1
	if index >= 0 and index < 3:
		get_viewport().set_input_as_handled()
		_choose(index)
