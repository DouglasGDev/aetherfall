// Passo 1 (c) do dossie 22 (S5.1): o esqueleto da extensao nativa do oraculo.
//
// Nada aqui encosta no llama.cpp de proposito. Em `.tools/llama/runtime/` nao existe
// nenhuma `.lib` de importacao (S12.3), entao "linkar o runtime" neste passo seria uma
// frase sobre um arquivo que nao esta na arvore; o gate de simbolos e do Passo 2, com
// import libs gerados do export-set medido e `/DELAYLOAD`. O que este arquivo deve provar
// e menor e verificavel: existe um `.dll` que o Godot 4.7.2 abre, que registra a classe
// `AfMindOracle` na `ClassDB` e que devolve um objeto vivo.
//
// A regra de ouro do prompt do dono ("a mente propoe, as regras dispoe") ainda nao tem o
// que desobedecer: esta classe nao tem funcao de IA nenhuma, nao move pe, nao aplica dano
// e nao escreve no ledger. O primeiro metodo de prompt chega no Passo 3 (S5.3).
//
// Compila contra o cabecalho de interface vendorado em `include/` (S6.1: fruto do gerador
// do Godot na tag 4.7.2-stable, conferido por SHA-256 no `build.bat`) e contra nenhuma
// outra dependencia.

#include <cstdint>

#include "gdextension_interface.h"

namespace {

// Toda funcao da interface chega por `p_get_proc_address`: nao ha linking estatico com o
// Godot, e um nome ausente e diagnostico, nao crash. Os tres nomes discriminantes da ABI
// 4.7.2 (S12.2) sao `classdb_register_extension_class6`, `classdb_construct_object3` e a
// struct `GDExtensionClassCreationInfo6`.
GDExtensionInterfacePrintError print_error_fn = nullptr;
GDExtensionInterfaceStringNameNewWithLatin1Chars string_name_new = nullptr;
GDExtensionInterfaceClassdbRegisterExtensionClass6 register_extension_class6 = nullptr;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_extension_class = nullptr;
GDExtensionInterfaceClassdbConstructObject3 construct_object3 = nullptr;
GDExtensionInterfaceObjectSetInstance set_instance = nullptr;
GDExtensionInterfaceGetGodotVersion2 get_godot_version2 = nullptr;

GDExtensionClassLibraryPtr library = nullptr;
bool class_registered = false;

const char *const CLASS_NAME = "AfMindOracle";
const char *const PARENT_NAME = "RefCounted";

// `r_dest` e "uninitialized storage, into which the newly created StringName is
// constructed": a engine escreve o StringName dela (16 bytes) dentro da storage que
// passamos. A interface 4.7.2 nao expoe destrutor de StringName, entao os dois nomes vivem
// o que o processo viver -- que e o ciclo de uma classe registrada no level CORE. 32 bytes
// alinhados a 8 e folga sobre os 16 da engine, nao um palpite de layout.
alignas(8) unsigned char sn_class_storage[32];
alignas(8) unsigned char sn_parent_storage[32];

GDExtensionConstStringNamePtr class_name_sn() {
	return reinterpret_cast<GDExtensionConstStringNamePtr>(sn_class_storage);
}

GDExtensionConstStringNamePtr parent_name_sn() {
	return reinterpret_cast<GDExtensionConstStringNamePtr>(sn_parent_storage);
}

// O corpo nativo ainda nao guarda estado de modelo: no Passo 1 ele existe para que
// `create_instance` e `free_instance` tenham o que construir e destruir, e para que
// `object_set_instance` tenha um ponteiro nao-nulo para amarrar ao objeto da engine. No
// Passo 2 e aqui que vao morar o pack carregado e a fila de inferencia.
struct AfMindOracleInstance {
	uint32_t marker;
};

GDExtensionObjectPtr create_instance(void *p_class_userdata, GDExtensionBool p_notify_postinitialize) {
	(void)p_class_userdata;
	// O alvo do construct e o PAI built-in, nao o nosso nome. Medido na sonda de
	// atribuicao (arm2, log em docs/evidence/oraculo-nativo-22/passo1c_arm2_probe.err):
	// pedir a engine que construa "AfMindOracle" de dentro do `create_instance_func` de
	// "AfMindOracle" faz a engine chamar este mesmo funcionario outra vez, e o processo
	// morria no instantiate (exit 127) sem nenhuma linha do probe depois de
	// `p4_class_exists`. O doc de
	// `classdb_construct_object3` admite "an already-registered extension class" sem
	// dizer que esse caminho reentrancia -- entao a palavra aqui e a corrida, nao o
	// comentario do header.
	GDExtensionObjectPtr obj = construct_object3(parent_name_sn());
	if (obj == nullptr) {
		return nullptr;
	}
	AfMindOracleInstance *inst = new AfMindOracleInstance{ 0x41464D31u };
	set_instance(obj, class_name_sn(), inst);
	// `NOTIFICATION_POSTINITIALIZE` nao e despachado, e isso vai escrito em vez de escondido:
	// a classe nao sobrescreve notificacao, nao tem script herdando dela e nao tem metodo
	// nenhum -- nao ha o que avisar. Quando houver corpo, o despacho passa a ser obrigatorio.
	(void)p_notify_postinitialize;
	return obj;
}

void free_instance(void *p_class_userdata, GDExtensionClassInstancePtr p_instance) {
	(void)p_class_userdata;
	delete static_cast<AfMindOracleInstance *>(p_instance);
}

void initialize_cb(void *p_userdata, GDExtensionInitializationLevel p_level) {
	(void)p_userdata;
	if (p_level != GDEXTENSION_INITIALIZATION_CORE || class_registered) {
		return;
	}
	GDExtensionClassCreationInfo6 info = {};
	info.is_exposed = 1;
	info.is_runtime = 1;
	info.create_instance_func = &create_instance;
	info.free_instance_func = &free_instance;
	register_extension_class6(library, class_name_sn(), parent_name_sn(), &info);
	class_registered = true;
}

void deinitialize_cb(void *p_userdata, GDExtensionInitializationLevel p_level) {
	(void)p_userdata;
	if (p_level == GDEXTENSION_INITIALIZATION_CORE && class_registered) {
		unregister_extension_class(library, class_name_sn());
		class_registered = false;
	}
}

template <typename T>
T load_proc(GDExtensionInterfaceGetProcAddress p_get_proc_address, const char *p_name) {
	return reinterpret_cast<T>(p_get_proc_address(p_name));
}

// `print_error` e a unica saida desta extensao no Passo 1: um `printf` no stderr do
// processo ia para o lugar errado quando a engine roda dentro do editor.
void refuse(const char *p_message, const char *p_function) {
	if (print_error_fn != nullptr) {
		print_error_fn(p_message, p_function, __FILE__, __LINE__, 0);
	}
}

} // namespace

// O nome tem de bater com `entry_symbol` do `af_mind.gdextension`: e assim que a engine
// acha o ponto de entrada. O `#if` existe porque exportar simbolo e do PE, nao do C++.
#if defined(_WIN32)
#define AF_MIND_EXPORT extern "C" __declspec(dllexport)
#else
#define AF_MIND_EXPORT extern "C"
#endif

AF_MIND_EXPORT GDExtensionBool af_mind_entry(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	library = p_library;

	print_error_fn = load_proc<GDExtensionInterfacePrintError>(p_get_proc_address, "print_error");
	string_name_new = load_proc<GDExtensionInterfaceStringNameNewWithLatin1Chars>(p_get_proc_address, "string_name_new_with_latin1_chars");
	register_extension_class6 = load_proc<GDExtensionInterfaceClassdbRegisterExtensionClass6>(p_get_proc_address, "classdb_register_extension_class6");
	unregister_extension_class = load_proc<GDExtensionInterfaceClassdbUnregisterExtensionClass>(p_get_proc_address, "classdb_unregister_extension_class");
	construct_object3 = load_proc<GDExtensionInterfaceClassdbConstructObject3>(p_get_proc_address, "classdb_construct_object3");
	set_instance = load_proc<GDExtensionInterfaceObjectSetInstance>(p_get_proc_address, "object_set_instance");
	get_godot_version2 = load_proc<GDExtensionInterfaceGetGodotVersion2>(p_get_proc_address, "get_godot_version2");

	// S12.2: a versao da interface nao e um `#define` do cabecalho -- e o que a engine devolve
	// em runtime. Estes nomes so existem a partir da 4.7, entao a ausencia de qualquer um
	// deles e a prova de que esta engine nao e a que o `build.bat` conferiu, e a extensao
	// recusa carregar em vez de chamar ponteiro nulo.
	if (string_name_new == nullptr || register_extension_class6 == nullptr ||
			unregister_extension_class == nullptr || construct_object3 == nullptr || set_instance == nullptr) {
		refuse("af_mind: a engine nao e a ABI 4.7.2 cuja interface esta em include/", "af_mind_entry");
		return 0;
	}

	if (get_godot_version2 != nullptr) {
		GDExtensionGodotVersion2 v = {};
		get_godot_version2(&v);
		if (v.major != 4 || v.minor < 7) {
			refuse("af_mind: get_godot_version2 devolve uma engine menor que 4.7", "af_mind_entry");
			return 0;
		}
	}

	// `p_is_static = 1` porque as literais vivem o quanto o processo viver -- a condicao que
	// o proprio doc da funcao exige de quem a usa.
	string_name_new(sn_class_storage, CLASS_NAME, 1);
	string_name_new(sn_parent_storage, PARENT_NAME, 1);

	r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_CORE;
	r_initialization->userdata = p_library;
	r_initialization->initialize = &initialize_cb;
	r_initialization->deinitialize = &deinitialize_cb;

	return 1;
}
