extends RefCounted
class_name UnitBehavior

const DamageContext = preload("res://src/Scripts/CoreMechanics/DamageContext.gd")

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

# Phase A: Hit detection. Can set context.is_miss or context.is_dodge.
func on_pre_damage_hit(_context: DamageContext):
	pass

# Phase B: Damage reduction and shield. Modify context.final_damage.
func on_calculate_mitigation(_context: DamageContext):
	pass

# Phase C: Final damage applied to stats.
func on_damage_applied(_context: DamageContext):
	pass

# Phase D: Feedback (reflection, etc.)
func on_post_damage_applied(_context: DamageContext):
	pass

# DEPRECATED: Use new lifecycle hooks above.
func on_damage_taken(amount: float, _source: Node) -> float:
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
