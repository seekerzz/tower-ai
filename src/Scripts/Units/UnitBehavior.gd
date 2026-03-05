extends RefCounted
class_name UnitBehavior

var unit: Node2D

func _init(target_unit: Node2D):
	unit = target_unit

# Unit initialized (used for Buff broadcast, trap placement, attachment logic)
func on_setup():
	pass

# Called every frame (used for production timer, passive regeneration, meteor generation)
func on_tick(delta: float):
	pass

# Combat logic. Return true to completely takeover attack logic (e.g. Parrot, Peacock, Eel).
# Return false to use default attack logic.
func on_combat_tick(delta: float) -> bool:
	return false

# Called when active skill is triggered
func on_skill_activated():
	pass

# Called when unit takes damage. Return modified damage amount.
# Used for reflection, reduction.
func on_damage_taken(amount: float, source: Node2D) -> float:
	return amount

# Called when a projectile fired by this unit hits a target.
# Used for Spider webs, Lifesteal, etc.
func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	pass

# Called when stats are reset/recalculated (e.g. level up, buff change).
# Used for updating range or internal state.
func on_stats_updated():
	pass

# Called to broadcast buffs to neighbors or other units.
# Called after all units have reset stats.
func broadcast_buffs():
	pass

# Called when active skill targeting completes and skill is executed at position
func on_skill_executed_at(grid_pos: Vector2i):
	pass

# Helper to get trap type for placement sequence
func get_trap_type() -> String:
	return ""

# Called when this unit kills a victim
func on_kill(victim: Node2D):
	pass

# Called before unit is destroyed
func on_cleanup():
	pass
