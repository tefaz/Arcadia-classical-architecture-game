shader_type spatial;

varying vec3 tree_position;

float hash(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
    vec3 cell = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(cell), hash(cell + vec3(1,0,0)), f.x),
                   mix(hash(cell + vec3(0,1,0)), hash(cell + vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(cell + vec3(0,0,1)), hash(cell + vec3(1,0,1)), f.x),
                   mix(hash(cell + vec3(0,1,1)), hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
    tree_position = VERTEX;
}

void fragment() {
    float grain = noise(tree_position * vec3(28.0, 2.2, 28.0));
    float cracks = smoothstep(0.48, 0.72, noise(tree_position * vec3(42.0, 1.1, 42.0)));
    ALBEDO = COLOR.rgb * (0.8 + grain * 0.32 - cracks * 0.22);
    ROUGHNESS = 0.98;
    SPECULAR = 0.12;
}
