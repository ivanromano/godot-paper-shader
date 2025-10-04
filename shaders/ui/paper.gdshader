shader_type canvas_item;
global uniform vec4 paper_color;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.10);
uniform float shadow_width : hint_range(0.001, 0.05) = 0.02;
uniform float shadow_blur : hint_range(0.0, 0.02) = 0.008;

uniform vec2 center = vec2(0.5, 0.5);
uniform vec2 size = vec2(0.4, 0.3);

uniform float noise_scale : hint_range(1.0, 15.0) = 12.0;
uniform float edge_strength_x : hint_range(0.0, 0.05) = 0.08;
uniform float edge_strength_y : hint_range(0.0, 0.05) = 0.08;
uniform float smoothness : hint_range(0.0, 0.02) = 0.005;

// Parámetros del subborde interior
global uniform vec4 sub_color;

uniform float sub_width : hint_range(0.001, 0.02) = 0.03; // grosor del subborde en unidades UV
uniform float sub_noise_scale : hint_range(1.0, 200.0) = 40.0; // escala de ruido del subborde
uniform float sub_strength : hint_range(0.0, 2.0) = 1.0; // fuerza del subborde (mezcla)
// Fuerza de irregularidad del subborde por eje
uniform float sub_edge_strength_x : hint_range(0.0, 0.1) = 0.04;
uniform float sub_edge_strength_y : hint_range(0.0, 0.1) = 0.04;

// Semilla para variar el ruido
uniform float seed : hint_range(0.0, 1000.0) = 0.0;

// --- funciones de ruido mejoradas ---
float rand(vec2 co) {
    return fract(sin(dot(co + vec2(seed, seed * 1.618), vec2(12.9898, 78.233))) * 43758.5453);
}

float smooth_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    // Suavizado cúbico mejorado
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 uv) {
    float val = 0.0;
    float amp = 0.5;
    float freq = 1.0;

    for (int i = 0; i < 5; i++) {
        val += amp * smooth_noise(uv * freq);
        freq *= 2.0;
        amp *= 0.5;
    }

    return val;
}

// Función de ruido direccional mejorada para bordes
vec2 directional_noise(vec2 uv, float strength_x, float strength_y, float scale) {
    // Usar coordenadas diferentes para cada eje para evitar correlaciones
    vec2 noise_uv_x = (uv + vec2(seed * 0.7, seed * 1.3)) * scale;
    vec2 noise_uv_y = (uv + vec2(seed * 1.9, seed * 0.4)) * scale;

    // Aplicar FBM con offsets diferentes
    float noise_x = fbm(noise_uv_x) * 2.0 - 1.0; // Convertir a rango [-1, 1]
    float noise_y = fbm(noise_uv_y) * 2.0 - 1.0;

    return vec2(noise_x * strength_x, noise_y * strength_y);
}

// Distancia rectangular por componentes (devuelve dx, dy)
vec2 rect_distance_components(vec2 uv, vec2 cen, vec2 half_size) {
    vec2 d = abs(uv - cen) - half_size;
    return d;
}

// Función de suavizado mejorada
float smooth_edge(float dist, float _smoothness) {
    // Usar una función de suavizado más suave
    return 1.0 - smoothstep(-_smoothness * 2.0, _smoothness * 2.0, dist);
}

void fragment() {
    // medio tamaño
    vec2 half_size = size * 0.5;

    // --- PAPEL PRINCIPAL ---
    // distancias por componente (dx, dy): negativas dentro, 0 en borde, positivas fuera
    vec2 comp = rect_distance_components(UV, center, half_size);
    float dx = comp.x;
    float dy = comp.y;

    // Ruido direccional mejorado para el borde principal
    vec2 main_noise = directional_noise(UV, edge_strength_x, edge_strength_y, noise_scale);

    // Aplicar el ruido de manera más suave
    dx += main_noise.x;
    dy += main_noise.y;

    // distancia rectangular combinada (max de componentes)
    float dist = max(dx, dy);

    // máscara del papel: 1 dentro del papel, 0 fuera
    float paper_mask = smooth_edge(dist, smoothness);

    // --- SOMBRA ALREDEDOR DEL PAPEL ---
    // Para la sombra, usamos una distancia ligeramente expandida
    float shadow_dist = max(dx - shadow_width, dy - shadow_width);
    // Máscara de sombra que solo aparece fuera del papel pero cerca del borde
    float shadow_mask = (1.0 - paper_mask) * smooth_edge(shadow_dist, shadow_blur);

    // --- SUBBORDE INTERIOR ---
    // Ruido direccional para el subborde (con escala diferente)
    vec2 sub_noise = directional_noise(UV, sub_edge_strength_x, sub_edge_strength_y, sub_noise_scale);

    // Distancia para el subborde con su propio ruido
    float sub_dist = max(dx + sub_noise.x, dy + sub_noise.y);

    // Máscara del subborde con transición suave
    float sub_mask = smooth_edge(sub_dist + sub_width, smoothness * 2.0) * paper_mask;

    // Ajustar la intensidad del subborde
    float sub_mix = sub_mask * sub_strength;

    // --- COMPOSITE FINAL ---
    // Aplicar el subborde interior al color del papel
    vec3 paper_with_sub = mix(paper_color.rgb, sub_color.rgb, sub_mix);

    // Mezclar entre transparencia, sombra y papel
    vec4 final_color = vec4(0.0); // Transparente por defecto

    // Aplicar sombra alrededor del borde
    final_color = mix(final_color, shadow_color, shadow_mask);

    // Aplicar papel encima
    final_color = mix(final_color, vec4(paper_with_sub, paper_color.a), paper_mask);

    // Resultado final
    COLOR = final_color;
}