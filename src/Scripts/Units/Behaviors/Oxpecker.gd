extends "res://src/Scripts/Units/Behaviors/DefaultBehavior.gd"

var extra_attack_damage_percent: float = 0.8

func on_setup():
	extra_attack_damage_percent = 0.8
	if unit.level >= 2:
		extra_attack_damage_percent = 1.2

	var host = unit.get_host_unit()
	if host:
		if not host.is_connected("attack_performed", _on_host_attack):
			host.attack_performed.connect(_on_host_attack)

func _on_host_attack(target_node):
	if !target_node or !is_instance_valid(target_node): return

	var host = unit.get_host_unit()
	if !host: return

	var damage = host.damage
	var extra_damage = damage * extra_attack_damage_percent

	if target_node.has_method("take_damage"):
		target_node.take_damage(extra_damage, unit, "physical")

	if unit.level >= 3:
		if target_node.has_method("add_debuff"):
			target_node.add_debuff("vulnerable", 1, 4.0)

func on_cleanup():
	var host = unit.get_host_unit()
	if is_instance_valid(host) and host.is_connected("attack_performed", _on_host_attack):
		host.attack_performed.disconnect(_on_host_attack)
