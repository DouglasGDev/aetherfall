// Sonda Fase 0: as DLLs pre-compiladas do llama.cpp no repositorio registram o backend Vulkan
// e quantos dispositivos Vulkan elas veem dentro de um processo comum, sem Godot e sem modelo.
// So ponteiros opacos e const char* trocam de modulo, nenhum tipo de STL cruza a fronteira.
#include <windows.h>
#include <stdio.h>

typedef void* ggml_backend_dev_t;
typedef void* ggml_backend_reg_t;

static const char* RT = "C:\\Aetherfall\\.tools\\llama\\runtime\\";

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
typedef const char* (*fn_vk_dev_desc_t)(int);
typedef void (*fn_print_system_info_t)(void);

static HMODULE load(const char* file) {
    char p[512];
    snprintf(p, sizeof(p), "%s%s", RT, file);
    HMODULE m = LoadLibraryExA(p, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    printf("LoadLibrary %s: %s (err=%lu)\n", file, m ? "OK" : "FALHOU", m ? 0UL : GetLastError());
    return m;
}

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    HMODULE base = load("ggml-base.dll");
    HMODULE ggml = load("ggml.dll");
    HMODULE vulkan = load("ggml-vulkan.dll");
    HMODULE llama = load("llama.dll");
    if (!base || !ggml) { printf("SONDA=FALHOU\n"); return 2; }

    fn_load_all_from_path_t load_all_from_path =
        (fn_load_all_from_path_t)GetProcAddress(ggml, "ggml_backend_load_all_from_path");
    if (!load_all_from_path)
        load_all_from_path = (fn_load_all_from_path_t)GetProcAddress(base, "ggml_backend_load_all_from_path");
    printf("ggml_backend_load_all_from_path exportada: %s\n", load_all_from_path ? "sim" : "nao");

    size_t n = load_all_from_path ? load_all_from_path(RT) : 0;
    printf("ggml_backend_load_all_from_path(): %zu backends registrados\n", n);

    fn_reg_count_t reg_count = (fn_reg_count_t)GetProcAddress(base, "ggml_backend_reg_count");
    fn_reg_get_t reg_get = (fn_reg_get_t)GetProcAddress(base, "ggml_backend_reg_get");
    fn_reg_name_t reg_name = (fn_reg_name_t)GetProcAddress(base, "ggml_backend_reg_name");
    size_t r = reg_count ? reg_count() : 0;
    printf("ggml_backend_reg_count(): %zu\n", r);

    fn_dev_count_t dev_count = (fn_dev_count_t)GetProcAddress(base, "ggml_backend_dev_count");
    fn_dev_get_t dev_get = (fn_dev_get_t)GetProcAddress(base, "ggml_backend_dev_get");
    fn_dev_name_t dev_name = (fn_dev_name_t)GetProcAddress(base, "ggml_backend_dev_name");
    fn_dev_desc_t dev_desc = (fn_dev_desc_t)GetProcAddress(base, "ggml_backend_dev_description");
    fn_dev_type_t dev_type = (fn_dev_type_t)GetProcAddress(base, "ggml_backend_dev_type");

    size_t d = dev_count ? dev_count() : 0;
    printf("ggml_backend_dev_count(): %zu\n", d);
    for (size_t i = 0; i < d; i++) {
        ggml_backend_dev_t dev = dev_get(i);
        printf("  dev[%zu] type=%d nome=%s\n", i, dev_type ? dev_type(dev) : -999, dev_name(dev));
        if (dev_desc) printf("           desc=%.120s\n", dev_desc(dev));
    }

    fn_vk_dev_count_t vk_count =
        vulkan ? (fn_vk_dev_count_t)GetProcAddress(vulkan, "ggml_backend_vk_get_device_count") : NULL;
    printf("ggml_backend_vk_get_device_count exportada: %s -> %d\n", vk_count ? "sim" : "nao",
           vk_count ? vk_count() : -999);
    fflush(stdout);

    fn_print_system_info_t psi = (fn_print_system_info_t)GetProcAddress(llama, "llama_print_system_info");
    printf("llama_print_system_info exportada: %s\n", psi ? "sim" : "nao");
    fflush(stdout);
    if (psi) psi();

    printf("SONDA=OK\n");
    return 0;
}
