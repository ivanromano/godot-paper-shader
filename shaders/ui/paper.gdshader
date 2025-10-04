shader_type canvas_item;

// Color del "papel" visible
uniform vec4 paper_color : source_color = vec4(1.0, 1.0, 0.9, 1.0);

// Color de fondo, por defecto transparente
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

// Centro y tamaño total del área (size es el ancho y alto completos en UV 0..1)
uniform vec2 center = vec2(0.5, 0.5);
uniform vec2 size = vec2(0.4, 0.3);

// Ruido y control del borde principal
uniform float noise_scale : hint_range(1.0, 200.0) = 12.0;
// Fuerza de la irregularidad por eje
uniform float edge_strength_x : hint_range(0.0, 0.5) = 0.08;
uniform float edge_strength_y : hint_range(0.0, 0.5) = 0.08;
uniform float smoothness : hint_range(0.0, 0.2) = 0.005;

// Parámetros del subborde interior
uniform vec4 sub_color : source_color = vec4(0.9, 0.85, 0.7, 1.0); // color del ribete interior
uniform float sub_width : hint_range(0.001, 0.2) = 0.03; // grosor del subborde en unidades UV
uniform float sub_noise_scale : hint_range(1.0, 200.0) = 40.0; // escala de ruido del subborde
uniform float sub_strength : hint_range(0.0, 2.0) = 1.0; // fuerza del subborde (mezcla)
// Fuerza de irregularidad del subborde por eje
uniform float sub_edge_strength_x : hint_range(0.0, 0.5) = 0.04;
uniform float sub_edge_strength_y : hint_range(0.0, 0.5) = 0.04;

// Semilla para variar el ruido
uniform float seed : hint_range(0.0, 1000.0) = 0.0;


// --- funciones de ruido ---
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 uv) {
    float val = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 5; i++) {
        val += amp * noise(uv);
        uv *= 2.0;
        amp *= 0.5;
    }
    return val;
}

// Distancia rectangular por componentes (devuelve dx, dy)
vec2 rect_distance_components(vec2 uv, vec2 cen, vec2 half_size) {
    vec2 d = abs(uv - cen) - half_size;
    return d;
}

void fragment() {
    // medio tamaño
    vec2 half = size * 0.5;

    // distancias por componente (dx, dy): negativas dentro, 0 en borde, positivas fuera
    vec2 comp = rect_distance_components(UV, center, half);
    float dx = comp.x;
    float dy = comp.y;

    // ruido separable para cada eje (variamos la semilla para decorrelacionar)
    float rag_x = fbm((UV + vec2(seed, seed * 0.3)) * noise_scale) * edge_strength_x;
    float rag_y = fbm((UV + vec2(seed * 0.7, seed + 13.13)) * noise_scale) * edge_strength_y;

    // aplicamos el ruido a cada componente de distancia
    dx += rag_x;
    dy += rag_y;

    // distancia rectangular combinada (max de componentes)
    float dist = max(dx, dy);

    // máscara exterior: 0 dentro del papel, 1 fuera (smoothstep para suavizar el borde)
    float outer_mask = smoothstep(0.0, smoothness, dist);

    // máscara del papel: 1 dentro del papel, 0 fuera
    float paper_mask = 1.0 - outer_mask;

    // --- SUBBORDE INTERIOR ---
    // ruido específico por eje para el subborde (semillas diferentes)
    float sub_rag_x = fbm((UV + vec2(seed + 21.0, seed * 0.5)) * sub_noise_scale) * sub_edge_strength_x;
    float sub_rag_y = fbm((UV + vec2(seed * 1.9, seed + 99.1)) * sub_noise_scale) * sub_edge_strength_y;

    // combinamos rugosidad del subborde en un solo valor para definir la franja (tomamos el máximo absoluto)
    float sub_rag = max(abs(sub_rag_x), abs(sub_rag_y));

    // sub_mask: 0 en el interior profundo, 1 en la franja interna junto al borde
    float sub_mask_raw = smoothstep(-sub_width - sub_rag, 0.0 + sub_rag, dist);

    // limitar el subborde para que esté dentro del papel
    float sub_mask = clamp(sub_mask_raw * paper_mask, 0.0, 1.0);

    // afinamos la mezcla del subborde (multiplicador de fuerza)
    float sub_mix = clamp(sub_mask * sub_strength, 0.0, 1.0);

    // --- COMPOSITE FINAL ---
    // primero mezclamos color de fondo y color del papel según la máscara principal
    vec3 base_rgb = mix(bg_color.rgb, paper_color.rgb, paper_mask);
    float base_a = mix(bg_color.a, paper_color.a, paper_mask);

    // aplicamos el subborde interior sobre el color del papel
    vec3 with_sub = mix(base_rgb, mix(base_rgb, sub_color.rgb, sub_mix), sub_mix);

    // resultado final (alpha igual que antes, el subborde está dentro del papel)
    COLOR = vec4(with_sub, base_a);
}
