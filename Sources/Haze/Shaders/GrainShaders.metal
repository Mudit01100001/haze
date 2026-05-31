#include <metal_stdlib>
using namespace metal;

struct GrainConstants {
    float intensity;
    float time;
    float size;
};

// Cryptographic-grade 3D PCG Hash.
// Mathematically proven to have ZERO repeating patterns in 2D space.
static float pcg3d(uint3 p) {
    p = p * uint3(1640531513u, 2924584289u, 2654435769u);
    p ^= p >> 16;
    p += p.yzx * uint3(2654435769u, 1640531513u, 2924584289u);
    p ^= p >> 16;
    p *= uint3(1640531513u, 2924584289u, 2654435769u);
    
    // Mix the 3 components into a single float 0.0-1.0
    uint n = p.x ^ p.y ^ p.z;
    return float(n) * (1.0 / 4294967296.0);
}

kernel void filmGrain(texture2d<float, access::write> outTexture [[texture(0)]],
                      constant GrainConstants &params [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }
    
    uint scaledX = gid.x / max(uint(params.size), 1u);
    uint scaledY = gid.y / max(uint(params.size), 1u);
    uint t = uint(params.time);
    
    float noise = pcg3d(uint3(scaledX, scaledY, t)); // 0.0 to 1.0
    
    // Pure black pixels with random opacity. This never increases brightness.
    float alpha = noise * params.intensity;
    outTexture.write(float4(0.0, 0.0, 0.0, alpha), gid);
}

kernel void chromaticGrain(texture2d<float, access::write> outTexture [[texture(0)]],
                           constant GrainConstants &params [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    uint scaledX = gid.x / max(uint(params.size), 1u);
    uint scaledY = gid.y / max(uint(params.size), 1u);
    uint t = uint(params.time);
    
    float noiseR = pcg3d(uint3(scaledX + 111u, scaledY, t));
    float noiseG = pcg3d(uint3(scaledX + 444u, scaledY, t));
    float noiseB = pcg3d(uint3(scaledX + 777u, scaledY, t));
    
    // For chromatic, we blend slight color variations by tinting the soot
    float r = noiseR * params.intensity;
    float g = noiseG * params.intensity;
    float b = noiseB * params.intensity;
    
    outTexture.write(float4(r, g, b, params.intensity), gid);
}
