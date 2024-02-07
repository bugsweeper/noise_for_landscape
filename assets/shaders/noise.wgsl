// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// https://www.shadertoy.com/view/Xsl3Dl
fn hash(point: vec3f) -> vec3f // replace this by something better
{
    let p = vec3f(dot(point,vec3f(127.1,311.7, 74.7)),
        dot(point,vec3f(269.5,183.3,246.1)),
        dot(point,vec3f(113.5,271.9,124.6)));

    return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

fn perlin_noise(p: vec3f) -> f32 {
    let i = floor(p);
    let f = fract(p);

    // fade curve value
    let fade = f*f*(vec3f(3.0)-(2.0*f));

    return mix(mix(mix(dot(hash(i + vec3(0.0,0.0,0.0)), f - vec3(0.0,0.0,0.0)),
                       dot(hash(i + vec3(1.0,0.0,0.0)), f - vec3(1.0,0.0,0.0)),fade.x),
                   mix(dot(hash(i + vec3(0.0,1.0,0.0)), f - vec3(0.0,1.0,0.0)),
                       dot(hash(i + vec3(1.0,1.0,0.0)), f - vec3(1.0,1.0,0.0)),fade.x),fade.y),
               mix(mix(dot(hash(i + vec3(0.0,0.0,1.0)), f - vec3(0.0,0.0,1.0)),
                       dot(hash(i + vec3(1.0,0.0,1.0)), f - vec3(1.0,0.0,1.0)),fade.x),
                   mix(dot(hash(i + vec3(0.0,1.0,1.0)), f - vec3(0.0,1.0,1.0)),
                       dot(hash(i + vec3(1.0,1.0,1.0)), f - vec3(1.0,1.0,1.0)),fade.x),fade.y),fade.z);
}

const F3 = 0.33333333333; // 1/3 Very nice and simple skew factor for 3D
const G3 = 0.16666666666; // 1/6 Very nice and simple unskew factor, too
const ONE: vec3f = vec3(1.0, 1.0, 1.0);

fn simplex_noise(p: vec3f) -> f32 {
    // Skew input space to determine which simplex cell we're in
    let s = dot(p, ONE) * F3;
    let i = floor(p + s); // (i, j, k) coords
    let t = dot(i, ONE) * G3;
    let P0 = i - t; // Unskew the cell origin back to (x, y, z) space
    let p0 = p - P0; // The x,y,z distances from cell origin

    // For the 3D case, the simplex shape is a slightly irregular tetrahedron
    // Determin which simplex we are in.
    var i1: vec3f; // Offsets for second corner of simplex in (i, j, k) coords
    var i2: vec3f; // Offsets for third corner of simplex in (i, j, k) coords

    if (p0.x >= p0.y) {
        if (p0.y >= p0.z) {
            i1 = vec3f(1.0, 0.0, 0.0);
            i2 = vec3f(1.0, 1.0, 0.0);
        } else if (p0.x >= p0.z) {
            i1 = vec3f(1.0, 0.0, 0.0);
            i2 = vec3f(1.0, 0.0, 1.0);
        } else {
            i1 = vec3f(0.0, 0.0, 1.0);
            i2 = vec3f(1.0, 0.0, 1.0);
        }
    } else { // p0.x < p0.y
        if (p0.y < P0.z) {
            i1 = vec3f(0.0, 0.0, 1.0);
            i2 = vec3f(0.0, 1.0, 1.0);
        } else if (p0.x < p0.z) {
            i1 = vec3f(0.0, 1.0, 0.0);
            i2 = vec3f(0.0, 1.0, 1.0);
        } else {
            i1 = vec3f(0.0, 1.0, 0.0);
            i2 = vec3f(1.0, 1.0, 0.0);
        }
    }

    // A step of (1,0,0) in (i,j,k) means a step of (1-c,-c,-c) in (x,y,z),
    // a step of (0,1,0) in (i,j,k) means a step of (-c,1-c,-c) in (x,y,z), and
    // a step of (0,0,1) in (i,j,k) means a step of (-c,-c,1-c) in (x,y,z), where
    // c = 1/6.

    let p1 = p0 - i1 + G3; // Offsets for second corner in (x, y, z) coords
    let p2 = p0 - i2 + 2.0 * G3; // Offsets for third corner in (x, y, z) coords
    let p3 = p0 - 1.0 + 3.0 * G3; // Offsets for last corner in (x, y, z) coords

    // Work out the hashed gradient inidices of the four simplex corners
    var tc = clamp(vec4f(0.6) - vec4f(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)), vec4f(0.0), vec4f(0.6));
    tc *= tc;
    let n = tc * tc * vec4f(dot(hash(i), p0), 
                            dot(hash(i + i1), p1),
                            dot(hash(i + i2), p2),
                            dot(hash(i + ONE), p3));
    return 32.0 * dot(n, vec4f(1.0, 1.0, 1.0, 1.0));
}

fn fbm_of_perlin_noise(p: vec3f, octaves: i32, persistence: f32, lacunarity: f32) -> f32 {
    var amplitude = 0.5;
    var frequency = 1.0;
    var total = 0.0;
    var normalization = 0.0;

    for (var i = 0; i < octaves; i += 1) {
        let noise_value = perlin_noise(p * frequency);
        total += noise_value * amplitude;
        normalization += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }

    total /= normalization;

    return total;
}

fn fbm_of_simplex_noise(p: vec3f, octaves: i32, persistence: f32, lacunarity: f32) -> f32 {
    var amplitude = 0.5;
    var frequency = 1.0;
    var total = 0.0;
    var normalization = 0.0;

    for (var i = 0; i < octaves; i += 1) {
        let noise_value = simplex_noise(p * frequency);
        total += noise_value * amplitude;
        normalization += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }

    total /= normalization;

    return total;
}


// The time since startup data is in the globals binding which is part of the mesh_view_bindings import
#import bevy_pbr::{
    prepass_bindings,
    mesh_functions,
    mesh_view_bindings::globals,
    forward_io::{Vertex, VertexOutput},
    skinning,
    mesh_view_bindings::{view, previous_view_proj},
    utils,
}

struct CustomMaterial {
    mode: u32,
};

@group(1) @binding(0) var<uniform> material: CustomMaterial;

#import bevy_render::instance_index::get_instance_index

const EPSILON: f32 = 0.001;

const ZERO: vec3f = vec3(0.0, 0.0, 0.0);

const RED: vec3f = vec3(1.0, 0.0, 0.0);
const ORANGE: vec3f = vec3(1.0, 0.25, 0.0);
const YELLOW: vec3f = vec3(1.0, 1.0, 0.0);
const GREEN: vec3f = vec3(0.0, 1.0, 0.0);
const BLUE: vec3f = vec3(0.0, 0.0, 1.0);
const VIOLET: vec3f = vec3(1.0, 0.0, 1.0);

fn color_mix(color: vec3f, pos: f32, goal: f32) -> vec3f {
    let y = 1.0 - abs(pos - goal);
    return mix(ZERO, color, clamp(y, 0.0, 1.0));
}

fn rainbow_mix(pos: f32) -> vec3f {
    let subrange_pos = pos * 5.0;
    return color_mix(RED, subrange_pos, 0.0) + color_mix(ORANGE, subrange_pos, 1.0) + color_mix(YELLOW, subrange_pos, 2.0) + color_mix(GREEN, subrange_pos, 3.0) + color_mix(BLUE, subrange_pos, 4.0) + color_mix(VIOLET, subrange_pos, 5.0);
}

fn rand(pos: vec2f) -> f32 {
    return utils::random1D(pos.x * pos.y * (pos.x + pos.y));
}

@vertex
fn vertex(vertex: Vertex) -> VertexOutput {
    var out: VertexOutput;

#ifdef SKINNED
    var model = skinning::skin_model(vertex.joint_indices, vertex.joint_weights);
#else // SKINNED
    var model = mesh_functions::get_model_matrix(vertex.instance_index);
#endif // SKINNED

    var height = 0.0;
    if material.mode == 1u {
        // just random
        height = rand(vertex.uv); 
    } else if material.mode == 2u {
        let grid_dimensity = 64.0;
        let step = 1.0 / grid_dimensity;
        // gradient noise
        let scaled_grid = vertex.uv * grid_dimensity;
        let cell_pos = fract(scaled_grid);
        let base = floor(scaled_grid) / grid_dimensity;
        let p00 = rand(base);
        let p01 = rand(base + vec2f(0.0, step));
        let p10 = rand(base + vec2f(step, 0.0));
        let p11 = rand(base + vec2f(step, step));
        
        let p0 = mix(p00, p01, cell_pos.y);
        let p1 = mix(p10, p11, cell_pos.y);
        height = mix(p0, p1, cell_pos.x);
    } else if material.mode == 3u {
        let grid_dimensity = 64.0;
        let step = 1.0 / grid_dimensity;
        // gradient noise with smoothness
        let scaled_grid = vertex.uv * grid_dimensity;
        let cell_pos = smoothstep(vec2f(0.0), vec2f(1.0), fract(scaled_grid));
        let base = floor(scaled_grid) / grid_dimensity;
        let p00 = rand(base);
        let p01 = rand(base + vec2f(0.0, step));
        let p10 = rand(base + vec2f(step, 0.0));
        let p11 = rand(base + vec2f(step, step));
        
        let p0 = mix(p00, p01, cell_pos.y);
        let p1 = mix(p10, p11, cell_pos.y);
        height = mix(p0, p1, cell_pos.x);
    } else if material.mode == 4u {
        let noise = fbm_of_perlin_noise(vec3f(10.0 * vertex.uv, globals.time * 0.2), 16, 0.5, 2.0);
        height = (noise + 1.0) / 2.0; 
    } else if material.mode == 5u {
        // let noise = fbm_of_simplex_noise(vec3f(10.0 * vertex.uv, globals.time * 0.2), 16, 0.5, 2.0);
        // height = (noise + 1.0) / 2.0; 
        // height = simplex_noise(vec3f(10.0 * vertex.uv, globals.time * 0.2));
        height = simplex_noise(vec3f(10.0 * vertex.uv, globals.time * 0.02));
    }
    let new_position = vec3f(vertex.position.x, height/* - (sin(globals.time) + 1.0) / 2.0*/, vertex.position.z);
    out.position = mesh_functions::mesh_position_local_to_clip(model, vec4(new_position, 1.0));
#ifdef DEPTH_CLAMP_ORTHO
    out.clip_position_unclamped = out.position;
    out.position.z = min(out.position.z, 1.0);
#endif // DEPTH_CLAMP_ORTHO

#ifdef VERTEX_UVS
    out.uv = vertex.uv;
#endif // VERTEX_UVS

#ifdef VERTEX_UVS_B
    out.uv_b = vertex.uv_b;
#endif // VERTEX_UVS_B

#ifdef NORMAL_PREPASS_OR_DEFERRED_PREPASS
#ifdef SKINNED
    out.world_normal = skinning::skin_normals(model, vertex.normal);
#else // SKINNED
    out.world_normal = mesh_functions::mesh_normal_local_to_world(
        vertex.normal,
        get_instance_index(vertex.instance_index)
    );
#endif // SKINNED

#ifdef VERTEX_TANGENTS
    out.world_tangent = mesh_functions::mesh_tangent_local_to_world(
        model,
        vertex.tangent,
        get_instance_index(vertex.instance_index)
    );
#endif // VERTEX_TANGENTS
#endif // NORMAL_PREPASS_OR_DEFERRED_PREPASS

#ifdef VERTEX_COLORS
//     out.color = vertex.color;
    // out.color = vec4f(height, 1.0, height, 1.0);
    out.color = vec4f(rainbow_mix(height), 1.0);
    // out.color = vec4f(rainbow_mix(vertex.uv.x), 1.0);
#endif

    out.world_position = mesh_functions::mesh_position_local_to_world(model, vec4<f32>(vertex.position, 1.0));

#ifdef MOTION_VECTOR_PREPASS
    out.previous_world_position = mesh_functions::mesh_position_local_to_world(
        mesh_functions::get_previous_model_matrix(vertex.instance_index),
        vec4<f32>(vertex.position, 1.0)
    );
#endif // MOTION_VECTOR_PREPASS

#ifdef VERTEX_OUTPUT_INSTANCE_INDEX
    out.instance_index = get_instance_index(vertex.instance_index);
#endif
#ifdef BASE_INSTANCE_WORKAROUND
    out.position.x += min(f32(get_instance_index(0u)), 0.0);
#endif

    return out;
}

// Default fragment shader makes magenta color like here https://github.com/bevyengine/bevy/blob/main/crates/bevy_pbr/src/prepass/prepass.wgsl#L151
@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    // var color = vec3(0.0); // background
    // return vec4<f32>(color, 1.0);
    return in.color;
}
