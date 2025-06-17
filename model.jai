
#import "Basic";

#import "common";
#import "image";
#import "Math";
#import "animation_graph";


Mesh_Triangle_Vertex :: struct {
    vertex_index:  s32;
    uv_index:      s32;
    normal_index:  s32;
    tangent_index: s32;
    color_index:   s32;
    
    bone_count:    u32;
    bone_ids:      [4]u32;
    bone_weights:  [4]f32;
}


Mesh_Triangle :: struct {
    v1: Mesh_Triangle_Vertex;
    v2: Mesh_Triangle_Vertex;
    v3: Mesh_Triangle_Vertex;
}


Mesh :: struct {
    name:           string;
    triangles:      [..]Mesh_Triangle;
    vertices:       [..]V3;
    normals:        [..]V3;
    tangents:       [..]V3;
    uvs:            [..]V2;
    colors:         [..]Color;
    material_names: [..]string;
    materials:      [..]*Mesh_Material;
    
    skeleton_id:    s32;
    bone_ids:       [..]u32;
    
    mesh_to_world:  Matrix4;
    world_to_mesh:  Matrix4;
    
    dead_vertices: [..]u32;
}

Model :: struct {
    name: string;
    meshes:          [..]*Mesh;
    skeletons:       [..]*Bone;
    bone_count:      u32;
    animations:      [..]*Animation;
    animation_graph: Animation_Graph;
}


Bone :: struct {
    id:           u32;
    position:     V3;
    rotation:     Quat;
    scale:        V3;
    local:        Matrix4;
    global:       Matrix4;
    inverse_bind: Matrix4;
    parent:       *Bone;
    children:     [..]*Bone;
}


Animation :: struct {
    name:        string;
    time:        f32;
    frame_times: [..]f32;
    frames:      [..]Animation_Frame;
}

Animation_Transform :: struct {
    object_id: s32; // the linked object whether that be a bone or mesh.
    position:  V3;
    rotation:  V3;
    scale:     V3;
    local:     Matrix4;
    
    // used as a back reference to whatever animation format this was created from.
    ref_id: u64;
}

Animation_Frame :: struct {
    mesh_transform:  Animation_Transform;
    bone_transforms: [..]Animation_Transform;
    // NOTE: if the mesh transform ever looks off. Then it 
    // might be because the transforms are local and it doesn't
    // take into account any objects higher than the root in
    // the hierarchy, such as the null node above the root bone.
}



Mesh_Texture_Type :: enum {
    Diffuse;
    Normal;
    Specular;
    Shininess;
    Ambient;
    Emissive;
    Reflection;
    Opacity;
    
    Count;
}


Mesh_Material :: struct {
    name:              string;
    ambient_color:     Color;
    diffuse_color:     Color;
    specular_color:    Color;
    shininess:         f32;
    alpha:             f32;
    illum:             u32;
    texture_map_files: [Mesh_Texture_Type.Count]string;
    texture_map_ids:   [Mesh_Texture_Type.Count]s32;
}




mesh_triangle_fix_winding_order :: (mesh: *Mesh, triangle: *Mesh_Triangle) {
    v1 := mesh.vertices[triangle.v1.vertex_index];
    v2 := mesh.vertices[triangle.v2.vertex_index];
    v3 := mesh.vertices[triangle.v3.vertex_index];
    edge1 := v2 - v1;
    edge2 := v3 - v1;
    
    normal := cross(edge1, edge2);
    
    n1 := mesh.normals[triangle.v1.normal_index];
    if dot(n1, normal) < 0 {
        temp := triangle.v3;
        triangle.v3 = triangle.v1;
        triangle.v1 = temp;
    }
    
}