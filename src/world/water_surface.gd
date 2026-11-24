class_name WaterSurface
## O material da superficie da agua (dossie 23 §3.1): GLSL como constante de GDScript
## e `ShaderMaterial` montado em runtime — nenhum recurso importado, porque a familia
## de artefatos de import que este repositorio nao controla e o furo #25.
##
## O que o shader sabe de fora vem de dois lugares: tres canais por vertice escritos
## pela malharia no `COLOR` (§3.3 — `R` mascara de onda, `G` profundidade da coluna em
## quartos, `B` face vertical) e a direcao do sol, que e do `main.gd`, nao daqui (§2:
## hoje o sol e uma constante, entao "caustica quando o sol esta alto" e constante por
## enquanto — quando a Fase 4 mover o sol, a agua acompanha sem linha nova).

## Os valores gravados no material vivem numa so lista, e `params()` e o unico lugar
## que a monta: a checagem `material_da_agua_e_shader` confere estes nomes contra os
## declarados na SOURCE, porque um nome escrito sem declaracao correspondente e um
## no-op silencioso — e headless nao compila shader nenhum para avisar.
const TUNING: Dictionary = {
	# O tile de agua do atlas continua desenhando o granulado; o shader so
	# acrescenta o que 16 px nao podem saber (a cena atras, a coluna, o sol).
	# Por isso `shallow`/`deep` vao com `source_color`: os numeros abaixo sao de
	# tela (sRGB). O atlas NAO vai, porque `voxel_atlas.gd:36` devolve a imagem
	# ja em linear.
	"shallow_color": Color(0.34, 0.62, 0.63),
	"deep_color": Color(0.02, 0.11, 0.24),
	# 0,11 x a soma das tres harmonicas (0,433 no pior ponto) = 4,8 cm de
	# deslocamento sobre uma celula de 1 m: ondula, nao vira mar.
	"wave_amp": 0.11,
	# 1,6 x as frequencias base (~1 rad/m) da cerca de 4 blocos de comprimento
	# de onda: abaixo disso a onda de 4 cantos por celula lee como rampa plana.
	"wave_freq": 1.6,
	"wave_speed": 1.15,
	# 0,02 e o vidroso da agua no ar (Schlick); nada aqui e ajuste de gosto sem
	# numero: o que cada um faz esta escrito na SOURCE, ao lado da declaracao.
	"fresnel_bias": 0.02,
	"refract_strength": 0.055,
	"reflect_strength": 0.55,
	"foam_width": 0.60,
	"absorb_per_block": 0.30,
	"caustic_gain": 0.35,
	"caustic_freq": 0.55,
}

const SOURCE: String = """shader_type spatial;
// blend_mix + escreve ALPHA = passe transparente, igual ao StandardMaterial3D que
// esta perna substitui; cull_disabled preserva o que o mesher ja decidia para LIQUID
// (ele emite a face contra AIR nos dois lados, inclusive a de baixo).
render_mode blend_mix, cull_disabled, specular_schlick_ggx;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 shallow_color : source_color = vec4(0.34, 0.62, 0.63, 1.0);
uniform vec4 deep_color : source_color = vec4(0.02, 0.11, 0.24, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float wave_amp = 0.11;
uniform float wave_freq = 1.6;
uniform float wave_speed = 1.15;
uniform float fresnel_bias = 0.02;
uniform float refract_strength = 0.055;
uniform float reflect_strength = 0.55;
uniform float foam_width = 0.60;
uniform float absorb_per_block = 0.30;
uniform float caustic_gain = 0.35;
uniform float caustic_freq = 0.55;

// k1 corre em +X, k2 em +Z, k3 na diagonal. A terceira existe porque a soma das
// duas primeiras e listras paralelas: com um quad de 4 cantos por celula, listra
// paralela vira rampa.
const vec2 K1 = vec2(1.10, 0.00);
const vec2 K2 = vec2(0.00, 0.85);
const vec2 K3 = vec2(0.70, 0.70);

// h com as duas derivadas espaciais na mesma passada. O NORMAL vem do closed form,
// nao de diferenca finita, porque o custo e identico e a regularidade nao pode
// depender do tamanho do triangulo (§3.2).
vec3 wave(vec2 f, float t) {
	float a1 = dot(K1, f) * wave_freq + t;
	float a2 = dot(K2, f) * wave_freq - 1.3 * t;
	float a3 = dot(K3, f) * wave_freq + 1.7 * t;
	float s = 0.3333333;
	float h = (0.55 * sin(a1) + 0.45 * sin(a2) + 0.30 * sin(a3)) * s;
	float dx = (0.55 * K1.x * cos(a1) + 0.30 * K3.x * cos(a3)) * s * wave_freq;
	float dy = (0.45 * K2.y * cos(a2) + 0.30 * K3.y * cos(a3)) * s * wave_freq;
	return vec3(h, dx, dy);
}

// Distancia ao longo do -Z da camera para o pixel uv. O depth nao e linear; o
// trecho e o documentado (screen-reading): INV_PROJECTION_MATRIX sobre (uv*2-1, d).
// A matriz entra por parametro porque os embutidos do shader so existem dentro de
// vertex() e fragment(): lida dentro de uma funcao propria, o parser responde
// "Unknown identifier" — medido no log da suíte, nao em documentacao.
float depth_at(vec2 uv, mat4 inv_proj) {
	float d = textureLod(depth_tex, uv, 0.0).r;
	vec4 upos = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -(upos.xyz / upos.w).z;
}

// Duas ondas que se cruzam, elevadas ao cubo: o cubo afina o feixe, sem ele a
// caustica e uma listra larga.
float caustic(vec2 q, float t) {
	float a = sin(q.x + t) + sin(q.y * 1.13 - t * 1.21);
	float b = sin((q.x + q.y) * 0.91 + t * 0.73) + sin((q.x - q.y) * 1.07 - t * 0.97);
	return pow(clamp((a + b) * 0.25 + 0.5, 0.0, 1.0), 3.0);
}

void vertex() {
	// So os vertices do plano de topo de um bloco sem agua em cima se movem, e o
	// deslocamento e funcao exclusiva do XZ de mundo: dois quads que dividem o
	// mesmo canto dividem o mesmo numero, entao nao existe costura por construcao
	// (§3.2). O mesher nao roda transform em nenhum chunk, mas a conta e feita em
	// mundo para nao depender dessa ausencia.
	//
	// Nao ha saida antecipada: `return` em processor e rejeitado pelo parser
	// ("Using 'return' in the 'vertex' processor function is incorrect"), medido no
	// log da suíte. Por isso o corpo inteiro mora dentro do teste da mascara.
	if (COLOR.r > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 w = wave(wp.xz, TIME * wave_speed);
		VERTEX.y += COLOR.r * wave_amp * w.x;
		if (COLOR.b <= 0.0) {
			// Plano de topo: normal reconstruida. Na lateral (B = 1) a superficie e um
			// muro e a normal geometrica da face ja e a resposta certa.
			NORMAL = normalize(vec3(-wave_amp * w.y, 1.0, -wave_amp * w.z));
		}
	}
}

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	vec4 tile = texture(atlas, UV);
	// O tile modula o desenho, nao o tom: dividir pela luminancia propria mantem a
	// granulado do atlas sem escurecer duas vezes o que `shallow`/`deep` ja pintam.
	float med = max(dot(tile.rgb, vec3(0.3333333)), 0.05);
	vec3 grana = tile.rgb / med;
	float wall = COLOR.b;
	// G veio em quartos de bloco: 4 blocos ou mais e o teto da coluna (§3.3).
	float col_blocks = COLOR.g * 4.0;

	// Schlick com f0 = fresnel_bias.
	float ndv = max(dot(N, V), 0.0);
	float fres = fresnel_bias + (1.0 - fresnel_bias) * pow(1.0 - ndv, 5.0);

	// Espessura lida da cena (o leito ja passou pelo passe opaco) com a coluna
	// geometrica ao lado: onde o depth nao alcanca, G segura a cor (§3.5).
	float atras = depth_at(SCREEN_UV, INV_PROJECTION_MATRIX);
	float esp = max(atras + VERTEX.z, 0.0);
	float blocos = max(esp, col_blocks);
	float body = clamp(1.0 - exp(-absorb_per_block * blocos), 0.0, 1.0);
	vec3 corpo = mix(shallow_color.rgb, deep_color.rgb, body) * grana;

	// Refracao: uma amostra da tela deslocada pela normal em perspectiva.
	vec2 refr_uv = clamp(SCREEN_UV + N.xy * refract_strength * (1.0 - fres),
		vec2(0.002), vec2(0.998));
	vec3 atras_cena = textureLod(screen_tex, refr_uv, 0.0).rgb * corpo;
	// A parede nao ve o leito atras de si: ve o proprio corpo.
	vec3 refratado = mix(atras_cena, corpo, wall);

	// Reflexao: um passo ao longo do raio espelhado a partir do fragmento, com a
	// distancia dele como estimativa do ponto virtual. Amostra unica, nao o SSR do
	// engine (§3.4) — e e isso que o braço rejeitado da pagina registra.
	vec3 R = reflect(-V, N);
	float rd = max(-VERTEX.z, 0.75);
	vec4 clip = PROJECTION_MATRIX * vec4(VERTEX + R * rd, 1.0);
	vec3 refletido = corpo;
	if (clip.w > 0.001) {
		vec2 ruv = clip.xy / clip.w * 0.5 + 0.5;
		if (ruv.x > 0.0 && ruv.x < 1.0 && ruv.y > 0.0 && ruv.y < 1.0) {
			refletido = textureLod(screen_tex, ruv, 0.0).rgb * grana;
		}
	}
	vec3 base = mix(refratado, refletido, clamp(fres * reflect_strength, 0.0, 1.0));

	// Espuma de margem: lenol fino atras deste pixel. Na lateral, a espuma e a
	// linha d'agua -- o mask interpolado do topo para a base do quad marca
	// justamente a altura em que o corpo entrou. Sem o canal B ela subiria pela
	// cachoeira inteira (§3.3).
	float margem = 1.0 - smoothstep(0.0, max(foam_width, 0.05), esp);
	float linha = wall * smoothstep(0.55, 0.98, COLOR.r);
	float foam = clamp(max(margem * (1.0 - wall * 0.85), linha * 0.7), 0.0, 1.0);
	base = mix(base, vec3(0.92, 0.96, 0.98) * grana, foam);

	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sol_alto = smoothstep(0.20, 0.55, sun_dir.y);
	float cac = caustic(wpos.xz * caustic_freq, TIME * 0.9) * sol_alto * caustic_gain;

	ALBEDO = base;
	ROUGHNESS = mix(0.06, 0.55, foam);
	SPECULAR = mix(0.5, 0.25, foam);
	// A caustica e luz somada no corpo, nao albedo: ela so aparece onde ha plano de
	// topo (a parede nao ve o fundo do lago).
	EMISSION = corpo * cac * (1.0 - wall) + vec3(0.03, 0.05, 0.06) * foam;
	ALPHA = clamp(mix(tile.a + foam * 0.35, 0.98, fres * reflect_strength), 0.0, 1.0);
}
"""


## O dicionario que da origem aos nomes gravados e aos valores. `atlas` aceita `null`
## justamente para a suíte poder ler a lista de nomes sem ter um contexto de render.
static func params(atlas: Texture2D, sun_dir: Vector3) -> Dictionary:
	var p: Dictionary = TUNING.duplicate()
	p["atlas"] = atlas
	p["sun_dir"] = sun_dir
	return p


static func written_uniforms() -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in TUNING:
		out.append(k)
	out.append("atlas")
	out.append("sun_dir")
	return out


## O outro lado da testemunha: os nomes que a SOURCE declara. Parseia a constante em
## vez de repetir a lista, senao a checagem conferiria um numero contra ele mesmo.
static func declared_uniforms() -> PackedStringArray:
	var re := RegEx.new()
	re.compile("^uniform\\s+\\w+\\s+(\\w+)\\s*[:=]")
	var out := PackedStringArray()
	for line: String in SOURCE.split("\n"):
		var m := re.search(line.strip_edges())
		if m != null:
			out.append(m.get_string(1))
	return out


static func build_material(atlas: Texture2D, sun_dir: Vector3) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SOURCE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var p := params(atlas, sun_dir)
	for k: String in p:
		mat.set_shader_parameter(k, p[k])
	return mat
