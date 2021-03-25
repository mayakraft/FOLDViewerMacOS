//
//  shaders.metal
//  MeshViewer
//
//  Created by Robby on 3/3/21.
//

#include <metal_stdlib>
using namespace metal;

struct Uniforms {
  float4x4 modelViewMatrix;
  float4x4 projectionMatrix;
};

struct SegmentsUniforms {
  float3 start;
  float3 end;
  float3 vector;
};

// 3D Mesh
struct VertexIn {
  float3 position [[attribute(0)]];
//  float3 normal [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float3 normal;
};

// 2D CP
struct EdgeOut {
  float4 origin [[position]];
  float4 end;
  float4 vector;
};

// 3D Mesh
vertex VertexOut vertex_mesh(VertexIn vin [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  VertexOut vertexOut;
  vertexOut.position = u.projectionMatrix * u.modelViewMatrix * float4(vin.position, 1);
//  vertexOut.normal = vin.normal;
  return vertexOut;
}

fragment float4 fragment_mesh(VertexOut fragmentIn [[stage_in]]) {
  float3 normal = normalize(fragmentIn.normal);
  return float4(normal, 1);
}

// 2D crease pattern, each vertex + normal (2 point, stride 6 floats) is actually a
// pair of vertices defining the edge's endpoints. face data still valid and points
// to one of these vertices
vertex EdgeOut vertex_cp(VertexIn vin [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  EdgeOut edgeOut;
  edgeOut.origin = u.projectionMatrix * u.modelViewMatrix * float4(vin.position, 1);
//  edgeOut.end = u.projectionMatrix * u.modelViewMatrix * float4(vin.normal, 1);
//  edgeOut.vector = edgeOut.end - edgeOut.origin;
  return edgeOut;
}

fragment float4 fragment_cp(EdgeOut fragmentIn [[stage_in]]) {
//  float gray = (fragmentIn.normalY + 1.0) / 2.0;
//  float gray = (normalize(fragmentIn.normal).y + 1.0) / 2.0;
//  return float4(gray, gray, gray, 1);
//  float3 normal = normalize(fragmentIn.vector.xyz);
//  return float4(normal, 1);

  return float4(1, 0, 0.5, 1);
}
