extends Node

const COLORS = {
    "primary": Color("#3498db"),
    "success": Color("#2ecc71"),
    "danger":  Color("#e74c3c"),
    "dark_bg": Color("#2c3e50"),
    "panel_bg": Color(0.1, 0.1, 0.1, 0.5),
    "slot_bg": Color(0.2, 0.2, 0.2, 1),
    "text_light": Color(1.0, 1.0, 1.0)
}

const BAR_COLORS = {
    "hp": Color(0.8, 0.1, 0.1),
    "mana": Color(0.2, 0.4, 1.0)
}

const CARD_SIZE = {
    "small": Vector2(40, 40),
    "medium": Vector2(60, 60),
    "large": Vector2(80, 80)
}

const CORNER_RADIUS = {
    "small": 4,
    "medium": 6,
    "large": 8,
    "xlarge": 12
}

const MARGINS = {
    "sidebar_bottom_combat": -10.0,
    "sidebar_cushion": 40.0,
    "sidebar_shop_base_height": 200.0
}
