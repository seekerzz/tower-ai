extends StatusEffect
class_name StunEffect

## 眩晕效果 - 使目标无法攻击

var original_atk_speed: float = 0.0
var stun_source: Node = null

func _init(duration: float = 1.0):
	type_key = "stunned"
	self.duration = duration

func setup(target: Node, source: Object, params: Dictionary):
	super.setup(target, source, params)

	stun_source = source
	if params.has("duration"):
		self.duration = params.duration

	# 应用眩晕效果
	if target != null and target is Node2D:
		target.set_meta("is_stunned", true)
		target.set_meta("stun_source", source)

		# 保存原始攻击速度并设为0
		var stats = target.get_node_or_null("Stats")
		if stats:
			original_atk_speed = stats.atk_speed
			stats.atk_speed = 0.0

		# 显示眩晕视觉效果
		var visual = target.get_node_or_null("VisualController")
		if visual:
			visual.set_idle_enabled(false)

		# 显示眩晕图标或文字
		GameManager.spawn_floating_text(target.global_position, "💫 眩晕!", Color.YELLOW)

func _exit_tree():
	var target = get_parent()
	if is_instance_valid(target) and target is Node2D:
		target.remove_meta("is_stunned")
		target.remove_meta("stun_source")

		# 恢复攻击速度
		var stats = target.get_node_or_null("Stats")
		if stats and original_atk_speed > 0:
			stats.atk_speed = original_atk_speed

		# 恢复动画
		var visual = target.get_node_or_null("VisualController")
		if visual:
			visual.set_idle_enabled(true)

		# 显示恢复文字
		GameManager.spawn_floating_text(target.global_position, "✨ 恢复", Color.GREEN)
