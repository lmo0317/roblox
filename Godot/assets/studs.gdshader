shader_type spatial;
render_mode specular_disabled;
uniform vec4 base_color : source_color = vec4(0.38,0.9,0.08,1.0);
uniform float tile_size = 0.45;
uniform bool checker = true;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec3 n = abs(world_normal);
 vec2 p = world_pos.xz;
 if(n.x > n.y && n.x > n.z) p = world_pos.zy;
 else if(n.z > n.y && n.z > n.x) p = world_pos.xy;
 vec2 cell = fract(p/tile_size);
 vec2 d = abs(cell-0.5);
 float dist = max(d.x,d.y);
 float aa = max(fwidth(dist),0.012);
 float outer = 1.0-smoothstep(0.31-aa,0.31+aa,dist);
 float inner = 1.0-smoothstep(0.23-aa,0.23+aa,dist);
 float rim = outer-inner;
 float light_side = step(cell.x+cell.y,1.0);
 float relief = 1.0+rim*mix(-0.24,0.25,light_side)+inner*0.025;
 float check = mod(floor(p.x/(tile_size*8.0))+floor(p.y/(tile_size*8.0)),2.0);
 vec3 color = base_color.rgb * relief;
 if(checker) color *= mix(0.90,1.03,check);
 ALBEDO = color;
 ROUGHNESS = 0.9;
}
