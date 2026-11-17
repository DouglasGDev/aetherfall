class_name BtStatus
## Status canonicos de um no de Behavior Tree. Separado para que as classes internas
## de BtTree referenciem constantes globais (escopo de classe externa e fraco em GDScript).

enum { FAILURE = 0, RUNNING = 1, SUCCESS = 2 }


static func name_of(s: int) -> String:
	match s:
		FAILURE: return "FAIL"
		RUNNING: return "RUN"
		SUCCESS: return "OK"
		_: return "?"
