extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"
class_name Butterfly

var skill_active: bool = false
var pending_bonus_damage: float = 0

func on_skill_activated():
	var mana_cost = GameManager.max_mana * 0.05
	if GameManager.mana < mana_cost:
		return

	# Only activate if mana consumption succeeds
	if not GameManager.consume_resource("mana", mana_cost):
		return

	var damage_multiplier = 1.2 if unit.level < 2 else 1.8
	pending_bonus_damage = mana_cost * damage_multiplier
	skill_active = true

	GameManager.spawn_floating_text(unit.global_position, "Empowered!", Color.MAGENTA)

func on_projectile_hit(target: Node2D, damage: float, projectile: Node2D):
	super.on_projectile_hit(target, damage, projectile)

	if skill_active:
		if target.has_method("take_damage"):
			target.take_damage(pending_bonus_damage, unit, "magic")
		skill_active = false
		pending_bonus_damage = 0

func on_kill(victim: Node2D):
	if unit.level >= 3:
		var restore = GameManager.max_mana * 0.1
		GameManager.add_resource("mana", restore)
		GameManager.spawn_floating_text(unit.global_position, "+%d Mana" % int(restore), Color.BLUE)
