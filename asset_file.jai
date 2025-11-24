// TODO: Add versioning to the individual asset files.

// NOTE(justin): This file is meant to be #load-ed into asset_builder.jai
// as it still depends on some of those types.




//NOTE(justin): has to be u32 because currently being read by cpp file that assumes a definition
// MATCHES WITH: assets.h (enum of the same name)
Asset_Type :: enum u32 {
    // NOTE: NONE is a legacy value that has to be there
    // because the following values are serialized in the engine as values
    // that are used to compute the Asset_Key type.
    // Cannot be altered until we do a full transformation in the engine
    // as well.
    NONE            :: 0;
    Sprite          :: 1;
    Sound           :: 2;
    Font            :: 3;
    Shader          :: 4;
    Model           :: 5;
    Texture         :: 6;
    Material        :: 7;
    Animation_Graph :: 8;
    Asset_Details   :: 9;
    Animation       :: 10;
};

asset_types :: #run enum_values_as_enum(Asset_Type);
ASSET_TYPE_COUNT :: #run enum_values_as_enum(Asset_Type).count;

three_letter_asset_type_code :: (asset_type:Asset_Type) -> string {
    if (asset_type == .Sprite) {
        return "sprt";
    } else if (asset_type == .Sound) {
        return "sndd";
    } else if (asset_type == .Font) {
        return "font";
    } else if (asset_type == .Shader) {
        return "shdr";
    } else if (asset_type == .Model) {
        return "modl";
    } else if (asset_type == .Texture) {
        return "txtr";
    } else if (asset_type == .Material) {
        return "mtrl";
    } else if (asset_type == .Animation_Graph) {
        return "agph";
    } else if (asset_type == .Asset_Details) {
        return "dtls";
    } else if (asset_type == .Animation) {
        return "anim";
    }
    invalid_code_path("three_letter_asset_type_code: Unimplemented Asset Type");
    return "";
}


make_filename :: (asset_id: string, type: Asset_Type) -> string {
    filename := sprint("../resources/%_%.%", three_letter_asset_type_code(type), asset_id, "sj5k_asset");
    return filename;
}



SJ_Header :: struct {
    code:                  u32; // magic number to check file format
    asset_count:           u32;
    sprite_count:          u32;
    sound_count:           u32;
    font_count:            u32;
    model_count:           u32;
    texture_count:         u32;
    material_count:        u32;
    animation_graph_count: u32;
    asset_details_count:   u32;
    shader_count:          u32;
}  


SJ_Asset_Header :: struct {
    type:                 Asset_Type;
    asset_id:             [128]u8;
    size_bytes:           u32;
    track_filename_count: u32;
} 

SJ_Track_Filename :: struct {
    filename: [128]u8;
}


SJ_Texture_Info :: struct {
    width:    u32;
    height:   u32;
}


SJ_Sprite_Info :: struct {
    texture_id: [128]u8;
    uv:         Rect;
    width:      u32;
    height:     u32;
} 

SJ_Sound_Info :: struct {
    bytes_per_sample:   u32;
    samples_per_second: u32;
    channels:           u32;
    size_bytes:         u32;
} 

SJ_Font_Glyph_Info :: struct {
    value:        u8;
    atlas_uv:     Rect;
    size:         V2;
    rect:         Rect;
    advance:      f32;
    left_padding: f32;
    kerning:      [128]f32;
} 

SJ_Font_Info :: struct {
    asset_id:    [128]u8;
    texture_id:  [128]u8;
    pixel_size:  u32;
    height:      f32;
    line_height: f32;
    ascent:      f32;
    descent:     f32;
    line_gap:    f32;
    glyph_count: u32;
} 


SJ_Mesh_Info :: struct {
    name:           [128]u8;
    triangle_count: u32;
    mesh_to_world:  Matrix4;
    world_to_mesh:  Matrix4;
    material_count: u32;
    material_ids:   [4][128]u8;
}

SJ_Material_Info :: struct {
    name:            [128]u8;
    ambient_color:   Color;
    diffuse_color:   Color;
    specular_color:  Color;
    shininess:       f32;
    alpha:           f32;
    illum:           u32;
    texture_map_ids: [Mesh_Texture_Type.Count][128]u8;
}

SJ_Model_Info :: struct {
    mesh_count:                u32;
    triangle_count:            u32;
    vertex_count:              u32; 
    skeleton_count:            u32;
    bone_count:                u32;
    animation_count:           u32;
    frame_count:               u32;
    animation_transform_count: u32;
    animation_graph_id:        [128]u8;
    asset_details_id:          [128]u8;
}

// NOTE this should match the Vertex_Skinned struct from the engine's platform.h file.
SJ_Mesh_Vertex :: struct {
    object_id:    u32;
    point:        V3;
    uv:           V2;
    normal:       V3;
    color:        u32;
    bone_ids:     [4]u32;
    bone_weights: [4]f32;
}

SJ_Bone_Info :: struct {
    id:           u32;
    position:     V3;
    rotation:     Quat;
    scale:        V3;
    local:        Matrix4;
    global:       Matrix4;
    inverse_bind: Matrix4;
    child_count:  u32;
}

SJ_Animation_Info :: struct {
    name:        [128]u8;
    time:        f32;
    frame_count: u32;
}

SJ_Animation_Frame_Info :: struct {
    mesh_transform_count: u32;
    bone_transform_count: u32;
}

SJ_Animation_Graph_Info :: struct {
    state_count:   u32; 
    initial_state: s32;
}

SJ_Animation_Graph_State_Info :: struct {
    name:            [32]u8;
    animation_name:  [128]u8;
    next_state:      u32;
    looping:         bool;
    start_time:      f32;
    stop_time:       f32;
}


SJ_Asset_Details_Info :: struct {
    name:         [128]u8;
    detail_count: u32;
}


SJ_Shader_Input_Info :: struct {
    semantic_name:  [128]u8;
    type:           Shader_Input_Type;
    semantic_index: u16;
}

SJ_Shader_Input_Layout_Info :: struct {
    vertex_type: Shader_Vertex_Type;
    input_count: u8;
}

SJ_Shader_Info :: struct {
    name: [128]u8;
    vert: bool;
    frag: bool;
}





SJ_Asset_Single_File_Data :: struct {
    data:      *u8;
    data_size: u32;
    filename:  string;
};

SJ_Asset_File_Datas :: struct {
    datas :[ASSET_TYPE_COUNT][..]SJ_Asset_Single_File_Data;
}


size_of_track_filenames :: inline (asset_info: *Asset_Info) -> u32{
    size : u32 = 0;
    size += xx (asset_info.track_filenames.count * size_of(SJ_Track_Filename));
    return size;
}

write_asset_track_filenames :: (filenames: []string, data: **u8) {
    for filenames {
        track_filename := consume_data(data, SJ_Track_Filename);
        copy_string_to_u8_array(track_filename.filename, it);
    }
}



write_sj_asset_sprite :: (sprite: *Sprite, asset_info: *Asset_Info) -> SJ_Asset_Single_File_Data {
    
    file_data:           = SJ_Asset_Single_File_Data.{};
    file_data.filename   = make_filename(asset_info.id, .Sprite);
    file_data.data_size  = size_of(SJ_Asset_Header) + size_of(SJ_Sprite_Info);
    file_data.data_size += size_of_track_filenames(asset_info);
    
    file_data.data = xx alloc(file_data.data_size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:           = consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Sprite;
    asset_header.size_bytes = file_data.data_size;
    copy_string_to_u8_array(asset_header.asset_id, asset_info.id);
    
    info:       = consume_data(data, SJ_Sprite_Info);
    info.uv     = sprite.uv;
    info.width  = sprite.texture.width;
    info.height = sprite.texture.height;
    copy_string_to_u8_array(info.texture_id, sprite.atlas_texture_id);
    
    asset_header.track_filename_count = xx asset_info.track_filenames.count;
    write_asset_track_filenames(asset_info.track_filenames, data);
    
    return file_data;
}





write_sj_asset_sound :: (sound: *Sound, asset_info: *Asset_Info) -> SJ_Asset_Single_File_Data {
    
    file_data:           = SJ_Asset_Single_File_Data.{};
    file_data.filename   = make_filename(asset_info.id, .Sound);
    file_data.data_size  = size_of(SJ_Asset_Header) + size_of(SJ_Sound_Info);
    file_data.data_size += sound.size;
    file_data.data_size += size_of_track_filenames(asset_info);
    
    file_data.data = xx alloc(file_data.data_size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:           = consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Sound;
    asset_header.size_bytes = file_data.data_size;
    copy_string_to_u8_array(asset_header.asset_id, asset_info.id);
    
    info:= consume_data(data, SJ_Sound_Info);
    info.bytes_per_sample   = sound.bytesPerSample;
    info.samples_per_second = sound.samplesPerSecond;
    info.channels           = sound.channels;
    info.size_bytes         = sound.size;
    
    sample_size: u32 = info.bytes_per_sample * info.channels;
    samples:     u32 = info.size_bytes / sample_size;
    
    for sample: 0..samples-1 {
        for channel: 0..info.channels-1 {
            index:u32  = (sample * info.channels) + channel;
            dest_snd:  = consume_data(data, s16);
            <<dest_snd = <<(sound.data + index);
        }
    }
    
    asset_header.track_filename_count = xx asset_info.track_filenames.count;
    write_asset_track_filenames(asset_info.track_filenames, data);
    
    return file_data;
}


write_sj_asset_font_set :: (font_set: *Font_Set, asset_info: *Asset_Info) -> SJ_Asset_Single_File_Data {
    
    file_data:          = SJ_Asset_Single_File_Data.{};
    file_data.filename  = make_filename(asset_info.id, .Font);
    file_data.data_size = size_of(SJ_Asset_Header);
    file_data.data_size += size_of(u32); // font count.
    for font_set.fonts {
        file_data.data_size += size_of(SJ_Font_Info);
        file_data.data_size += cast(u32)(size_of(SJ_Font_Glyph_Info) * it.glyphs.count);
    }
    file_data.data_size += size_of_track_filenames(asset_info);
    
    file_data.data = xx alloc(file_data.data_size);
    data_base     := file_data.data;
    data          := *data_base;
    
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Font;
    asset_header.size_bytes = file_data.data_size;
    copy_string_to_u8_array(asset_header.asset_id, asset_info.id);
    
    font_count := consume_data(data, u32);
    <<font_count = xx font_set.fonts.count;
    
    for *font: font_set.fonts {
        
        info := consume_data(data, SJ_Font_Info);
        info.pixel_size   = font.pixel_size;
        info.height       = font.height;
        info.line_height  = font.line_height;
        info.ascent       = font.ascent;
        info.descent      = font.descent;
        info.line_gap     = font.line_gap;
        info.glyph_count  = xx font_set.glyph_set.count;
        copy_string_to_u8_array(info.asset_id, font.id);
        copy_string_to_u8_array(info.texture_id, font_set.atlas_texture_id);
        
        
        for code: font_set.glyph_set {
            
            src_glyph := font.glyphs[code - MIN_FONT_GLYPH];
            dest_glyph := consume_data(data, SJ_Font_Glyph_Info);
            
            dest_glyph.value        = src_glyph.value;
            dest_glyph.atlas_uv     = src_glyph.atlas_uv;
            dest_glyph.rect         = src_glyph.rect;
            dest_glyph.advance      = src_glyph.advance;
            for k_code: MIN_FONT_GLYPH .. MAX_FONT_GLYPH {
                k_index: = k_code - MIN_FONT_GLYPH;
                c_index: = code - MIN_FONT_GLYPH;
                dest_glyph.kerning[k_index] = font.kerning[c_index][k_index];
            }
        }
        
    }
    
    asset_header.track_filename_count = xx asset_info.track_filenames.count;
    write_asset_track_filenames(asset_info.track_filenames, data);
    
    return file_data;
}


write_sj_asset_texture :: (texture: *Texture, asset_info: *Asset_Info) -> SJ_Asset_Single_File_Data {
    
    
    file_data:           = SJ_Asset_Single_File_Data.{};
    file_data.filename   = make_filename(asset_info.id, .Texture);
    file_data.data_size  = size_of(SJ_Asset_Header) + size_of(SJ_Texture_Info);
    image_pixel_count:   = cast(u32)texture.width * cast(u32)texture.height;
    file_data.data_size += xx (size_of(Pixel) * image_pixel_count);
    file_data.data_size += size_of_track_filenames(asset_info);
    
    file_data.data = xx alloc(file_data.data_size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Texture;
    asset_header.size_bytes = file_data.data_size;
    copy_string_to_u8_array(asset_header.asset_id, asset_info.id);
    
    texture_info := consume_data(data, SJ_Texture_Info);
    texture_info.width  = texture.width;
    texture_info.height = texture.height;
    
    
    pixel_count: = cast(u32)texture_info.width * cast(u32)texture_info.height;
    
    for pixel_index: 0 .. pixel_count-1 {
        dest_pixel: = consume_data(data, Pixel);
        src_pixel: = texture.pixels + pixel_index;
        <<dest_pixel = <<src_pixel;
    }
    
    asset_header.track_filename_count = xx asset_info.track_filenames.count;
    write_asset_track_filenames(asset_info.track_filenames, data);
    
    return file_data;
}


write_sj_asset_model :: (model: *Model, asset_info: *Asset_Info) -> SJ_Asset_Single_File_Data {
    
    file_data:           = SJ_Asset_Single_File_Data.{};
    file_data.filename   = make_filename(asset_info.id, .Model);
    file_data.data_size  = size_of(SJ_Asset_Header) + size_of(SJ_Model_Info);
    
    for mesh: model.meshes {
        file_data.data_size += size_of(SJ_Mesh_Info);
        file_data.data_size += cast(u32)mesh.triangles.count * (size_of(SJ_Mesh_Vertex) * 3);
    }
    
    size_of_bone :: (bone: *Bone) -> u32 {
        size := cast(u32)size_of(SJ_Bone_Info);
        for bone.children {
            size += size_of_bone(it);
        }
        return size;
    }
    
    for root_bone: model.skeletons {
        file_data.data_size += size_of_bone(root_bone);
    }
    
    for animation: model.animations {
        file_data.data_size += size_of(SJ_Animation_Info);
        for frame: animation.frames {
            file_data.data_size += size_of(f32); // the frame time.
            file_data.data_size += size_of(SJ_Animation_Frame_Info);
            file_data.data_size += size_of(Animation_Transform) * cast(u32)frame.mesh_transforms.count;
            file_data.data_size += size_of(Animation_Transform) * cast(u32)frame.bone_transforms.count;
        }
    }
    
    file_data.data_size += size_of_track_filenames(asset_info);
    
    
    
    
    file_data.data = xx alloc(file_data.data_size);
    data_base     := file_data.data;
    data          := *data_base;
    
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type                 = .Model;
    asset_header.size_bytes           = file_data.data_size;
    copy_string_to_u8_array(asset_header.asset_id, asset_info.id);
    
    model_info := consume_data(data, SJ_Model_Info);
    model_info.mesh_count = xx model.meshes.count;
    
    model_info.triangle_count            = 0;
    model_info.vertex_count              = 0;
    model_info.skeleton_count            = xx model.skeletons.count;
    model_info.bone_count                = model.bone_count;
    model_info.animation_count           = xx model.animations.count;
    model_info.frame_count               = 0;
    model_info.animation_transform_count = 0;
    copy_string_to_u8_array(model_info.animation_graph_id, model.animation_graph_id);
    copy_string_to_u8_array(model_info.asset_details_id, model.asset_details_id);
    
    
    for mesh: model.meshes {
        
        info:= consume_data(data, SJ_Mesh_Info);
        info.mesh_to_world  = mesh.mesh_to_world;
        info.world_to_mesh  = mesh.world_to_mesh;
        copy_string_to_u8_array(info.name, mesh.name);
        
        info.triangle_count = cast(u32)mesh.triangles.count;
        
        model_info.triangle_count += info.triangle_count;
        model_info.vertex_count   += info.triangle_count * 3;
        
        for *tri: mesh.triangles {
            
            v1 := consume_data(data, SJ_Mesh_Vertex);
            v2 := consume_data(data, SJ_Mesh_Vertex);
            v3 := consume_data(data, SJ_Mesh_Vertex);
            
            v1.point = mesh.vertices[tri.v1.vertex_index];
            v2.point = mesh.vertices[tri.v2.vertex_index];
            v3.point = mesh.vertices[tri.v3.vertex_index];
            
            if tri.v1.uv_index >= 0 {
                v1.uv = mesh.uvs[tri.v1.uv_index];
                v2.uv = mesh.uvs[tri.v2.uv_index];
                v3.uv = mesh.uvs[tri.v3.uv_index];
            }
            if tri.v1.normal_index >= 0 {
                v1.normal = mesh.normals[tri.v1.normal_index];
                v2.normal = mesh.normals[tri.v2.normal_index];
                v3.normal = mesh.normals[tri.v3.normal_index];
            }
            
            if tri.v1.bone_count > 0 {
                for 0 .. 3 {
                    v1.bone_ids[it]     = tri.v1.bone_ids[it];
                    v1.bone_weights[it] = tri.v1.bone_weights[it];
                }
            }
            if tri.v2.bone_count > 0 {
                for 0 .. 3 {
                    v2.bone_ids[it]     = tri.v2.bone_ids[it];
                    v2.bone_weights[it] = tri.v2.bone_weights[it];
                }
            }
            if tri.v3.bone_count > 0 {
                for 0 .. 3 {
                    v3.bone_ids[it]     = tri.v3.bone_ids[it];
                    v3.bone_weights[it] = tri.v3.bone_weights[it];
                }
            }
            
            v1.color = 0xFFFFFFFF;
            v2.color = 0xFFFFFFFF;
            v3.color = 0xFFFFFFFF;
        }
        
        info.material_count = 0;
        for mesh.material_names {
            copy_string_to_u8_array(info.material_ids[it_index], it);
            
            info.material_count += 1;
            if info.material_count == 4 break;
        }
        
    }
    
    
    write_bone_info :: (data: **u8, bone: *Bone) {
        bone_info := consume_data(data, SJ_Bone_Info);
        bone_info.id           = bone.id;
        bone_info.position     = bone.position;
        bone_info.rotation     = bone.rotation;
        bone_info.scale        = bone.scale;
        bone_info.local        = bone.local;
        bone_info.global       = bone.global;
        bone_info.inverse_bind = bone.inverse_bind;
        bone_info.child_count  = xx bone.children.count;
        
        for bone.children {
            write_bone_info(data, it);
        }
    }
    
    for root_bone: model.skeletons {
        write_bone_info(data, root_bone);
    }
    
    
    
    for animation: model.animations {
        anim_info := consume_data(data, SJ_Animation_Info);
        // TODO maybe an animation can have a name somehow.
        copy_string_to_u8_array(anim_info.name, animation.name);
        anim_info.time = animation.time;
        anim_info.frame_count = xx animation.frames.count;
        
        model_info.frame_count += anim_info.frame_count;
        
        for *frame: animation.frames {
            frame_time:  = consume_data(data, f32);
            <<frame_time = animation.frame_times[it_index];
            
            frame_info := consume_data(data, SJ_Animation_Frame_Info);
            frame_info.mesh_transform_count = xx frame.mesh_transforms.count;
            frame_info.bone_transform_count = xx frame.bone_transforms.count;
            
            model_info.animation_transform_count += frame_info.mesh_transform_count;
            model_info.animation_transform_count += frame_info.bone_transform_count;
            
            for frame.mesh_transforms {
                t:  = consume_data(data, Animation_Transform);
                <<t = it;
            }
            for frame.bone_transforms {
                t:  = consume_data(data, Animation_Transform);
                <<t = it;
            }
        }
    }
    
    asset_header.track_filename_count = xx asset_info.track_filenames.count;
    write_asset_track_filenames(asset_info.track_filenames, data);
    
    return file_data;
}


write_sj_asset_asset_details :: (details: *Asset_Details, asset_info: *Asset_Info) -> SJ_Asset_Single_File_Data {
    
    file_data:           = SJ_Asset_Single_File_Data.{};
    file_data.filename   = make_filename(asset_info.id, .Asset_Details);
    file_data.data_size  = size_of(SJ_Asset_Header) + size_of(SJ_Asset_Details_Info);
    detail_count: u32    = xx details.details.count;
    file_data.data_size += size_of(Asset_Detail) * detail_count;
    file_data.data_size += size_of_track_filenames(asset_info);
    
    file_data.data = xx alloc(file_data.data_size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Asset_Details;
    asset_header.size_bytes = file_data.data_size;
    copy_string_to_u8_array(asset_header.asset_id, asset_info.id);
    
    details_info := consume_data(data, SJ_Asset_Details_Info);
    details_info.detail_count = detail_count;
    
    for details.details {
        detail_info := consume_data(data, Asset_Detail);
        <<detail_info = it;
    }
    
    asset_header.track_filename_count = xx asset_info.track_filenames.count;
    write_asset_track_filenames(asset_info.track_filenames, data);
    
    return file_data;
    
}

write_sj_asset_animation_graph :: (graph: *Animation_Graph, asset_info: *Asset_Info) -> SJ_Asset_Single_File_Data {
    
    file_data:           = SJ_Asset_Single_File_Data.{};
    file_data.filename   = make_filename(asset_info.id, .Animation_Graph);
    file_data.data_size  = size_of(SJ_Asset_Header) + size_of(SJ_Animation_Graph_Info);
    state_count: u32     = xx graph.states.count;
    file_data.data_size += size_of(SJ_Animation_Graph_State_Info) * state_count;
    file_data.data_size += size_of_track_filenames(asset_info);
    
    file_data.data = xx alloc(file_data.data_size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header := consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Animation_Graph;
    asset_header.size_bytes = file_data.data_size;
    copy_string_to_u8_array(asset_header.asset_id, asset_info.id);
    
    anim_graph_info := consume_data(data, SJ_Animation_Graph_Info);
    anim_graph_info.state_count   = state_count;
    anim_graph_info.initial_state = xx graph.initial_state;
    for *state: graph.states {
        state_info := consume_data(data, SJ_Animation_Graph_State_Info);
        copy_string_to_u8_array(state_info.name, state.name);
        copy_string_to_u8_array(state_info.animation_name, state.animation_name);
        state_info.next_state      = xx state.next_state_index;
        state_info.looping         = state.looping;
        state_info.start_time      = state.start_time;
        state_info.stop_time       = state.stop_time;
    }
    
    asset_header.track_filename_count = xx asset_info.track_filenames.count;
    write_asset_track_filenames(asset_info.track_filenames, data);
    
    return file_data;
    
}


write_sj_asset_material :: (material: *Mesh_Material, asset_info: *Asset_Info) -> SJ_Asset_Single_File_Data {
    
    file_data:           = SJ_Asset_Single_File_Data.{};
    file_data.filename   = make_filename(asset_info.id, .Material);
    file_data.data_size  = size_of(SJ_Asset_Header) + size_of(SJ_Material_Info);
    file_data.data_size += size_of_track_filenames(asset_info);
    
    
    file_data.data = xx alloc(file_data.data_size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Material;
    asset_header.size_bytes = file_data.data_size;
    copy_string_to_u8_array(asset_header.asset_id, asset_info.id);
    
    
    material_info := consume_data(data, SJ_Material_Info);
    copy_string_to_u8_array(material_info.name, asset_info.id);
    material_info.ambient_color  = material.ambient_color;
    material_info.diffuse_color  = material.diffuse_color;
    material_info.specular_color = material.specular_color;
    material_info.shininess      = material.shininess;
    material_info.alpha          = material.alpha;
    material_info.illum          = material.illum;
    
    for 0 .. Mesh_Texture_Type.Count - 1 {
        texture_map_id := material.texture_map_ids[it];
        if texture_map_id.count > 0 {
            copy_string_to_u8_array(material_info.texture_map_ids[it], texture_map_id);
        }
    }
    
    asset_header.track_filename_count = xx asset_info.track_filenames.count;
    write_asset_track_filenames(asset_info.track_filenames, data);
    
    return file_data;
    
}


write_sj_asset_shader :: (shader: *Shader, asset_info: *Asset_Info) -> SJ_Asset_Single_File_Data {
    
    file_data:           = SJ_Asset_Single_File_Data.{};
    file_data.filename   = make_filename(asset_info.id, .Shader);
    file_data.data_size  = size_of(SJ_Asset_Header) + size_of(SJ_Shader_Info);
    file_data.data_size += size_of(SJ_Shader_Input_Layout_Info);
    file_data.data_size += xx (size_of(SJ_Shader_Input_Info) * cast(s64)shader.input_layout.input_count);
    file_data.data_size += size_of(u32); // code size.
    file_data.data_size += xx shader.code.count;
    file_data.data_size += size_of_track_filenames(asset_info);
    
    
    file_data.data = xx alloc(file_data.data_size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Shader;
    asset_header.size_bytes = file_data.data_size;
    copy_string_to_u8_array(asset_header.asset_id, asset_info.id);
    
    shader_info := consume_data(data, SJ_Shader_Info);
    copy_string_to_u8_array(shader_info.name, shader.name);
    shader_info.vert = shader.vert;
    shader_info.frag = shader.frag;
    
    layout_info := consume_data(data, SJ_Shader_Input_Layout_Info);
    layout_info.vertex_type = shader.input_layout.vertex_type;
    layout_info.input_count = shader.input_layout.input_count;
    
    if layout_info.input_count > 0 {
        for 0 .. layout_info.input_count - 1 {
            input_info: = consume_data(data, SJ_Shader_Input_Info);
            input:      = shader.input_layout.inputs[it];
            
            copy_string_to_u8_array(input_info.semantic_name, input.semantic_name);
            input_info.type           = input.type;
            input_info.semantic_index = input.semantic_index;
        }
    }
    
    code_size := consume_data(data, u32);
    <<code_size = xx shader.code.count;
    
    dst_code := consume_data_size(data, xx shader.code.count);
    copy_data(dst_code, shader.code.data, xx shader.code.count);
    
    asset_header.track_filename_count = xx asset_info.track_filenames.count;
    write_asset_track_filenames(asset_info.track_filenames, data);
    
    assert(data_base - file_data.data == file_data.data_size);
    
    return file_data;
    
}






write_single_file :: (file_data: *SJ_Asset_Single_File_Data) {
    delete_file(file_data.filename);
    written := write_file(file_data.filename, file_data.data, file_data.data_size);
}




save_final_assets :: (asset_data: *Asset_Data, bundle: bool, single_files: bool) -> SJ_Asset_File_Datas {
    
    
    leak_report := make_leak_report();
    for leak_report.sorted_summaries print("** summary %: **\n%\n", it_index, <<it);
    log_leak_report(leak_report);
    
    
    print("preparing save\n");
    
    
    file_datas: SJ_Asset_File_Datas = .{};
    
    size_of_models:           u32;
    size_of_textures:         u32;
    size_of_asset_details:    u32;
    size_of_animation_graphs: u32;
    size_of_materials:        u32;
    size_of_sprites:          u32;
    size_of_sounds:           u32;
    size_of_fonts:            u32;
    size_of_shaders:          u32;
    
    using asset_data;
    
    for * assets.textures {
        info := table_find_pointer(*asset_infos[Asset_Type.Texture], it_index);
        file_data := write_sj_asset_texture(it, info);
        if single_files write_single_file(*file_data);
        size_of_textures += file_data.data_size;
        array_add(*file_datas.datas[Asset_Type.Texture], file_data);
    }
    
    for * assets.asset_details {
        info := table_find_pointer(*asset_infos[Asset_Type.Asset_Details], it_index);
        file_data := write_sj_asset_asset_details(it, info);
        if single_files write_single_file(*file_data);
        size_of_asset_details += file_data.data_size;
        array_add(*file_datas.datas[Asset_Type.Asset_Details], file_data);
    }
    
    for * assets.animation_graphs {
        info := table_find_pointer(*asset_infos[Asset_Type.Animation_Graph], it_index);
        file_data := write_sj_asset_animation_graph(it, info);
        if single_files write_single_file(*file_data);
        size_of_animation_graphs += file_data.data_size;
        array_add(*file_datas.datas[Asset_Type.Animation_Graph], file_data);
    }
    
    for * assets.sprites {
        info := table_find_pointer(*asset_infos[Asset_Type.Sprite], it_index);
        file_data := write_sj_asset_sprite(it, info);
        if single_files write_single_file(*file_data);
        size_of_sprites += file_data.data_size;
        array_add(*file_datas.datas[Asset_Type.Sprite], file_data);
    }
    
    
    for * assets.sounds {
        info := table_find_pointer(*asset_infos[Asset_Type.Sound], it_index);
        file_data := write_sj_asset_sound(it, info);
        if single_files write_single_file(*file_data);
        size_of_sounds += file_data.data_size;
        array_add(*file_datas.datas[Asset_Type.Sound], file_data);
    }
    
    
    
    for * assets.font_sets {
        info := table_find_pointer(*asset_infos[Asset_Type.Font], it_index);
        file_data := write_sj_asset_font_set(it, info);
        if single_files write_single_file(*file_data);
        size_of_fonts += file_data.data_size;
        array_add(*file_datas.datas[Asset_Type.Font], file_data);
    }
    
    
    for * assets.materials {
        info := table_find_pointer(*asset_infos[Asset_Type.Material], it_index);
        file_data := write_sj_asset_material(it, info);
        if single_files write_single_file(*file_data);
        size_of_materials += file_data.data_size;
        array_add(*file_datas.datas[Asset_Type.Material], file_data);
    }
    
    for * assets.models {
        info := table_find_pointer(*asset_infos[Asset_Type.Model], it_index);
        file_data := write_sj_asset_model(it, info);
        if single_files write_single_file(*file_data);
        size_of_models += file_data.data_size;
        array_add(*file_datas.datas[Asset_Type.Model], file_data);
    }
    
    
    for * assets.shaders {
        info := table_find_pointer(*asset_infos[Asset_Type.Shader], it_index);
        file_data := write_sj_asset_shader(it, info);
        if single_files write_single_file(*file_data);
        size_of_shaders += file_data.data_size;
        array_add(*file_datas.datas[Asset_Type.Shader], file_data);
    }
    
    
    
    total_size:u32 = 
        size_of(SJ_Header) + 
        size_of_sprites + 
        size_of_sounds + 
        size_of_fonts + 
        size_of_models + 
        size_of_textures + 
        size_of_animation_graphs + 
        size_of_asset_details +
        size_of_materials + 
        size_of_shaders;
    
    
    if bundle {
        bundle_data: *u8 = xx alloc(total_size);
        bundle_data_start := bundle_data;
        defer free(bundle_data_start);
        
        header:= consume_data(*bundle_data, SJ_Header);
        header.code                  = magic_number("sj5k");
        header.asset_count           = 0;
        header.sprite_count          = 0;
        header.sound_count           = 0;
        header.font_count            = 0;
        header.model_count           = 0;
        header.texture_count         = 0;
        header.material_count        = 0;
        header.animation_graph_count = 0;
        header.asset_details_count   = 0;
        header.shader_count          = 0;
        
        // NOTE: Write data in depedency order.
        
        // Many things depend on textures.
        for data: file_datas.datas[Asset_Type.Texture] {
            if data.data_size == 0 continue;
            texture_data := consume_data_size(*bundle_data, data.data_size);
            copy_data(texture_data, data.data, data.data_size);
            
            header.texture_count += 1;
            header.asset_count   += 1;
            
        }
        
        for data: file_datas.datas[Asset_Type.Animation_Graph] {
            if data.data_size == 0 continue;
            animation_graph_data := consume_data_size(*bundle_data, data.data_size);
            copy_data(animation_graph_data, data.data, data.data_size);
            header.animation_graph_count += 1;
            header.asset_count += 1;
        }
        
        for data: file_datas.datas[Asset_Type.Asset_Details] {
            if data.data_size == 0 continue;
            asset_details_data := consume_data_size(*bundle_data, data.data_size);
            copy_data(asset_details_data, data.data, data.data_size);
            header.asset_details_count += 1;
            header.asset_count += 1;
        }
        
        for data: file_datas.datas[Asset_Type.Sprite] {
            if data.data_size == 0 continue; // WIERD.
            atlas_data := consume_data_size(*bundle_data, data.data_size);
            copy_data(atlas_data, data.data, data.data_size);
            
            header.sprite_count += 1;
            header.asset_count += 1;
        }
        
        for data: file_datas.datas[Asset_Type.Sound] {
            if data.data_size == 0 continue; // WIERD.
            sound_data := consume_data_size(*bundle_data, data.data_size);
            copy_data(sound_data, data.data, data.data_size);
            
            header.sound_count += 1;
            header.asset_count += 1;
        }
        
        for data: file_datas.datas[Asset_Type.Font] {
            if data.data_size == 0 continue; // WIERD.
            font_data := consume_data_size(*bundle_data, data.data_size);
            copy_data(font_data, data.data, data.data_size);
            
            header.font_count  += 1;
            header.asset_count += 1;
        }
        
        // Models (meshes) depend on materials
        for data: file_datas.datas[Asset_Type.Material] {
            if data.data_size == 0 continue;
            material_data := consume_data_size(*bundle_data, data.data_size);
            copy_data(material_data, data.data, data.data_size);
            
            header.material_count += 1;
            header.asset_count    += 1;
            
        }
        
        for data: file_datas.datas[Asset_Type.Model] {
            if data.data_size == 0 continue;
            model_data := consume_data_size(*bundle_data, data.data_size);
            copy_data(model_data, data.data, data.data_size);
            
            header.model_count += 1;
            header.asset_count += 1;
            
        }
        
        for data: file_datas.datas[Asset_Type.Shader] {
            if data.data_size == 0 continue;
            shader_data := consume_data_size(*bundle_data, data.data_size);
            copy_data(shader_data, data.data, data.data_size);
            
            header.shader_count += 1;
            header.asset_count  += 1;
            
        }
        
        asset_bundle_filename := "../resources/asset_bundle_0_3_0.sj5k";
        delete_file(asset_bundle_filename);
        written := write_file(asset_bundle_filename, cast(*void)bundle_data_start, total_size);
        
    }
    
    return file_datas;
    
}

