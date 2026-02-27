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
    """Called when merged, preserves devour bonuses from both wolves"""
    if other_unit is UnitWolf:
        var other_wolf = other_unit as UnitWolf

        # Merge stat bonuses
        if other_wolf.consumed_data.has("damage_bonus"):
            if not consumed_data.has("damage_bonus"): consumed_data["damage_bonus"] = 0.0
            consumed_data["damage_bonus"] += other_wolf.consumed_data.damage_bonus * 0.5

        if other_wolf.consumed_data.has("hp_bonus"):
            if not consumed_data.has("hp_bonus"): consumed_data["hp_bonus"] = 0.0
            consumed_data["hp_bonus"] += other_wolf.consumed_data.hp_bonus * 0.5

        # Merge mechanics
        for mechanic in other_wolf.consumed_mechanics:
            if mechanic not in consumed_mechanics:
                consumed_mechanics.append(mechanic)
                if mechanic not in active_buffs:
                    apply_buff(mechanic, self)

        # Record merge info
        consumed_data["merged_with"] = other_wolf.consumed_data

        GameManager.spawn_floating_text(global_position, "Wolf Merge!", Color.GOLD)

        # Apply stats immediately (base_damage is reset in reset_stats before this call usually,
        # but reset_stats uses consumed_data. So if we update consumed_data, we should re-apply stats or call reset_stats again?
        # merge_with calls reset_stats. Then UnitDragHandler calls on_merged_with.
        # So we need to re-apply stats here.

        base_damage += consumed_data.get("damage_bonus", 0.0)
        # Note: reset_stats sets base_damage = damage (from unit_data).
        # Then adds consumed_data bonus.
        # If we just updated consumed_data, we should re-run that logic.

        damage = base_damage # This might be wrong if base_damage already includes bonus?
        # Let's look at reset_stats:
        # base_damage = damage (from unit_data)
        # if consumed_data.has("damage_bonus"): base_damage += bonus; damage = base_damage

        # So here, we are AFTER reset_stats. base_damage has the OLD bonus included (from self).
        # We need to add the NEW part of the bonus.
        # OR simpler: just re-run the stat application part of reset_stats.

        var damage_from_data = 0.0
        if unit_data.has("levels") and unit_data["levels"].has(str(level)):
             damage_from_data = unit_data["levels"][str(level)].get("damage", 0)
        else:
             damage_from_data = unit_data.get("damage", 0)

        base_damage = damage_from_data
        if consumed_data.has("damage_bonus"):
            base_damage += consumed_data.damage_bonus
        damage = base_damage

        max_hp += consumed_data.get("hp_bonus", 0.0) # This adds ON TOP of current max_hp?
        # reset_stats sets max_hp from data.
        # Then adds bonus.
        # So we should recalculate max_hp from base too.
        # But max_hp is trickier.
        # Let's keep it simple: just update damage and max_hp by adding the *delta* or re-calculating.
        # The simplest is to rely on the fact that consumed_data is updated.
        # We can just run the logic from reset_stats again.

        # Recalculate max_hp
        # We don't have easy access to base stats here without duplicating reset_stats logic.
        # But we know what we added.
        # Actually, let's just add the *other wolf's* contribution.
        # No, because we multiplied by 0.5.

        # Re-run logic:
        # We can't call reset_stats because it resets active_buffs etc.

        # Let's trust base_damage is correct for *this* wolf's level (it was just leveled up and reset).
        # reset_stats: base_damage = damage (base). base_damage += consumed_data.bonus.
        # Now we added MORE to consumed_data.bonus.
        # We need to add that difference to base_damage and damage.

        # But wait, reset_stats was called for level 2 (merged).
        # It used the OLD consumed_data.
        # Now we update consumed_data.
        # We need to apply the difference.

        # Since I can't easily calc difference without knowing old value,
        # I'll just manually set damage = base_stat + total_bonus.
        # And base_stat for damage we can get from unit_data (since we are level 2).
        # Actually, `damage` right now is `base_stat + old_bonus`.
        # `base_damage` right now is `base_stat + old_bonus`.
        # So:
        # damage = base_damage - old_bonus + new_bonus? No base_damage includes bonus.

        # Correct approach:
        # base_damage -= (consumed_data["damage_bonus"] - increase) # Hard.

        # Let's just grab base damage from unit_data again.
        var stats = unit_data
        if unit_data.has("levels") and unit_data["levels"].has(str(level)):
            stats = unit_data["levels"][str(level)]
        var raw_damage = stats.get("damage", unit_data.get("damage", 0))
        var raw_hp = stats.get("hp", unit_data.get("hp", 0))

        base_damage = raw_damage
        if consumed_data.has("damage_bonus"):
            base_damage += consumed_data.damage_bonus
        damage = base_damage

        max_hp = raw_hp
        if consumed_data.has("hp_bonus"):
            max_hp += consumed_data.hp_bonus

        current_hp = max_hp

func get_description() -> String:
    var desc = unit_data.get("description", "")
    if not consumed_data.is_empty():
        desc += "\n[Devour] %s" % consumed_data.get("unit_name", "Unknown")
        if consumed_data.has("inherited_mechanics"):
            var mechs = consumed_data["inherited_mechanics"]
            if mechs.size() > 0:
                desc += " - Inherited: " + ", ".join(mechs)
    return desc
