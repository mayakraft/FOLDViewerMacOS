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
  float3 normal [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float3 normal;
};

// 2D CP
struct EdgeOut {
  float4 position [[position]];
  float3 color;
};

// 3D Mesh
vertex VertexOut vertex_mesh(VertexIn vin [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  VertexOut vertexOut;
  vertexOut.position = u.projectionMatrix * u.modelViewMatrix * float4(vin.position, 1);
  vertexOut.normal = vin.normal;
  return vertexOut;
}

fragment float4 fragment_mesh(VertexOut fragmentIn [[stage_in]]) {
//   rainbow color normals
//  float3 normal = normalize(fragmentIn.normal);
//  return float4(normal, 1);

  // simple white light from the top (+Y)
  float gray = (normalize(fragmentIn.normal).y + 1.0) / 2.0;
  return float4(gray, gray, gray, 1);
}

// 2D crease pattern, each vertex + normal (2 point, stride 6 floats) is actually a
// pair of vertices defining the edge's endpoints. face data still valid and points
// to one of these vertices
vertex EdgeOut vertex_cp(VertexIn vin [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
  EdgeOut edgeOut;
  edgeOut.position = u.projectionMatrix * u.modelViewMatrix * float4(vin.position, 1);
  edgeOut.color = vin.normal;
  return edgeOut;
}

fragment float4 fragment_cp(EdgeOut fragmentIn [[stage_in]]) {
  return float4(fragmentIn.color, 1);
}
