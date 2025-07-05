
#scope_file

#import "Basic";
#import "String";

#import "common";
#import "file_io_common";

#import "model";



#scope_export




parse_face_vertex :: (_line: string) -> (s32, s32, s32) {
    v:s32= 0;
    t:s32=-1;
    n:s32=-1;
    
    line := _line;
    line = eat_spaces(line);
    
    // NOTE(justin): have to subtract 1 from the vertex values
    // since obj file indexes start at 1 instead of 0.
    found, left, right : = split_from_left(line, "/");
    if found {
        v = string_to_int(left, 10, s32) - 1;
        last_right := right;
        found, left, right = split_from_left(right, "/");
        if found {
            if left.count > 0 {
                t = string_to_int(left, 10, s32) - 1;
            }
            if right.count > 0 {
                n = string_to_int(right, 10, s32) - 1;
            }
        } else {
            t = string_to_int(last_right, 10, s32) - 1;
        }
    } else {
        line = slice(line, 0, 1);
        v = string_to_int(line, 10, s32) - 1;
    }
    
    return v,t,n;
}



parse_line :: (_line: string, mesh: *Mesh) {
    if _line.count == 0 return;
    
    line := _line;
    line = trim(line);
    
    found, left, right := split_from_left(line, " ");
    
    if equal(left, "o") {
        if mesh.name.count > 0 {
            print("Currently we only support a single object per obj file.");
            assert(false);
        }
        
        mesh.name = right;
        mesh.name = eat_spaces(mesh.name);
        
    } else if equal(left, "v") {
        
        line = right;
        line = eat_spaces(line);
        
        v : V3 = .{};
        
        found, left, right : = split_from_left(line, " ");
        v.x = string_to_float(left);
        line = right;
        line = eat_spaces(line);
        found, left, right = split_from_left(line, " ");
        v.y = string_to_float(left);
        v.z = string_to_float(right);
        
        array_add(*mesh.vertices, v);
        
    } else if equal(left, "vt") {
        line = right;
        line = eat_spaces(line);
        
        t : V2 =.{};
        
        found, left, right : = split_from_left(line, " ");
        t.u  = string_to_float(left);
        if right.count > 0 {
            line = right;
            line = eat_spaces(line);
            found, left, right = split_from_left(line, " ");
            if found {
                t.v = string_to_float(left);
            } else {
                t.v = string_to_float(line);
            }
        }
        
        array_add(*mesh.uvs, t);
        
    } else if equal(left, "vn") {
        
        line = right;
        line = eat_spaces(line);
        
        n : V3 = .{};
        
        found, left, right : = split_from_left(line, " ");
        n.x = string_to_float(left);
        line = right;
        line = eat_spaces(line);
        found, left, right = split_from_left(line, " ");
        n.y = string_to_float(left);
        n.z = string_to_float(right);
        
        array_add(*mesh.normals, n);
        
    } else if equal(left, "vp") {
        
    } else if equal(left, "usemtl") {
        
        array_add(*mesh.material_names, right);
        
    } else if equal(left, "f") {
        
        triangle : Mesh_Triangle = .{};
        
        line = right;
        line = eat_spaces(line);
        
        found, left, right: = split_from_left(line, " ");
        v,t,n := parse_face_vertex(left);
        triangle.v1.vertex_index = v;
        triangle.v1.uv_index     = t;
        triangle.v1.normal_index = n;
        found, left, right = split_from_left(right, " ");
        v,t,n  = parse_face_vertex(left);
        triangle.v2.vertex_index = v;
        triangle.v2.uv_index     = t;
        triangle.v2.normal_index = n;
        v,t,n  = parse_face_vertex(right);
        triangle.v3.vertex_index = v;
        triangle.v3.uv_index     = t;
        triangle.v3.normal_index = n;
        
        array_add(*mesh.triangles, triangle);
        
    } else {
        
    }
}



obj_load :: (data: *u8, data_size: u64) -> Model {
    
    model: Model = .{};
    mesh := cast(*Mesh)alloc(size_of(Mesh));
    <<mesh = .{};
    
    
    line_builder: String_Builder = .{};
    c := <<(data);
    size := data_size;
    while size > 0 {
        while true {
            c = <<consume_data(*data, u8);
            size -= 1;
            if c == 0x0a break;
            append(*line_builder, c);
            if size == 0 break;
            
        }
        
        line:string = builder_to_string(*line_builder);
        parse_line(line, mesh);
        
        if size == 0 break;
    }
    
    array_add(*model.meshes, mesh);
    
    return model;
}











mtl_parse_color_line :: (_line: string) -> Color {
    color: Color = .{};
    
    line := _line;
    
    found, left, right : = split_from_left(line, " ");
    color.r = string_to_float(left);
    line = right;
    line = eat_spaces(line);
    found, left, right = split_from_left(line, " ");
    color.g = string_to_float(left);
    color.b = string_to_float(right);
    
    color.a = 1.0;
    return color;
}


mtl_parse_line :: (_line: string, mat: *Mesh_Material) {
    
    line := _line;
    line = trim(line);
    
    found, left, right: = split_from_left(line, " ");
    if found {
        
        right = trim(right);
        
        if equal(left, "newmtl") {
            mat.name = right;
        } else if equal(left, "Ka") {
            mat.ambient_color = mtl_parse_color_line(right);
        } else if equal(left, "Kd") {
            mat.diffuse_color = mtl_parse_color_line(right);
        } else if equal(left, "Ks") {
            mat.specular_color = mtl_parse_color_line(right);
        } else if equal(left, "d") {
            mat.alpha = string_to_float(right);
        } else if equal(left, "illum") {
            mat.illum = string_to_int(right, 10, u32);
        } else if equal(left, "map_Ka") {
            mat.texture_map_files[Mesh_Texture_Type.Ambient] = right;
        } else if equal(left, "map_Kd") {
            mat.texture_map_files[Mesh_Texture_Type.Diffuse] = right;
        } else if equal(left, "map_Ks") {
            mat.texture_map_files[Mesh_Texture_Type.Specular] = right;
        } else if equal(left, "map_Ns") {
            // obj calls this the specular highlight map
            mat.texture_map_files[Mesh_Texture_Type.Shininess] = right;
        } else if equal(left, "map_d") {
            // obj calls this the alpha map
            mat.texture_map_files[Mesh_Texture_Type.Opacity] = right;
        } else if equal(left, "map_bump") || equal(left, "bump") {
            mat.texture_map_files[Mesh_Texture_Type.Normal] = right;
        }
    }
    
    // FOR MORE INFO:
    // Here is a full spec of MTL file:
    // https://paulbourke.net/dataformats/mtl/
    
}





mtl_load :: (data: *u8, data_size: u64) -> Mesh_Material {
    
    mat: Mesh_Material = .{};
    line_builder: String_Builder = .{};
    c := <<(data);
    size := data_size;
    while size > 0 {
        while true {
            c = <<consume_data(*data, u8);
            size -= 1;
            if c == 0x0a break;
            append(*line_builder, c);
            if size == 0 break;
            
        }
        
        line:string = builder_to_string(*line_builder);
        
        mtl_parse_line(line, *mat);
        
        if size == 0 break;
    }
    
    return mat;
}






