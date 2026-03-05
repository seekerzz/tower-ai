extends Button

signal card_selected(key)

const EMOJI_MAP = {
	"MECHANIC": "⚙️",
	"NATURE": "🌿",
	"cow_totem": "🐮",
	"bat_totem": "🦇",
	"viper_totem": "🐍",
	"butterfly_totem": "🦋",
	"eagle_totem": "🦅"
}

@onready var icon_rect = $VBoxContainer/Icon
@onready var emoji_label = $VBoxContainer/EmojiLabel
@onready var title_label = $VBoxContainer/TitleLabel
@onready var desc_label = $VBoxContainer/DescLabel

var _key: String

func _ready():
	pressed.connect(_on_pressed)

func setup(key: String, data: Dictionary):
	_key = key

	# Set text content
	title_label.text = data.get("name", key)
	desc_label.text = data.get("desc", "No description")

	# Try to load image
	var image_path = "res://assets/images/cores/%s.png" % key.to_lower()
	if FileAccess.file_exists(image_path):
		var texture = load(image_path)
		if texture:
			icon_rect.texture = texture
			icon_rect.show()
			emoji_label.hide()
		else:
			_show_emoji(key)
	else:
		_show_emoji(key)

func _show_emoji(key: String):
	icon_rect.hide()
	emoji_label.show()

	if key in EMOJI_MAP:
		emoji_label.text = EMOJI_MAP[key]
	else:
		emoji_label.text = "❓"

func _on_pressed():
	card_selected.emit(_key)
