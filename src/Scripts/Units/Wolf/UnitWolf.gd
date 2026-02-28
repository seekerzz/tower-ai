class_name UnitWolf
extends Unit

var consumed_data: Dictionary = {}
var consumed_mechanics: Array = []
var has_selected_devour: bool = false

func _ready():
    super._ready()
    base_damage = damage

    # If first time placed (not loaded from save), show selection UI
    if not has_selected_devour:
        call_deferred("_show_devour_ui")

func _show_devour_ui():
    var ui_scene = load("res://src/Scenes/UI/WolfDevourUI.tscn")
    if ui_scene:
        var ui = ui_scene.instantiate()
        # Add to canvas layer or top level to ensure visibility
        get_tree().current_scene.add_child(ui)
        if ui.has_method("show_for_wolf"):
            ui.show_for_wolf(self)
        ui.tree_exited.connect(_on_devour_ui_closed)
    else:
        _auto_devour()

func _on_devour_ui_closed():
    has_selected_devour = true
    # If no target selected (consumed_data empty), auto select nearest
    if consumed_data.is_empty():
        _auto_devour()

func devour_target(target: Unit):
    if not target or not is_instance_valid(target):
        return
    _perform_devour(target)

func _auto_devour():
    var nearest = _get_nearest_unit()
    if nearest:
        _perform_devour(nearest)

func _perform_devour(target: Unit):
    # Record consumed data
    var u_name = target.unit_data.get("name", target.type_key.capitalize())
    consumed_data = {
        "unit_id": target.type_key,
        "unit_name": u_name,
        "level": target.level,
        "damage_bonus": target.damage * 0.5,
        "hp_bonus": target.max_hp * 0.5
    }

    # Inherit mechanics
    _inherit_mechanics(target)

    # Apply stats
    base_damage += consumed_data.damage_bonus
    damage = base_damage
    max_hp += consumed_data.hp_bonus
    current_hp = max_hp

    # 增加狼图腾魂魄
    TotemManager.add_resource("wolf", 10)

    # Remove target
    if GameManager.grid_manager:
        GameManager.grid_manager.remove_unit_from_grid(target)
    else:
        target.queue_free()

    # Visuals
    GameManager.spawn_floating_text(global_position, "Devoured %s!" % u_name, Color.RED)
    _play_devour_effect()

    # Emit signal for logging
    GameManager.unit_devoured.emit(self, target, consumed_data)

func _inherit_mechanics(target: Unit):
    consumed_mechanics.clear()
    # Check target active buffs
    for buff in target.active_buffs:
        match buff:
            "bounce", "split", "multishot", "poison", "fire":
                if buff not in consumed_mechanics:
                    consumed_mechanics.append(buff)
                if buff not in active_buffs:
                    apply_buff(buff, self)

    if not consumed_mechanics.is_empty():
        consumed_data["inherited_mechanics"] = consumed_mechanics.duplicate()

func _play_devour_effect():
    var effect_scene = load("res://src/Scenes/Effects/DevourEffect.tscn")
    if effect_scene:
        var effect = effect_scene.instantiate()
        effect.global_position = global_position
        get_tree().current_scene.add_child(effect)

func _get_nearest_unit() -> Unit:
    if !GameManager.grid_manager: return null
    var min_dist = 9999.0
    var nearest = null
    var my_pos = global_position

    for key in GameManager.grid_manager.tiles:
        var tile = GameManager.grid_manager.tiles[key]
        var unit = tile.unit
        if unit and unit != self and is_instance_valid(unit):
            var dist = my_pos.distance_to(unit.global_position)
            if dist < min_dist:
                min_dist = dist
                nearest = unit
    return nearest

func can_upgrade() -> bool:
    return level < 2  # 最高2级

var base_damage = 0.0

func reset_stats():
    super.reset_stats()
    base_damage = damage

    # Re-apply devoured stats bonus
    if consumed_data.has("damage_bonus"):
        base_damage += consumed_data.damage_bonus
        damage = base_damage

    if consumed_data.has("hp_bonus"):
        max_hp += consumed_data.hp_bonus
        current_hp = max_hp # Optionally heal or keep ratio? Prompt says "current_hp = max_hp" in _perform_devour, so maybe reset heals too? Standard merge does full heal.

    # Re-apply inherited mechanics
    for mech in consumed_mechanics:
        if mech not in active_buffs:
            apply_buff(mech, self)

func on_merged_with(other_unit: Unit):
    """Called when merged, preserves devour bonuses from both wolves.

    合并规则:
    1. 属性加成: 继承另一只狼50%的吞噬加成
    2. 机制继承: 合并两只狼的所有特殊机制
    3. 属性重算: 基于当前等级的基础属性 + 总加成
    """
    if not (other_unit is UnitWolf):
        return

    var other_wolf = other_unit as UnitWolf

    # 1. 合并属性加成 (继承50%)
    _merge_stat_bonuses(other_wolf)

    # 2. 合并特殊机制
    _merge_mechanics(other_wolf)

    # 3. 记录合并信息
    consumed_data["merged_with"] = other_wolf.consumed_data

    # 4. 重新计算最终属性
    _recalculate_merged_stats()

    GameManager.spawn_floating_text(global_position, "Wolf Merge!", Color.GOLD)


func _merge_stat_bonuses(other_wolf: UnitWolf):
    """合并另一只狼的属性加成 (继承50%)"""
    const INHERIT_RATIO = 0.5

    for bonus_key in ["damage_bonus", "hp_bonus"]:
        if other_wolf.consumed_data.has(bonus_key):
            if not consumed_data.has(bonus_key):
                consumed_data[bonus_key] = 0.0
            consumed_data[bonus_key] += other_wolf.consumed_data[bonus_key] * INHERIT_RATIO


func _merge_mechanics(other_wolf: UnitWolf):
    """合并特殊机制，避免重复"""
    for mechanic in other_wolf.consumed_mechanics:
        if mechanic not in consumed_mechanics:
            consumed_mechanics.append(mechanic)
        if mechanic not in active_buffs:
            apply_buff(mechanic, self)


func _recalculate_merged_stats():
    """基于当前等级和合并后的加成重新计算属性"""
    # 获取当前等级的基础属性
    var base_stats = _get_base_stats_for_level()

    # 应用属性加成
    base_damage = base_stats.damage
    max_hp = base_stats.hp

    if consumed_data.has("damage_bonus"):
        base_damage += consumed_data.damage_bonus
    if consumed_data.has("hp_bonus"):
        max_hp += consumed_data.hp_bonus

    damage = base_damage
    current_hp = max_hp


func _get_base_stats_for_level() -> Dictionary:
    """从unit_data获取当前等级的基础属性"""
    var stats = unit_data
    if unit_data.has("levels") and unit_data["levels"].has(str(level)):
        stats = unit_data["levels"][str(level)]

    return {
        "damage": stats.get("damage", unit_data.get("damage", 0)),
        "hp": stats.get("hp", unit_data.get("hp", 0))
    }

func get_description() -> String:
    var desc = unit_data.get("description", "")
    if not consumed_data.is_empty():
        desc += "\n[Devour] %s" % consumed_data.get("unit_name", "Unknown")
        if consumed_data.has("inherited_mechanics"):
            var mechs = consumed_data["inherited_mechanics"]
            if mechs.size() > 0:
                desc += " - Inherited: " + ", ".join(mechs)
    return desc
