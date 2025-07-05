// TODO: Add versioning to the individual asset files.

// NOTE(justin): This file is meant to be #load-ed into asset_builder.jai
// as it still depends on some of those types.




//NOTE(justin): has to be u32 because currently being read by cpp file that assumes a definition
// MATCHES WITH: assets.h (enum of the same name)
Asset_Type :: enum u32 {
    None         :: 0;
    Sprite       :: 1;
    Sound        :: 2;
    Font         :: 3;
    Shader       :: 4;
    Model        :: 5;
    Texture      :: 6;
    Material     :: 7;
};



SJ_Header :: struct {
    code:           u32; // magic number to check file format
    asset_count:    u32;
    sprite_count:   u32;
    sound_count:    u32;
    font_count:     u32;
    model_count:    u32;
    texture_count:  u32;
    material_count: u32;
}  


SJ_Asset_Header :: struct {
    type: Asset_Type;
    size_bytes: u32;
    track_filename_count: u32;
} 

SJ_Track_Filename :: struct {
    filename: [128]u8;
}


SJ_Texture_Info :: struct {
    asset_id: [128]u8;
    width:    u32;
    height:   u32;
}


SJ_Sprite_Info :: struct {
    asset_id:   [128]u8;
    texture_id: [128]u8;
    uv:         Rect;
    width:      u32;
    height:     u32;
} 

SJ_Sound_Info :: struct {
    asset_id:           [128]u8;
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
    asset_id:       [128]u8;
    triangle_count: u32;
    mesh_to_world:  Matrix4;
    world_to_mesh:  Matrix4;
    material_count: u32;
    material_ids:   [4][128]u8;
}

SJ_Material_Info :: struct {
    asset_id:        [128]u8;
    ambient_color:   Color;
    diffuse_color:   Color;
    specular_color:  Color;
    shininess:       f32;
    alpha:           f32;
    illum:           u32;
    texture_map_ids: [Mesh_Texture_Type.Count][128]u8;
}

SJ_Model_Info :: struct {
    asset_id:          [128]u8;
    mesh_count:        u32;
    skeleton_count:    u32;
    bone_count:        u32;
    animation_count:   u32;
    asset_translation: V3;
    asset_rotation:    V3;
    asset_scale:       V3;
}

// NOTE this should match the Vertex_Skinned struct from the engine's platform.h file.
SJ_Mesh_Vertex :: struct {
    object_id:    u32;
    point:        V3;
    uv:           V2;
    normal:       V3;
    color:        u32;
    bone_count:   u32;
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
    animation_index: u8;
    next_state:      u32;
    looping:         bool;
    start_time:      f32;
    stop_time:       f32;
}


SJ_Asset_Single_File_Data :: struct {
    data: *u8;
    size: u32;
};

SJ_Asset_File_Datas :: struct {
    model_datas    :[..]SJ_Asset_Single_File_Data;
    texture_datas  :[..]SJ_Asset_Single_File_Data;
    material_datas :[..]SJ_Asset_Single_File_Data;
    sprite_datas   :[..]SJ_Asset_Single_File_Data;
    sound_datas    :[..]SJ_Asset_Single_File_Data;
    font_datas     :[..]SJ_Asset_Single_File_Data;
}

SJ_Asset_Single_File_Info :: struct {
    asset_id: [128]u8;
    type:     Asset_Type;
    filename: [256]u8;
    track_filename_count: u32;
}



copy_string_to_u8_array :: (dest: []u8, src: string) {
    assert(src.count < 128);
    for i: 0 .. src.count-1 {
        c: u8 = src.data[i];
        dest.data[i] = c;
    }
    dest[src.count] = #char "\0";
}



write_asset_track_filenames :: (resource: *Resource_Base, data: **u8) {
    
    if resource.track_filenames.count > 0 {
        for 0 .. resource.track_filenames.count - 1 {
            track_file := consume_data(data, SJ_Track_Filename);
            copy_string_to_u8_array(track_file.filename, resource.track_filenames[it]);
            
        }
    }
}


write_sj_asset_sprite :: (resource: *Resource_Sprite) -> SJ_Asset_Single_File_Data {
    
    file_data:      = SJ_Asset_Single_File_Data.{};
    file_data.size  = size_of(SJ_Asset_Header) + size_of(SJ_Sprite_Info);
    file_data.size += size_of(SJ_Track_Filename) * cast(u32)resource.track_filenames.count;
    
    file_data.data = xx alloc(file_data.size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:           = consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Sprite;
    asset_header.size_bytes = file_data.size;
    asset_header.track_filename_count = xx resource.track_filenames.count;
    
    info:       = consume_data(data, SJ_Sprite_Info);
    info.uv     = resource.uv;
    info.width  = resource.texture.width;
    info.height = resource.texture.height;
    copy_string_to_u8_array(info.asset_id, resource.id);
    copy_string_to_u8_array(info.texture_id, resource.texture_id);
    
    write_asset_track_filenames(resource, data);
    return file_data;
}





write_sj_asset_sound :: (resource: *Resource_Sound) -> SJ_Asset_Single_File_Data {
    
    file_data := SJ_Asset_Single_File_Data.{};
    file_data.size  = size_of(SJ_Asset_Header) + size_of(SJ_Sound_Info);
    file_data.size += resource.snd.size;
    file_data.size += size_of(SJ_Track_Filename) * cast(u32)resource.track_filenames.count;
    
    
    file_data.data = xx alloc(file_data.size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:           = consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Sound;
    asset_header.size_bytes = file_data.size;
    asset_header.track_filename_count = xx resource.track_filenames.count;
    
    info:= consume_data(data, SJ_Sound_Info);
    info.bytes_per_sample   = resource.snd.bytesPerSample;
    info.samples_per_second = resource.snd.samplesPerSecond;
    info.channels           = resource.snd.channels;
    info.size_bytes         = resource.snd.size;
    copy_string_to_u8_array(info.asset_id, resource.id);
    
    sample_size: u32 = info.bytes_per_sample * info.channels;
    samples:     u32 = info.size_bytes / sample_size;
    
    for sample: 0..samples-1 {
        for channel: 0..info.channels-1 {
            index:u32  = (sample * info.channels) + channel;
            dest_snd:  = consume_data(data, s16);
            <<dest_snd = <<(resource.snd.data + index);
        }
    }
    
    write_asset_track_filenames(resource, data);
    
    return file_data;
}


write_sj_asset_font :: (resource: *Resource_Font) -> SJ_Asset_Single_File_Data {
    
    file_data      := SJ_Asset_Single_File_Data.{};
    file_data.size  = size_of(SJ_Asset_Header);
    file_data.size += size_of(SJ_Track_Filename) * cast(u32)resource.track_filenames.count;
    
    file_data.size += size_of(u32);
    for font: resource.fonts {
        file_data.size += size_of(SJ_Font_Info);
        file_data.size += cast(u32)(size_of(SJ_Font_Glyph_Info) * font.glyphs.count);
    }
    
    file_data.data = xx alloc(file_data.size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Font;
    asset_header.size_bytes = file_data.size;
    asset_header.track_filename_count = xx resource.track_filenames.count;
    
    size_count := consume_data(data, u32);
    <<size_count = xx resource.fonts.count;
    
    for font: resource.fonts {
        
        info := consume_data(data, SJ_Font_Info);
        info.pixel_size   = font.pixel_size;
        info.height       = font.height;
        info.line_height  = font.line_height;
        info.ascent       = font.ascent;
        info.descent      = font.descent;
        info.line_gap     = font.line_gap;
        info.glyph_count  = cast(u32)resource.desired_glyphs.count;
        copy_string_to_u8_array(info.asset_id, resource.ids[it_index]);
        copy_string_to_u8_array(info.texture_id, resource.texture_id);
        
        
        for glyph_index: 0 .. info.glyph_count-1 {
            code: = resource.desired_glyphs.data[glyph_index];
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
    
    write_asset_track_filenames(resource, data);
    
    return file_data;
}


write_sj_asset_texture :: (resource: *Resource_Texture) -> SJ_Asset_Single_File_Data {
    
    
    file_data:      = SJ_Asset_Single_File_Data.{};
    file_data.size  = size_of(SJ_Asset_Header) + size_of(SJ_Texture_Info);
    file_data.size += 
        cast(u32)size_of(Pixel) * cast(u32)resource.texture.width * cast(u32)resource.texture.height;
    file_data.size += size_of(SJ_Track_Filename) * cast(u32)resource.track_filenames.count;
    
    file_data.data = xx alloc(file_data.size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Texture;
    asset_header.size_bytes = file_data.size;
    asset_header.track_filename_count = xx resource.track_filenames.count;
    
    texture_info := consume_data(data, SJ_Texture_Info);
    texture_info.width  = resource.texture.width;
    texture_info.height = resource.texture.height;
    copy_string_to_u8_array(texture_info.asset_id, resource.id);
    
    
    pixel_count: = cast(u32)texture_info.width * cast(u32)texture_info.height;
    
    for pixel_index: 0 .. pixel_count-1 {
        dest_pixel: = consume_data(data, Pixel);
        src_pixel: = resource.texture.pixels + pixel_index;
        <<dest_pixel = <<src_pixel;
    }
    
    write_asset_track_filenames(resource, data);
    
    return file_data;
}


write_sj_asset_model :: (resource: *Resource_Model) -> SJ_Asset_Single_File_Data {
    
    file_data      := SJ_Asset_Single_File_Data.{};
    file_data.size  = size_of(SJ_Asset_Header) + size_of(SJ_Model_Info);
    file_data.size += size_of(SJ_Track_Filename) * cast(u32)resource.track_filenames.count;
    
    model := resource.model;
    for mesh: model.meshes {
        file_data.size += size_of(SJ_Mesh_Info);
        file_data.size += cast(u32)mesh.triangles.count * (size_of(SJ_Mesh_Vertex) * 3);
    }
    
    size_of_bone :: (bone: *Bone) -> u32 {
        size := cast(u32)size_of(SJ_Bone_Info);
        for bone.children {
            size += size_of_bone(it);
        }
        return size;
    }
    
    for root_bone: model.skeletons {
        file_data.size += size_of_bone(root_bone);
    }
    
    for animation: model.animations {
        file_data.size += size_of(SJ_Animation_Info);
        for frame: animation.frames {
            file_data.size += size_of(f32); // the frame time.
            file_data.size += size_of(SJ_Animation_Frame_Info);
            file_data.size += size_of(Animation_Transform) * cast(u32)frame.mesh_transforms.count;
            file_data.size += size_of(Animation_Transform) * cast(u32)frame.bone_transforms.count;
        }
    }
    
    file_data.size += size_of(SJ_Animation_Graph_Info);
    for state: model.animation_graph.states {
        file_data.size += size_of(SJ_Animation_Graph_State_Info);
    }
    
    
    file_data.data = xx alloc(file_data.size);
    data_base     := file_data.data;
    data          := *data_base;
    
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type                 = .Model;
    asset_header.size_bytes           = file_data.size;
    asset_header.track_filename_count = xx resource.track_filenames.count;
    
    model_info := consume_data(data, SJ_Model_Info);
    model_info.mesh_count = xx resource.model.meshes.count;
    copy_string_to_u8_array(model_info.asset_id, resource.model.name);
    
    model_info.skeleton_count    = xx resource.model.skeletons.count;
    model_info.bone_count        = resource.model.bone_count;
    model_info.animation_count   = xx resource.model.animations.count;
    model_info.asset_translation = V3.{};
    model_info.asset_rotation    = V3.{};
    model_info.asset_scale       = V3.{x=1,y=1,z=1};
    
    for resource.asset_details.details {
        if it.type == .Translation {
            model_info.asset_translation = V3.{x=it.x,y=it.y,z=it.z};
            
        } else if it.type == .Rotation {
            model_info.asset_rotation = V3.{x=it.x,y=it.y,z=it.z};
            
        } else if it.type == .Scale {
            model_info.asset_scale = V3.{x=it.x,y=it.y,z=it.z};
            
        }
    }
    
    
    for mesh: resource.model.meshes {
        
        info:= consume_data(data, SJ_Mesh_Info);
        info.mesh_to_world  = mesh.mesh_to_world;
        info.world_to_mesh  = mesh.world_to_mesh;
        copy_string_to_u8_array(info.asset_id, mesh.name);
        
        info.triangle_count = cast(u32)mesh.triangles.count;
        
        
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
            
            v1.bone_count = tri.v1.bone_count;
            if v1.bone_count > 0 {
                for 0 .. 3 {
                    v1.bone_ids[it]     = tri.v1.bone_ids[it];
                    v1.bone_weights[it] = tri.v1.bone_weights[it];
                }
            }
            v2.bone_count = tri.v2.bone_count;
            if v2.bone_count > 0 {
                for 0 .. 3 {
                    v2.bone_ids[it]     = tri.v2.bone_ids[it];
                    v2.bone_weights[it] = tri.v2.bone_weights[it];
                }
            }
            v3.bone_count = tri.v3.bone_count;
            if v3.bone_count > 0 {
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
        for mesh.materials {
            copy_string_to_u8_array(info.material_ids[it_index], it.name);
            
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
    
    for root_bone: resource.model.skeletons {
        write_bone_info(data, root_bone);
    }
    
    
    
    for animation: resource.model.animations {
        anim_info := consume_data(data, SJ_Animation_Info);
        // TODO maybe an animation can have a name somehow.
        copy_string_to_u8_array(anim_info.name, animation.name);
        anim_info.time = animation.time;
        anim_info.frame_count = xx animation.frames.count;
        for *frame: animation.frames {
            frame_time:  = consume_data(data, f32);
            <<frame_time = animation.frame_times[it_index];
            
            frame_info := consume_data(data, SJ_Animation_Frame_Info);
            frame_info.mesh_transform_count = xx frame.mesh_transforms.count;
            frame_info.bone_transform_count = xx frame.bone_transforms.count;
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
    
    graph := resource.model.animation_graph;
    anim_graph_info := consume_data(data, SJ_Animation_Graph_Info);
    anim_graph_info.state_count   = xx graph.states.count;
    anim_graph_info.initial_state = xx graph.initial_state;
    for *state: graph.states {
        state_info := consume_data(data, SJ_Animation_Graph_State_Info);
        copy_string_to_u8_array(state_info.name, state.name);
        state_info.animation_index = xx state.animation_index;
        state_info.next_state      = xx state.next_state_index;
        state_info.looping         = state.looping;
        state_info.start_time      = state.start_time;
        state_info.stop_time       = state.stop_time;
    }
    
    write_asset_track_filenames(resource, data);
    
    return file_data;
}



write_sj_asset_material :: (resource: *Resource_Material) -> SJ_Asset_Single_File_Data {
    
    file_data:      = SJ_Asset_Single_File_Data.{};
    file_data.size  = size_of(SJ_Asset_Header) + size_of(SJ_Material_Info);
    file_data.size += size_of(SJ_Track_Filename) * cast(u32)resource.track_filenames.count;
    
    
    file_data.data = xx alloc(file_data.size);
    data_base     := file_data.data;
    data          := *data_base;
    
    asset_header:= consume_data(data, SJ_Asset_Header);
    asset_header.type       = .Material;
    asset_header.size_bytes = file_data.size;
    asset_header.track_filename_count = xx resource.track_filenames.count;
    
    material := resource.material;
    
    material_info := consume_data(data, SJ_Material_Info);
    copy_string_to_u8_array(material_info.asset_id, material.name);
    
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
    
    write_asset_track_filenames(resource, data);
    
    return file_data;
    
}






save_final_assets :: (resources: *Resources, bundle: bool, single_files: bool, single_files_descriptor: bool) {
    
    print("preparing save\n");
    
    
    file_datas: SJ_Asset_File_Datas = .{};
    
    resources_directory := "../resources";
    
    
    size_of_models:    u32;
    size_of_textures:  u32;
    size_of_materials: u32;
    size_of_sprites:   u32;
    size_of_sounds:    u32;
    size_of_fonts:     u32;
    
    
    single_file_infos :[..]SJ_Asset_Single_File_Info;
    add_single_file_info :: (infos: *[..]SJ_Asset_Single_File_Info, 
                             asset_id: string,
                             filename: string, 
                             type: Asset_Type,
                             track_filename_count: u32) {
        info := SJ_Asset_Single_File_Info.{};
        info.type = type;
        info.track_filename_count = track_filename_count;
        copy_string_to_u8_array(info.asset_id, asset_id);
        copy_string_to_u8_array(info.filename, filename);
        array_add(infos, info);
    }
    
    
    // NOTE: Process resource types in dependency order.
    
    for * resources.textures {
        
        texture_file_data := write_sj_asset_texture(it);
        array_add(*file_datas.texture_datas, texture_file_data);
        
        if single_files {
            filename := sprint("%/%.%", resources_directory, it.id, "sj5k_texture");
            delete_file(filename);
            written := write_file(filename, texture_file_data.data, texture_file_data.size);
            
            add_single_file_info(*single_file_infos, it.id, filename, .Texture, xx it.track_filenames.count);
        }
        
        size_of_textures += texture_file_data.size;
    }
    
    
    
    for * resources.sprites {
        
        sprite_file_data := write_sj_asset_sprite(it);
        array_add(*file_datas.sprite_datas, sprite_file_data);
        
        if single_files {
            filename := sprint("%/%.%", resources_directory, it.id, "sj5k_sprite");
            delete_file(filename);
            written := write_file(filename, sprite_file_data.data, sprite_file_data.size);
            
            add_single_file_info(*single_file_infos, it.id, filename, .Sprite, xx it.track_filenames.count);
        }
        
        size_of_sprites += sprite_file_data.size;
    }
    
    
    for * resources.sounds {
        if it.file_type == .Unknown continue;
        
        sound_file_data := write_sj_asset_sound(it);
        array_add(*file_datas.sound_datas, sound_file_data);
        
        if single_files {
            filename := sprint("%/%.%", resources_directory, it.id, "sj5k_sound");
            delete_file(filename);
            written := write_file(filename, sound_file_data.data, sound_file_data.size);
            
            add_single_file_info(*single_file_infos, it.id, filename, .Sound, xx it.track_filenames.count);
        }
        
        size_of_sounds += sound_file_data.size;
    }
    
    
    
    for * resources.fonts {
        
        font_file_data := write_sj_asset_font(it);
        array_add(*file_datas.font_datas, font_file_data);
        
        if single_files {
            filename := sprint("%/%.%", resources_directory, it.id, "sj5k_font");
            delete_file(filename);
            written := write_file(filename, font_file_data.data, font_file_data.size);
            
            add_single_file_info(*single_file_infos, it.id, filename, .Font, xx it.track_filenames.count);
        }
        
        size_of_fonts += font_file_data.size;
    }
    
    
    for * resources.materials {
        
        material_file_data := write_sj_asset_material(it);
        array_add(*file_datas.material_datas, material_file_data);
        
        if single_files {
            filename := sprint("%/%.%", resources_directory, it.id, "sj5k_material");
            delete_file(filename);
            written := write_file(filename, material_file_data.data, material_file_data.size);
            
            add_single_file_info(*single_file_infos, it.id, filename, .Material, xx it.track_filenames.count);
        }
        
        size_of_materials += material_file_data.size;
    }
    
    for * resources.models {
        
        model_file_data := write_sj_asset_model(it);
        array_add(*file_datas.model_datas, model_file_data);
        
        if single_files {
            filename := sprint("%/%.%", resources_directory, it.id, "sj5k_model");
            delete_file(filename);
            written := write_file(filename, model_file_data.data, model_file_data.size);
            
            add_single_file_info(*single_file_infos, it.id, filename, .Model, xx it.track_filenames.count);
        }
        
        size_of_models += model_file_data.size;
    }
    
    
    
    
    total_size:u32 = 
        size_of(SJ_Header) + 
        size_of_sprites + 
        size_of_sounds + 
        size_of_fonts + 
        size_of_models + 
        size_of_textures + 
        size_of_materials;
    
    
    
    if bundle {
        bundle_data: *u8 = xx alloc(total_size);
        bundle_data_start := bundle_data;
        defer free(bundle_data_start);
        
        
        header:= consume_data(*bundle_data, SJ_Header);
        header.code           = magic_number("sj5k");
        header.asset_count    = 0;
        header.sprite_count   = 0;
        header.sound_count    = 0;
        header.font_count     = 0;
        header.model_count    = 0;
        header.texture_count  = 0;
        header.material_count = 0;
        
        
        // NOTE: Write data in depedency order.
        
        // Many things depend on textures.
        for data: file_datas.texture_datas {
            if data.size == 0 continue;
            texture_data := consume_data_size(*bundle_data, data.size);
            copy_data(texture_data, data.data, data.size);
            
            header.texture_count += 1;
            header.asset_count   += 1;
            
        }
        
        for data: file_datas.sprite_datas {
            if data.size == 0 continue; // WIERD.
            atlas_data := consume_data_size(*bundle_data, data.size);
            copy_data(atlas_data, data.data, data.size);
            
            header.sprite_count += 1;
            header.asset_count += 1;
        }
        
        for data: file_datas.sound_datas {
            if data.size == 0 continue; // WIERD.
            sound_data := consume_data_size(*bundle_data, data.size);
            copy_data(sound_data, data.data, data.size);
            
            header.sound_count += 1;
            header.asset_count += 1;
        }
        
        for data: file_datas.font_datas {
            if data.size == 0 continue; // WIERD.
            font_data := consume_data_size(*bundle_data, data.size);
            copy_data(font_data, data.data, data.size);
            
            header.font_count  += 1;
            header.asset_count += 1;
        }
        
        // Models (meshes) depend on materials
        for data: file_datas.material_datas {
            if data.size == 0 continue;
            material_data := consume_data_size(*bundle_data, data.size);
            copy_data(material_data, data.data, data.size);
            
            header.material_count += 1;
            header.asset_count    += 1;
            
        }
        
        for data: file_datas.model_datas {
            if data.size == 0 continue;
            model_data := consume_data_size(*bundle_data, data.size);
            copy_data(model_data, data.data, data.size);
            
            header.model_count += 1;
            header.asset_count += 1;
            
        }
        
        asset_bundle_filename := "../resources/asset_bundle_0_2_0.sj5k";
        delete_file(asset_bundle_filename);
        written := write_file(asset_bundle_filename, cast(*void)bundle_data_start, total_size);
        
    }
    
    
    if single_files_descriptor {
        
        size := 4; // magic number.
        size += 4; // single file count.
        size += single_file_infos.count * size_of(SJ_Asset_Single_File_Info);
        
        data: *u8 = xx alloc(size);
        data_start := data;
        defer free(data_start);
        
        code := consume_data(*data, u32);
        <<code = magic_number("sjsf");
        count := consume_data(*data, u32);
        <<count = xx single_file_infos.count;
        
        for * src: single_file_infos {
            dst := consume_data(*data, SJ_Asset_Single_File_Info);
            copy_data(cast(*u8)dst, cast(*u8)src, size_of(SJ_Asset_Single_File_Info));
        }
        
        
        filename := "../resources/asset_single_file_infos_0_0_2.sj5k";
        delete_file(filename);
        written := write_file(filename, cast(*void)data_start, size);
        
    }
}
