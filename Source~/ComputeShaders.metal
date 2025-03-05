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

// Compute shader to perform blend shape blending (without skinning).
kernel void blend(
    device BlendResult* results [[buffer(0)]],
    device const uint& vertexCount [[buffer(1)]],
    device const BaseVertex* baseVertices [[buffer(2)]],
    device const int32_t* blendShapeVertices [[buffer(3)]],
    device const float* blendFrameWeights [[buffer(4)]],
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

    // Normalize and set the results and apply the tangent sign.
    result.position = blendedPosition;
    result.normal = normalize(blendedNormal);
    result.tangent = normalize(blendedTangent);
    result.bitangent = normalize(cross(blendedNormal, blendedTangent)) * baseVertex.tangent.w;
}

// Compute shader to perform blend shape blending and skinning.
kernel void blendAndSkin(
    device BlendResult* results [[buffer(0)]],
    device const uint& vertexCount [[buffer(1)]],
    device const BaseVertex* baseVertices [[buffer(2)]],
    device const int32_t* blendShapeVertices [[buffer(3)]],
    device const float* blendFrameWeights [[buffer(4)]],
    device const JointInfluence* jointInfluences [[buffer(5)]],
    device const uint& jointInfluencesPerVertex [[buffer(6)]],
    device const float4x4* jointMatrices [[buffer(7)]],
    device const float3x3* jointNormalMatrices [[buffer(8)]],
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

// A compute shader that writes the first three columns of a matrix to a texture.
kernel void copyMatrixToTexture(
    device const float4x4& inMatrix [[buffer(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    outTexture.write(inMatrix[0], uint2(0, 0));
    outTexture.write(inMatrix[1], uint2(1, 0));
    outTexture.write(inMatrix[2], uint2(2, 0));
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

// Describes a single sub mesh range within an index buffer.
struct SubMesh
{
    uint32_t indexStart;
    uint32_t indexCount;
    uint32_t baseVertexIndex;
};

// A compute shader that transfers a buffer of 16-bit triangle indices to a buffer of 32-bit ones
// (with reversed winding order and optional offsets).
kernel void transferTriangleIndices16(
    device const uint16_t* sourceIndices [[buffer(0)]],
    device uint32_t* destIndices [[buffer(1)]],
    device const uint32_t& indexCount [[buffer(2)]],
    device const SubMesh* subMeshes [[buffer(3)]],
    device const uint32_t& subMeshCount [[buffer(4)]],
    uint indexIndex [[thread_position_in_grid]])
{
    if (indexIndex >= indexCount)
        return;

    // Find the range in which the index lies.
    for (auto subMesh = subMeshes, lastSubMesh = subMeshes + subMeshCount; subMesh < lastSubMesh; ++subMesh)
    {
        if (indexIndex >= subMesh->indexStart)
        {
            auto offset = indexIndex - subMesh->indexStart;
            if (offset < subMesh->indexCount)
            {
                // Each triplet 0, 1, 2 becomes reversed: 2, 1, 0.
                auto reversedOffset = offset + 2 - 2 * (offset % 3);
                destIndices[indexIndex] = subMesh->baseVertexIndex +
                    sourceIndices[subMesh->indexStart + reversedOffset];
            }
        }
    }
}

// A compute shader that transfers a buffer of 32-bit triangle indices to a buffer of 32-bit ones
// (with reversed winding order and optional offsets).
kernel void transferTriangleIndices32(
    device const uint32_t* sourceIndices [[buffer(0)]],
    device uint32_t* destIndices [[buffer(1)]],
    device const uint32_t& indexCount [[buffer(2)]],
    device const SubMesh* subMeshes [[buffer(3)]],
    device const uint32_t& subMeshCount [[buffer(4)]],
    uint indexIndex [[thread_position_in_grid]])
{
    if (indexIndex >= indexCount)
        return;

    // Find the range in which the index lies.
    for (auto subMesh = subMeshes, lastSubMesh = subMeshes + subMeshCount; subMesh < lastSubMesh; ++subMesh)
    {
        if (indexIndex >= subMesh->indexStart)
        {
            auto offset = indexIndex - subMesh->indexStart;
            if (offset < subMesh->indexCount)
            {
                // Each triplet 0, 1, 2 becomes reversed: 2, 1, 0.
                auto reversedOffset = offset + 2 - 2 * (offset % 3);
                destIndices[indexIndex] = subMesh->baseVertexIndex +
                    sourceIndices[subMesh->indexStart + reversedOffset];
            }
        }
    }
}

// Describes the location and size of a single attribute within the source and destination buffers.  If the attribute
// is unused, all fields will be -1.  The tangent is a special case where the size only applies to the source (the
// source is a float4, but the dest is two float3s: tangent and bitangent).  All values are in bytes.
struct TransferExtents
{
    int32_t sourceOffset;
    int32_t destOffset;
    int32_t size;
};

// Copies a range of values.  There's no std::copy/memcpy in MSL, as far as I can tell.
template<typename T>
inline void copy(device const T* sourceBegin, device const T* sourceEnd, device T* dest)
{
    for (auto source = sourceBegin; source < sourceEnd; ++source, ++dest)
    {
        *dest = *source;
    }
}

// Transfers all the vertex attributes that we support for a single buffer in one pass.
kernel void transferVertexAttributes(
    device const uint8_t* sourceVertices [[buffer(0)]],
    device uint8_t* destVertices [[buffer(1)]],
    device const uint32_t& vertexCount [[buffer(2)]],
    device const uint32_t& sourceStride [[buffer(3)]],
    device const uint32_t& destStride [[buffer(4)]],
    device const TransferExtents& positionExtents [[buffer(5)]],
    device const TransferExtents& normalExtents [[buffer(6)]],
    device const TransferExtents& tangentExtents [[buffer(7)]],
    device const TransferExtents& colorExtents [[buffer(8)]],
    device const TransferExtents* texCoordExtents [[buffer(9)]],
    device const uint32_t& texCoordExtentsCount [[buffer(10)]],
    uint vertexIndex [[thread_position_in_grid]])
{
    if (vertexIndex >= vertexCount)
        return;

    auto sourceVertex = sourceVertices + vertexIndex * sourceStride;
    auto destVertex = destVertices + vertexIndex * destStride;

    if (positionExtents.sourceOffset >= 0)
    {
        auto pos = *(device const packed_float3*)(sourceVertex + positionExtents.sourceOffset);
        *(device packed_float3*)(destVertex + positionExtents.destOffset) = packed_float3(pos.x, pos.y, -pos.z);
    }

    if (normalExtents.sourceOffset >= 0)
    {
        auto normal = *(device const packed_float3*)(sourceVertex + normalExtents.sourceOffset);
        *(device packed_float3*)(destVertex + normalExtents.destOffset) = packed_float3(normal.x, normal.y, -normal.z);

        // Computing the bitangent requires the normal.
        if (tangentExtents.sourceOffset >= 0)
        {
            auto tangent = *(device const packed_float4*)(sourceVertex + tangentExtents.sourceOffset);
            auto bitangent = cross(normal, tangent.xyz) * tangent.w;
            auto dest = (device packed_float3*)(destVertex + tangentExtents.destOffset);

            dest[0] = packed_float3(tangent.x, tangent.y, -tangent.z);
            dest[1] = packed_float3(bitangent.x, bitangent.y, -bitangent.z);
        }
    }

    if (colorExtents.sourceOffset >= 0)
    {
        // No transformation required for colors; we copy them as bytes.
        auto colorSource = sourceVertex + colorExtents.sourceOffset;
        copy(colorSource, colorSource + colorExtents.size, destVertex + colorExtents.destOffset);
    }

    for (auto extents = texCoordExtents, end = extents + texCoordExtentsCount; extents < end; ++extents)
    {
        // Invert the V coordinate when transferring the first two floats.
        auto source = (device const float*)(sourceVertex + extents->sourceOffset);
        auto dest = (device float*)(destVertex + extents->destOffset);
        auto uv = *(device const packed_float2*)source;
        *(device packed_float2*)dest = packed_float2(uv.x, 1.0f - uv.y);

        // Copy the rest as floats.
        copy(source + 2, source + extents->size / sizeof(float), dest + 2);
    }
}

// Transfers all the vertex attributes that we support from one buffer to another, flipping all the texture
// coordinates vertically.
kernel void flipTexCoords(
    device const uint8_t* sourceVertices [[buffer(0)]],
    device uint8_t* destVertices [[buffer(1)]],
    device const uint32_t& vertexCount [[buffer(2)]],
    device const uint32_t& stride [[buffer(3)]],
    device const uint32_t* texCoordOffsets [[buffer(4)]],
    device const uint32_t& texCoordOffsetCount [[buffer(5)]],
    uint vertexIndex [[thread_position_in_grid]])
{
    if (vertexIndex >= vertexCount)
        return;

    auto sourceVertex = sourceVertices + vertexIndex * stride;
    auto destVertex = destVertices + vertexIndex * stride;

    // Start by just copying the bytes of all attributes.
    copy(sourceVertex, sourceVertex + stride, destVertex);

    // Then flip the tex coords at the specified offsets.
    for (auto offset = texCoordOffsets, end = offset + texCoordOffsetCount; offset < end; ++offset)
    {
        *(device float*)(destVertex + *offset) = 1.0f - *(device const float*)(sourceVertex + *offset);
    }
}

// Transfers a block of indices from one buffer to another, adding an indexDelta value to each one.
kernel void batchIndices(
    device const uint32_t* sourceIndices [[buffer(0)]],
    device uint32_t* destIndices [[buffer(1)]],
    device const uint32_t& indexCount [[buffer(2)]],
    device const uint32_t& sourceOffset [[buffer(3)]],
    device const uint32_t& destOffset [[buffer(4)]],
    device const int32_t& indexDelta [[buffer(5)]],
    uint indexIndex [[thread_position_in_grid]])
{
    if (indexIndex < indexCount)
        destIndices[destOffset + indexIndex] = sourceIndices[sourceOffset + indexIndex] + indexDelta;
}

// Describes the location and size of a single attribute within the source and destination buffers.  If the attribute
// is unused, all fields will be -1.  All values are in bytes.
struct BatchExtents
{
    int32_t sourceOffset;
    int32_t destOffset;
    int32_t sourceSize;
    int32_t destSize;
};

// Assigns a range of values.  There's no std::fill/memset in MSL, as far as I can tell.
template<typename T>
inline void fill(device T* destBegin, device T* destEnd, T value)
{
    for (auto dest = destBegin; dest < destEnd; ++dest)
    {
        *dest = value;
    }
}

// Transfers a block of vertex data from one buffer to another, applying transforms to the point/vector values
// and performing simple conversions based on the sizes contained in the attribute extents.
kernel void batchVertices(
    device const uint8_t* sourceVertices [[buffer(0)]],
    device uint8_t* destVertices [[buffer(1)]],
    device const uint32_t& vertexCount [[buffer(2)]],
    device const uint32_t& sourceStride [[buffer(3)]],
    device const uint32_t& destStride [[buffer(4)]],
    device const uint32_t& sourceStart [[buffer(5)]],
    device const uint32_t& destStart [[buffer(6)]],
    device const float4x4& transformMatrix [[buffer(7)]],
    device const float3x3& normalMatrix [[buffer(8)]],
    device const BatchExtents& positionExtents [[buffer(9)]],
    device const BatchExtents& normalExtents [[buffer(10)]],
    device const BatchExtents& tangentExtents [[buffer(11)]],
    device const BatchExtents& bitangentExtents [[buffer(12)]],
    device const BatchExtents& colorExtents [[buffer(13)]],
    device const BatchExtents* texCoordExtents [[buffer(14)]],
    device const uint32_t& texCoordExtentsCount [[buffer(15)]],
    uint vertexIndex [[thread_position_in_grid]])
{
    if (vertexIndex >= vertexCount)
        return;

    auto sourceVertex = sourceVertices + sourceStart + vertexIndex * sourceStride;
    auto destVertex = destVertices + destStart + vertexIndex * destStride;

    if (positionExtents.sourceOffset >= 0)
    {
        auto packed = *(device const packed_float3*)(sourceVertex + positionExtents.sourceOffset);
        auto position = transformMatrix * float4(packed, 1.0f);
        *(device packed_float3*)(destVertex + positionExtents.destOffset) = packed_float3(position.xyz);
    }

    if (normalExtents.sourceOffset >= 0)
    {
        auto packed = *(device const packed_float3*)(sourceVertex + normalExtents.sourceOffset);
        auto normal = normalMatrix * float3(packed);
        *(device packed_float3*)(destVertex + normalExtents.destOffset) = packed_float3(normal);
    }

    if (tangentExtents.sourceOffset >= 0)
    {
        auto packed = *(device const packed_float3*)(sourceVertex + tangentExtents.sourceOffset);
        auto tangent = normalMatrix * float3(packed);
        *(device packed_float3*)(destVertex + tangentExtents.destOffset) = packed_float3(tangent);
    }

    if (bitangentExtents.sourceOffset >= 0)
    {
        auto packed = *(device const packed_float3*)(sourceVertex + bitangentExtents.sourceOffset);
        auto bitangent = normalMatrix * float3(packed);
        *(device packed_float3*)(destVertex + bitangentExtents.destOffset) = packed_float3(bitangent);
    }

    if (colorExtents.sourceOffset >= 0)
    {
        auto source = sourceVertex + colorExtents.sourceOffset;
        auto dest = destVertex + colorExtents.destOffset;

        // We assume the colors are either packed_float4 (Color) or packed_uchar4 (Color32).
        if (colorExtents.sourceSize == sizeof(packed_float4))
        {
            *(device packed_float4*)dest = *(device const packed_float4*)source;
        }
        else
        {
            auto color = *(device const packed_uchar4*)source;
            if (colorExtents.destSize == sizeof(packed_uchar4))
                *(device packed_uchar4*)dest = color;
            else
                *(device packed_float4*)dest = packed_float4(color.r, color.g, color.b, color.a) / 255.0f;
        }
    }

    for (auto extents = texCoordExtents, end = extents + texCoordExtentsCount; extents < end; ++extents)
    {
        auto source = (device const float*)(sourceVertex + extents->sourceOffset);
        auto dest = (device float*)(destVertex + extents->destOffset);

        // We copy the source range and fill the rest of the dest range with zeroes.
        auto sourceCount = extents->sourceSize / sizeof(float);
        copy(source, source + sourceCount, dest);
        fill(dest + sourceCount, dest + extents->destSize / sizeof(float), 0.0f);
    }
}
