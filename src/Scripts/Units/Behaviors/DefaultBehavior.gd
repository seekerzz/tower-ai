extends "res://src/Scripts/Units/UnitBehavior.gd"

# Default behavior for standard units.
# Combat is handled by Unit.gd's default logic (since on_combat_tick returns false).
# No special setup, tick, or damage handling by default.

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	if "forest_blessing" in unit.active_buffs:
		var source = unit.buff_sources.get("forest_blessing")
		if source and is_instance_valid(source) and source.behavior.has_method("get_debuff_chance"):
			if randf() < source.behavior.get_debuff_chance():
				var debuffs = source.behavior.debuff_types
				var type = debuffs[randi() % debuffs.size()]
				var stacks = 1
				if source.level >= 3 and randf() < 0.15:
					stacks = 2
				if target.has_method("apply_debuff"):
					target.apply_debuff(type, stacks)
