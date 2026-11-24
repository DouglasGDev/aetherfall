// Sonda Fase 0 (terceira leitura): a enumeracao do registro mora em ggml.dll (shim de 16 exports)
// e os acessores que descrevem reg e dev moram em ggml-base.dll (689 exports). Um binding que
// resolve do modulo errado recebe NULL em silencio — foi assim que a primeira leitura imprimiu
// "0 backends". Aqui cada ponteiro vem do modulo onde o simbolo realmente existe.
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
typedef size_t (*fn_reg_count_t)(void);
typedef ggml_backend_reg_t (*fn_reg_get_t)(size_t);
typedef const char* (*fn_reg_name_t)(ggml_backend_reg_t);
typedef size_t (*fn_dev_count_t)(void);
typedef ggml_backend_dev_t (*fn_dev_get_t)(size_t);
typedef const char* (*fn_dev_name_t)(ggml_backend_dev_t);
typedef const char* (*fn_dev_desc_t)(ggml_backend_dev_t);
typedef int (*fn_dev_type_t)(ggml_backend_dev_t);
typedef int (*fn_vk_dev_count_t)(void);

static HMODULE ggml, base, vkn, llm;

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    base = LoadLibraryExA(BASE, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    ggml = LoadLibraryExA(GGML, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    vkn  = LoadLibraryExA(VKN,  NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    llm  = LoadLibraryExA(LLM,  NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    printf("LoadLibrary: ggml-base=%s ggml=%s ggml-vulkan=%s llama=%s\n",
           base ? "OK" : "FALHOU", ggml ? "OK" : "FALHOU",
           vkn ? "OK" : "FALHOU", llm ? "OK" : "FALHOU");
    if (!ggml || !base || !vkn || !llm) { printf("SONDA=FALHOU\n"); return 2; }

    // enumeracao: ggml.dll
    fn_load_all_from_path_t load_all = (fn_load_all_from_path_t)GetProcAddress(ggml, "ggml_backend_load_all_from_path");
    fn_reg_count_t  reg_count  = (fn_reg_count_t)  GetProcAddress(ggml, "ggml_backend_reg_count");
    fn_reg_get_t    reg_get    = (fn_reg_get_t)    GetProcAddress(ggml, "ggml_backend_reg_get");
    fn_dev_count_t  dev_count  = (fn_dev_count_t)  GetProcAddress(ggml, "ggml_backend_dev_count");
    fn_dev_get_t    dev_get    = (fn_dev_get_t)    GetProcAddress(ggml, "ggml_backend_dev_get");
    // descricao: ggml-base.dll
    fn_reg_name_t   reg_name   = (fn_reg_name_t)   GetProcAddress(base, "ggml_backend_reg_name");
    fn_dev_name_t   dev_name   = (fn_dev_name_t)   GetProcAddress(base, "ggml_backend_dev_name");
    fn_dev_desc_t   dev_desc   = (fn_dev_desc_t)   GetProcAddress(base, "ggml_backend_dev_description");
    fn_dev_type_t   dev_type   = (fn_dev_type_t)   GetProcAddress(base, "ggml_backend_dev_type");

    printf("ponteiros (ggml): load_all=%p reg_count=%p reg_get=%p dev_count=%p dev_get=%p\n",
           (void*)load_all, (void*)reg_count, (void*)reg_get, (void*)dev_count, (void*)dev_get);
    printf("ponteiros (base): reg_name=%p dev_name=%p dev_desc=%p dev_type=%p\n",
           (void*)reg_name, (void*)dev_name, (void*)dev_desc, (void*)dev_type);
    if (!load_all || !reg_count || !reg_get || !dev_count || !dev_get) { printf("SONDA=FALHOU\n"); return 3; }

    size_t n = load_all(RT);
    printf("ggml_backend_load_all_from_path(runtime) devolve: %zu (ve o rodape do stderr; nao e contagem de backends)\n", n);

    size_t r = reg_count();
    printf("ggml_backend_reg_count(): %zu\n", r);
    for (size_t i = 0; i < r; i++) {
        ggml_backend_reg_t rg = reg_get(i);
        printf("  reg[%zu] %s\n", i, rg && reg_name ? reg_name(rg) : "(null)");
    }

    size_t d = dev_count();
    printf("ggml_backend_dev_count(): %zu\n", d);
    for (size_t i = 0; i < d; i++) {
        ggml_backend_dev_t dv = dev_get(i);
        printf("  dev[%zu] type=%d nome=%s\n", i, dv && dev_type ? dev_type(dv) : -999,
               dv && dev_name ? dev_name(dv) : "(null)");
        if (dv && dev_desc) printf("           desc=%.160s\n", dev_desc(dv));
    }

    fn_vk_dev_count_t vk_count =
        (fn_vk_dev_count_t)GetProcAddress(vkn, "ggml_backend_vk_get_device_count");
    printf("ggml_backend_vk_get_device_count(): %d\n", vk_count ? vk_count() : -999);

    printf("SONDA=OK\n");
    return 0;
}
