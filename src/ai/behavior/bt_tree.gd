class_name BtTree
## Runtime de Behavior Tree enxuto e sem Node: arvore instanciada por arquetype,
## estado vive no ctx/blackboard. Regras do projeto (docs/design/04.1):
## - RUNNING so em folhas de tempo/locoposicao; folha logica resolve em 1 tick
## - SubtreeGuard devolve FAILURE com motivo quando o orcamento estoura (fail-visible)

class BtNode:
	var name_str: String = ""

	func tick(_ctx: Dictionary) -> int:
		return BtStatus.FAILURE

	func _to_string() -> String:
		return name_str


class Sequence:
	extends BtNode
	var children: Array = []

	func with(p_children: Array) -> Sequence:
		children = p_children
		return self

	func tick(ctx: Dictionary) -> int:
		for c in children:
			var s: int = c.tick(ctx)
			if s != BtStatus.SUCCESS:
				return s
		return BtStatus.SUCCESS


class Selector:
	extends BtNode
	var children: Array = []

	func with(p_children: Array) -> Selector:
		children = p_children
		return self

	func tick(ctx: Dictionary) -> int:
		for c in children:
			var s: int = c.tick(ctx)
			if s != BtStatus.FAILURE:
				return s
		return BtStatus.FAILURE


class Condition:
	extends BtNode
	var fn: Callable

	func init(p_name: String, p_fn: Callable) -> Condition:
		name_str = p_name
		fn = p_fn
		return self

	func tick(ctx: Dictionary) -> int:
		return BtStatus.SUCCESS if fn.call(ctx) else BtStatus.FAILURE


class Action:
	extends BtNode
	var fn: Callable

	func init(p_name: String, p_fn: Callable) -> Action:
		name_str = p_name
		fn = p_fn
		return self

	func tick(ctx: Dictionary) -> int:
		var r: Variant = fn.call(ctx)
		if typeof(r) == TYPE_INT:
			return r
		return BtStatus.SUCCESS if bool(r) else BtStatus.FAILURE


class Cooldown:
	extends BtNode
	var child: BtNode
	var seconds: float = 1.0
	var _last: float = -9999.0

	func init(p_name: String, p_child: BtNode, p_seconds: float) -> Cooldown:
		name_str = p_name
		child = p_child
		seconds = p_seconds
		return self

	func tick(ctx: Dictionary) -> int:
		var elapsed: float = ctx.get("elapsed", 0.0)
		if elapsed - _last < seconds:
			return BtStatus.FAILURE
		var s: int = child.tick(ctx)
		if s == BtStatus.SUCCESS:
			_last = elapsed
		return s


class Inverter:
	extends BtNode
	var child: BtNode

	func init(p_child: BtNode) -> Inverter:
		child = p_child
		return self

	func tick(ctx: Dictionary) -> int:
		var s: int = child.tick(ctx)
		if s == BtStatus.SUCCESS:
			return BtStatus.FAILURE
		if s == BtStatus.FAILURE:
			return BtStatus.SUCCESS
		return BtStatus.RUNNING


class SubtreeGuard:
	extends BtNode
	var child: BtNode
	var budget_us: int = 250
	var last_us: int = 0
	var trips: int = 0

	func init(p_name: String, p_child: BtNode, p_budget_us: int) -> SubtreeGuard:
		name_str = p_name
		child = p_child
		budget_us = p_budget_us
		return self

	func tick(ctx: Dictionary) -> int:
		var t0 := Time.get_ticks_usec()
		var s: int = child.tick(ctx)
		last_us = Time.get_ticks_usec() - t0
		if last_us > budget_us:
			trips += 1
			return BtStatus.FAILURE
		return s
