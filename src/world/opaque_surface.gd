class_name OpaqueSurface
## O material da superficie opaca do mundo (dossie 23 §3.10c): GLSL como constante de
## GDScript e `ShaderMaterial` montado em runtime, espelhando `water_surface.gd` peca por
## peca — inclusive o par `written_uniforms()` / `declared_uniforms()`, que e o que
## impede um uniforme gravado sem declaracao virar no-op silencioso (headless nao compila
## shader nenhum para avisar).
##
## A metade de baixo e **fidelidade**, nao efeito: o que o `StandardMaterial3D` de
## `voxel_world.gd` fazia antes — tile em `NEAREST_WITH_MIPMAPS`, `COLOR.rgb` multiplicando
## o albedo, `ROUGHNESS = 0,92`, `METALLIC = 0`, passe opaco, sombras da
## `DirectionalLight3D` recebidas pelo proprio engine — tem de continuar acontecendo com o
## shader ligado. O braco `--weather=0` da sonda §5.4 e quem mede isso no pixel; aqui em
## headless o que mede e o `COLOR.rgb` nao se mover (§5.3) e o par de nomes abaixo.
##
## Sobre a fidelidade a fase acrescenta uma coisa so: `molhado × COLOR.a`, o canal de
## exposicao de cielo que a malharia passou a escrever no alfa do grupo opaco (§3.10b). O
## produto e zero no fundo da ravina e 1 no topo do morro, e e por isso que o beiral escurece
## e o leito nao — a unica propriedade pedida, e a que o braco (c) do §3.10b perderia.

## Os valores gravados no material vivem numa so lista, e `params()` e o unico lugar que a
## monta. `molhado` entra nascendo 0 (o vale comeca seco) e passa a ser reescrito pelo sink
## do `Weather` — o mesmo nome nos dois lados, porque um uniforme que so existe no `set` do
## runtime e um no-op com cara de efeito.
const TUNING: Dictionary = {
	# Fator multiplicativo sobre o albedo, **nao** cor de tela: por isso nao vai
	# `source_color`. O atlas ja chega linear (`voxel_atlas.gd:35` `srgb_to_linear()`),
	# e um numero convertido de sRGB para multiplicar escureceria duas vezes o que o
	# proprio molhamento escurece. 0,62 no vermelho e o pedra encharcada; o salto para
	# 0,72 no azul e o ceu que a lamina de agua passa a refletir no lugar do proprio
	# pigmento — o desvio para o azul e o que faz a pedra molhada nao ser a pedra com o
	# brilho baixo.
	"wet_tint": Color(0.62, 0.66, 0.72),
	# O `roughness` do `StandardMaterial3D` que este material substitui
	# (`voxel_world.gd:95`), copiado como default para a ausencia de fiação ser o shader
	# seco desenhando o material velho, e nao outro numero.
	"dry_roughness": 0.92,
	# Rugosidade de lamina de agua sobre rocha. O teto e a legibilidade voxel do prompt:
	# abaixo de ~0,3 o grana de 16 px do atlas com mip linear vira borrado e o bloco para
	# de ler como bloco. O chao e a agua desta perna (`0,06` no plano de topo molhado de
	# espuma), e o valor fica no meio do caminho entre os dois numeros que ja existem no
	# projeto, nao num gosto.
	"wet_roughness": 0.30,
	"molhado": 0.0,
}

const SOURCE: String = """shader_type spatial;
// `diffuse_burley` + `specular_schlick_ggx` sao os defaults do `StandardMaterial3D` que
// este material substitui, medidos e nao lembrados (`.tools/probe_defaults.gd`:
// `diffuse_mode=0`=BURLEY, `specular_mode=0`=SCHLICK_GGX). Escrever as duas explicitas e
// o que impede a reproducao de virar outro tom se o default do engine mudar de endereco.
// A primeira versao desta linha dizia `specular_schlick_blurry`, que e de Godot 3 e NAO
// existe no 4.7: o front-end recusou com `SHADER ERROR: Invalid render mode` (o eixo do
// furo #50). Nenhum outro `render_mode`: o passe continua opaco (sem `blend_*`, sem
// `ALPHA`) e o `cull_back` e o do material velho.
render_mode diffuse_burley, specular_schlick_ggx;

// NEAREST_WITH_MIPMAPS e o filtro do material velho (`eb218fe:src/world/voxel_world.gd:94`,
// a arvore da base), e e o que mantem o tile de 16 px em quadros: linear no atlas faria a
// parede de pedra virar massa. Sem `source_color` na amostra — o `voxel_atlas.gd:35` devolve
// a imagem ja em linear, e o `hint_albedo` acrescentaria a conversao de novo.
uniform sampler2D atlas : filter_nearest_mipmap, repeat_disable;
uniform vec4 wet_tint = vec4(0.62, 0.66, 0.72, 1.0);
uniform float dry_roughness = 0.92;
uniform float wet_roughness = 0.30;
uniform float molhado = 0.0;

void fragment() {
	vec4 tile = texture(atlas, UV);
	// O produto e o que a fase compra com o quarto canal: `molhado` e do clima (um
	// numero por mundo) e `COLOR.a` e da coluna (um numero por vertice). Sem o canal
	// seria um filtro global, e o §3.10b rejeita esse braco pelo nome.
	float molhamento = clamp(molhado * COLOR.a, 0.0, 1.0);
	// O `COLOR.rgb` entra exatamente como entrava: R = G = B = `bright`, a aritmetica do
	// mesher intacta, e a assercao `rgb_iguais == verts` da §5.3 e quem vigia isso.
	ALBEDO = tile.rgb * COLOR.rgb * mix(vec3(1.0), wet_tint.rgb, molhamento);
	ROUGHNESS = mix(dry_roughness, wet_roughness, molhamento);
	METALLIC = 0.0;
}
"""


## O dicionario que da origem aos nomes gravados e aos valores. `atlas` aceita `null` para
## a suíte poder ler a lista de nomes sem ter um contexto de render.
static func params(atlas: Texture2D) -> Dictionary:
	var p: Dictionary = TUNING.duplicate()
	p["atlas"] = atlas
	return p


static func written_uniforms() -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in TUNING:
		out.append(k)
	out.append("atlas")
	return out


## O outro lado da testemunha: os nomes que a SOURCE declara. Parseia a constante em vez
## de repetir a lista, senao a checagem conferiria um numero contra ele mesmo.
static func declared_uniforms() -> PackedStringArray:
	var re := RegEx.new()
	re.compile("^uniform\\s+\\w+\\s+(\\w+)\\s*[:=]")
	var out := PackedStringArray()
	for line: String in SOURCE.split("\n"):
		var m := re.search(line.strip_edges())
		if m != null:
			out.append(m.get_string(1))
	return out


static func build_material(atlas: Texture2D) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SOURCE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var p := params(atlas)
	for k: String in p:
		mat.set_shader_parameter(k, p[k])
	return mat
