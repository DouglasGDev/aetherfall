// Sonda Fase 0 (re-medida): as DLLs pre-compiladas do llama.cpp no repositorio registram o backend
// Vulkan e quantos dispositivos Vulkan elas veem dentro de um processo comum, sem Godot e sem modelo.
// A correcao desta passada: reg_count / dev_count / load_all_from_path so existem em ggml.dll
// (16 exports); em ggml-base.dll nao ha nenhum deles, entao GetProcAddress devolvia NULL e a
// impressao anterior lia "0" por ponteiro ausente, nao por backend ausente.
#include <windows.h>
#include <stdio.h>

typedef void* ggml_backend_dev_t;
typedef void* ggml_backend_reg_t;

static const char* GGML = "C:\\Aetherfall\\.tools\\llama\\runtime\\ggml.dll";
static const char* BASE = "C:\\Aetherfall\\.tools\\llama\\runtime\\ggml-base.dll";
static const char* VKN  = "C:\\Aetherfall\\.tools\\llama\\runtime\\ggml-vulkan.dll";
static const char* LLM  = "C:\\Aetherfall\\.tools\\llama\\runtime\\llama.dll";
static const char* RT   = "C:\\Aetherfall\\.tools\\llama\\runtime\\";

typedef size_t (*fn_load_all_from_path_t)(const char*);
typedef size_t (*fn_dev_count_t)(void);
typedef ggml_backend_dev_t (*fn_dev_get_t)(size_t);
typedef const char* (*fn_dev_name_t)(ggml_backend_dev_t);
typedef const char* (*fn_dev_desc_t)(ggml_backend_dev_t);
typedef int (*fn_dev_type_t)(ggml_backend_dev_t);
typedef size_t (*fn_reg_count_t)(void);
typedef ggml_backend_reg_t (*fn_reg_get_t)(size_t);
typedef const char* (*fn_reg_name_t)(ggml_backend_reg_t);
typedef int (*fn_vk_dev_count_t)(void);
typedef void (*fn_print_system_info_t)(void);

static HMODULE ggml, base, vkn, llm;

static void* addr(HMODULE m, const char* name) {
    void* p = (void*)GetProcAddress(m, name);
    printf("  GetProcAddress(%s) de %.24s: %s\n", name,
           m == ggml ? "ggml.dll" : m == base ? "ggml-base.dll" : "?", p ? "ACHOU" : "NAO");
    return p;
}

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    base = LoadLibraryExA(BASE, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    ggml = LoadLibraryExA(GGML, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    vkn  = LoadLibraryExA(VKN,  NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    llm  = LoadLibraryExA(LLM,  NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    printf("LoadLibrary: ggml-base=%s ggml=%s ggml-vulkan=%s llama=%s\n",
           base ? "OK" : "FALHOU", ggml ? "OK" : "FALHOU",
           vkn ? "OK" : "FALHOU", llm ? "OK" : "FALHOU");
    if (!ggml || !base) { printf("SONDA=FALHOU\n"); return 2; }

    // onde cada simbolo vive, medido nao assumido
    void* p_load_all = addr(ggml, "ggml_backend_load_all_from_path");
    void* p_reg_cnt  = addr(ggml, "ggml_backend_reg_count");
    void* p_dev_cnt  = addr(ggml, "ggml_backend_dev_count");
    addr(base, "ggml_backend_load_all_from_path");
    addr(base, "ggml_backend_reg_count");
    addr(base, "ggml_backend_dev_count");

    fn_load_all_from_path_t load_all_from_path = (fn_load_all_from_path_t)p_load_all;
    fn_reg_count_t  reg_count  = (fn_reg_count_t)p_reg_cnt;
    fn_dev_count_t  dev_count  = (fn_dev_count_t)p_dev_cnt;
    fn_reg_get_t    reg_get    = (fn_reg_get_t)GetProcAddress(ggml, "ggml_backend_reg_get");
    fn_reg_name_t   reg_name   = (fn_reg_name_t)GetProcAddress(ggml, "ggml_backend_reg_name");
    fn_dev_get_t    dev_get    = (fn_dev_get_t)GetProcAddress(ggml, "ggml_backend_dev_get");
    fn_dev_name_t   dev_name   = (fn_dev_name_t)GetProcAddress(ggml, "ggml_backend_dev_name");
    fn_dev_desc_t   dev_desc   = (fn_dev_desc_t)GetProcAddress(ggml, "ggml_backend_dev_description");
    fn_dev_type_t   dev_type   = (fn_dev_type_t)GetProcAddress(ggml, "ggml_backend_dev_type");

    size_t n = load_all_from_path ? load_all_from_path(RT) : 0;
    printf("ggml_backend_load_all_from_path(runtime): %zu\n", n);

    size_t r = reg_count ? reg_count() : 0;
    printf("ggml_backend_reg_count(): %zu\n", r);
    for (size_t i = 0; i < r; i++)
        printf("  reg[%zu] %s\n", i, reg_name && reg_get ? reg_name(reg_get(i)) : "?");

    size_t d = dev_count ? dev_count() : 0;
    printf("ggml_backend_dev_count(): %zu\n", d);
    for (size_t i = 0; i < d; i++) {
        ggml_backend_dev_t dev = dev_get ? dev_get(i) : NULL;
        printf("  dev[%zu] type=%d nome=%s\n", i, dev_type && dev ? dev_type(dev) : -999,
               dev_name && dev ? dev_name(dev) : "?");
        if (dev_desc && dev) printf("           desc=%.140s\n", dev_desc(dev));
    }

    fn_vk_dev_count_t vk_count =
        vkn ? (fn_vk_dev_count_t)GetProcAddress(vkn, "ggml_backend_vk_get_device_count") : NULL;
    printf("ggml_backend_vk_get_device_count(): %d\n", vk_count ? vk_count() : -999);

    fn_print_system_info_t psi =
        llm ? (fn_print_system_info_t)GetProcAddress(llm, "llama_print_system_info") : NULL;
    printf("llama_print_system_info exportada: %s\n", psi ? "sim" : "nao");
    if (psi) psi();

    printf("SONDA=OK\n");
    return 0;
}
