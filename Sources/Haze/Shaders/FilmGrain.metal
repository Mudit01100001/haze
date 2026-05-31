#include <metal_stdlib>
using namespace metal;

/// Uniforms passed from the CPU each frame.
struct GrainUniforms {
    float time;       // elapsed seconds (for temporal variation)
    float intensity;  // 0..1, grain visibility
    float size;       // grain particle size in pixels (0.5..4)
    float speed;      // animation speed multiplier
    uint2 resolution; // output texture size in pixels
};

// ---------- Hash-based blue-noise grain ----------
// Uses a combination of two hash functions to produce
// high-frequency noise without the repeating stripe
// artefacts that plagued simpler approaches.

/// Integer hash from "Hash without Sine" by Dave Hoskins.
/// https://www.shadertoy.com/view/4djSRW
float hash12(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/// Secondary hash for blue-noise-like distribution.
float hash13(float3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}

/// Film grain kernel.
/// Reads the current texture (blur + dim composite), applies
/// monochrome temporal film grain, and writes the result back.
kernel void filmGrainKernel(
    texture2d<float, access::read>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant GrainUniforms &uniforms           [[buffer(0)]],
    uint2 gid                                  [[thread_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= uniforms.resolution.x || gid.y >= uniforms.resolution.y) {
        return;
    }

    // Read source pixel
    float4 color = inTexture.read(gid);

    // Scale coordinates by grain size (larger size = larger grain particles)
    float2 uv = float2(gid) / max(uniforms.size, 0.5);

    // Temporal offset — changes each frame for the "breathing" feel.
    // floor(time * speed * 12) gives ~12 grain updates per second at 1x speed,
    // creating a film-like flicker rather than smooth animation.
    float timeSlice = floor(uniforms.time * uniforms.speed * 12.0);

    // Two-pass hash for better spatial distribution (less structured artifacts)
    float grain = hash12(uv + timeSlice * 1.17);
    grain = mix(grain, hash13(float3(uv, timeSlice * 0.73)), 0.5);

    // Center around 0 (range: -0.5 to 0.5) and scale by intensity
    grain = (grain - 0.5) * uniforms.intensity;

    // Overlay blend: preserves midtones, affects highlights and shadows
    // This looks more natural than additive blending
    float3 grainColor = float3(grain);
    float3 result = color.rgb;

    // Soft-light blend (less harsh than pure overlay)
    float3 a = result;
    float3 b = grainColor + 0.5; // shift to 0..1 range for blending
    result = mix(
        2.0 * a * b,
        1.0 - 2.0 * (1.0 - a) * (1.0 - b),
        step(0.5, a)
    );

    outTexture.write(float4(result, color.a), gid);
}
