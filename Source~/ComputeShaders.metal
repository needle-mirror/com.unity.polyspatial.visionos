#include <metal_stdlib>

using namespace metal;

// This file contains the compute shaders used to process image based lighting (IBL) textures,
// converting them from Unity to RealityKit format, as well as the compute shaders used to
// perform blend shape blending.

// Contains the attributes associated with a base vertex for blending.
struct BaseVertex
{
    float3 position;
    float3 normal;
    float4 tangent;
};

// Contains the deltas associated with a single blend shape for a single vertex.
#pragma pack(push, 1)
struct BlendShapeVertex
{
    int32_t index;
    float3 positionDelta;
    float3 normalDelta;
    float3 tangentDelta;
};
#pragma pack(pop)

// Represents the influence of a single joint on a vertex.
struct JointInfluence
{
    int32_t index;
    float weight;
};

// Contains the final result of blending.
struct BlendResult
{
    float3 position;
    float3 normal;
    float3 tangent;
    float3 bitangent;
};

// Compute shader to perform blend shape blending and skinning.
kernel void blendAndSkin(
    device const uint& vertexCount [[buffer(0)]],
    device const BaseVertex* baseVertices [[buffer(1)]],
    device const int32_t* blendShapeVertices [[buffer(2)]],
    device const float* blendFrameWeights [[buffer(3)]],
    device const JointInfluence* jointInfluences [[buffer(4)]],
    device const uint& jointInfluencesPerVertex [[buffer(5)]],
    device const float4x4* jointMatrices [[buffer(6)]],
    device const float3x3* jointNormalMatrices [[buffer(7)]],
    device BlendResult* results [[buffer(8)]],
    uint index [[thread_position_in_grid]])
{
    if (index >= vertexCount)
        return;
    
    // Start with the base vertex attributes.
    device auto& result = results[index];
    device auto& baseVertex = baseVertices[index];
    auto blendedPosition = baseVertex.position;
    auto blendedNormal = baseVertex.normal;
    auto blendedTangent = baseVertex.tangent.xyz;
    
    // Extract the blend shape vertex range for the current index.
    auto startVertex = (device const BlendShapeVertex*)(blendShapeVertices + blendShapeVertices[index]);
    auto endVertex = (device const BlendShapeVertex*)(blendShapeVertices + blendShapeVertices[index + 1]);
    
    // Add each blend shape vertex multiplied by its weight in the array.
    for (auto currentVertex = startVertex; currentVertex != endVertex; ++currentVertex)
    {
        auto weight = blendFrameWeights[currentVertex->index];
        blendedPosition += currentVertex->positionDelta * weight;
        blendedNormal += currentVertex->normalDelta * weight;
        blendedTangent += currentVertex->tangentDelta * weight;
    }
    
    auto position = float3(0, 0, 0);
    auto normal = float3(0, 0, 0);
    auto tangent = float3(0, 0, 0);
    
    auto startInfluence = jointInfluences + index * jointInfluencesPerVertex;
    auto endInfluence = startInfluence + jointInfluencesPerVertex;
    
    // Apply the joint influences to the results of blending.
    for (auto currentInfluence = startInfluence; currentInfluence != endInfluence; ++currentInfluence)
    {
        auto jointMatrix = jointMatrices[currentInfluence->index];
        auto jointNormalMatrix = jointNormalMatrices[currentInfluence->index];
        
        position += (jointMatrix * float4(blendedPosition, 1)).xyz * currentInfluence->weight;
        normal += jointNormalMatrix * blendedNormal * currentInfluence->weight;
        tangent += jointNormalMatrix * blendedTangent * currentInfluence->weight;
    }
    
    // Normalize and set the results and apply the tangent sign.
    result.position = position;
    result.normal = normalize(normal);
    result.tangent = normalize(tangent);
    result.bitangent = normalize(cross(normal, tangent)) * baseVertex.tangent.w;
}

// A compute shader that simply flips in the input vertically and writes it to the output
// (necessary because the CGImage constructor expects data with a lower-left origin).
kernel void textureFlipVertical(
    texture2d<half, access::read> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x < outTexture.get_width() && gid.y < outTexture.get_height())
        outTexture.write(inTexture.read(uint2(gid.x, inTexture.get_height() - gid.y - 1)), gid);
}

// A compute shader that converts a cube map to the equirectangular (that is,
// latitude/longitude) format required by the EnvironmentResource constructor.
kernel void textureCubeToEquirectangular(
    texturecube<half, access::sample> inTexture [[texture(0)]],
    texture2d<half, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    // Convert grid position to lat/long.
    float latitude = gid.x * 2 * M_PI_F / outTexture.get_width();
    float longitude = gid.y * M_PI_F / outTexture.get_height();

    // Convert lat/long to unit direction.
    float sinLongitude = sin(longitude);
    float3 dir = float3(-sinLongitude * sin(latitude), cos(longitude), -sinLongitude * cos(latitude));
    
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    outTexture.write(inTexture.sample(textureSampler, dir), gid);
}
