
#import "Basic";
#import "String";
#import "Sort";
#import "Math";

#import "common";
#import "file_io_common";

#import "image";
#import "font";
#import "sound";
#import "model";

#import "font_files";
#import "wav";
#import "png";
#import "bitmap";
#import "tga";
#import "obj";
#import "fbx";

#import "atlas";

#load "asset_file.jai";



MAX_ATLAS_SPRITES :: 1024;
DESIRED_GLYPHS_ALL :: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!?@#$%^&*()-=_+[]{}\\/|<>,.;':\"`~ ";


Asset_Sprite :: struct {
    id: u32;
    asset_id: string;
    texture_index: u32;
    file_type: File_Type;
    filename: string;
    uv: Rect;
    texture: Texture;
}


Asset_Sprite_Atlas :: struct {
    id: u32;
    sprites: [MAX_ATLAS_SPRITES]Asset_Sprite;
    sprite_count: u32;
    texture: Texture;
}



Asset_Sound :: struct {
    id: u32;
    asset_id: string;
    snd: Sound;
    filename: string;
    file_type: File_Type;
}

Asset_Font :: struct {
    id: u32;
    atlas: Texture;
    fonts: [..]Font;
    glyphs_sorted_by_size: [..]*Glyph;
    
    filename: string;
    desired_pixel_sizes: [..]u16;
    asset_ids: [..]string;
    desired_glyphs: string;
    
    file_type: File_Type;
}




Asset_Material :: struct {
    file_type: File_Type;
    filename: string;
    material: Mesh_Material;
}

Asset_Texture_Map :: struct {
    name: string;
    file_type: File_Type;
    filename: string;
    texture: Texture;
}

Asset_Model :: struct {
    id:        u32;
    asset_id:  string;
    file_type: File_Type;
    filename:  string;
    model:     Model;
}



MAX_SPRITE_ATLASES :: 16;
MAX_SPRITES :: 1024;
MAX_SOUNDS :: 256;
MAX_FONTS :: 16;
MAX_MODELS :: 1024;
MAX_MODEL_TEXTURES :: 1024 * 3;


Asset_Files :: struct {
    atlas_builder: Atlas_Builder;
    
    sprite_atlases: [MAX_SPRITE_ATLASES]Asset_Sprite_Atlas;
    sprite_atlas_count: u32;
    
    sprites: [MAX_SPRITES]Asset_Sprite;
    sprite_count: u32;
    sprite_atlas_size: u32;
    
    sounds: [MAX_SOUNDS]Asset_Sound;
    sound_count: u32;
    sound_failed_count: u32;
    sound_size: u32;
    
    fonts: [MAX_FONTS]Asset_Font;
    font_count: u32;
    font_size: u32;
    
    models: [MAX_MODELS]Asset_Model;
    model_count: u32;
    model_size: u32;
    
    materials: [MAX_MODELS]Asset_Material;
    material_count: u32;
    
    texture_maps: [MAX_MODELS*3]Asset_Texture_Map;
    texture_map_count: u32;
};







add_sprite :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.sprite_count < MAX_ATLAS_SPRITES);
    
    asset: *Asset_Sprite = *(files.sprites[files.sprite_count]);
    asset.id = files.sprite_count;
    asset.asset_id = copy_string(file_info.name);
    asset.file_type = file_info.type;
    asset.filename = copy_string(file_info.relative_path_and_filename);
    
    files.sprite_count += 1;
}

add_sprite_atlas :: (files: *Asset_Files, width: u16, height: u16) {
    print("Added new sprite atlas with width: %, height: %\n", width, height);
    assert(files.sprite_atlas_count < MAX_SPRITE_ATLASES);
    
    atlas_builder_init(*files.atlas_builder, width, height);
    
    asset: *Asset_Sprite_Atlas = *(files.sprite_atlases[files.sprite_atlas_count]);
    asset.id = files.sprite_atlas_count;
    asset.texture = files.atlas_builder.texture;
    
    files.sprite_atlas_size += (cast(u32)width * cast(u32)height) * size_of(Pixel);
    
    files.sprite_atlas_count += 1;
}


add_sprite_to_sprite_atlas :: (texture: *Asset_Sprite_Atlas, sprite: *Asset_Sprite, uv: Rect) {
    sprite.texture_index = texture.id;
    sprite.uv = uv;
    texture.sprites[texture.sprite_count] = sprite;
    texture.sprite_count += 1;
}


add_font :: (files: *Asset_Files, file_info: File_Info, pixel_sizes: []u16, desired_glyphs: string = DESIRED_GLYPHS_ALL) {
    assert(files.font_count < MAX_FONTS);
    asset: *Asset_Font = *files.fonts[files.font_count];
    asset.id = files.font_count;
    asset.file_type = file_info.type;
    asset.filename = copy_string(file_info.relative_path_and_filename);
    for size: pixel_sizes {
        array_add(*asset.desired_pixel_sizes, size);
        sb := String_Builder.{};
        append(*sb, copy_string(file_info.name));
        append(*sb, "_s_");
        print_integer(*sb, formatInt(size));
        array_add(*asset.asset_ids, builder_to_string(*sb));
    }
    asset.desired_glyphs = desired_glyphs;
    files.font_count += 1;
}


add_sound :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.sound_count < MAX_SOUNDS);
    asset: Asset_Sound  = .{};
    asset.id = files.sound_count;
    asset.asset_id = copy_string(file_info.name);
    asset.file_type = file_info.type;
    asset.filename = copy_string(file_info.relative_path_and_filename);
    files.sounds[asset.id] = asset;
    files.sound_count+=1;
}




add_model :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.model_count < MAX_MODELS);
    
    asset: Asset_Model = .{};
    asset.id = files.model_count;
    asset.asset_id = copy_string(file_info.name);
    asset.file_type = file_info.type;
    asset.filename = copy_string(file_info.relative_path_and_filename);
    
    files.models[asset.id] = asset;
    files.model_count += 1;
}

add_material :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.material_count < MAX_MODELS);
    
    asset: Asset_Material = .{};
    asset.file_type = file_info.type;
    asset.filename = copy_string(file_info.relative_path_and_filename);
    files.materials[files.material_count] = asset;
    files.material_count += 1;
}

add_texture_map :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.texture_map_count < MAX_MODEL_TEXTURES);
    
    asset: Asset_Texture_Map = .{};
    asset.name = file_info.name;
    asset.file_type = file_info.type;
    asset.filename = copy_string(file_info.relative_path_and_filename);
    files.texture_maps[files.texture_map_count] = asset;
    files.texture_map_count += 1;
}




load_sprite :: (asset: *Asset_Sprite) {
    
    file_result: File_Result = read_file(asset.filename);
    defer free_file(file_result);
    
    if file_result.content_size {
        save_to_bitmap := false;
        if asset.file_type == .PNG {
            asset.texture = png_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else if asset.file_type == .TGA {
            asset.texture = tga_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
            // save_to_bitmap = true;
        } else {
            print("unimplemented texture file type: %\n", asset.file_type);
        }
        
        if save_to_bitmap {
            sb := String_Builder.{};
            append(*sb, "../data/test/");
            append(*sb, asset.asset_id);
            append(*sb, ".bmp");
            bmp_name := builder_to_string(*sb);
            bitmap_save(asset.texture.pixels, asset.texture.width, asset.texture.height, bmp_name);
        }
    }
    else {
        print("err (content_size): %\n", file_result.content_size);
    }
}



load_font :: (asset: *Asset_Font) {
    file_result: File_Result = read_file(asset.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (asset.file_type == .TTF) {
            
            added_fonts := font_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size, asset.desired_glyphs, asset.desired_pixel_sizes);
            for font: added_fonts {
                array_add(*asset.fonts, font);
            }
            
        }
        else {
            print("unimplemented font file type: %\n", asset.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}




load_sound :: (asset: *Asset_Sound) -> bool {
    
    file_result: File_Result = read_file(asset.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (asset.file_type == .WAV) {
            worked:, asset.snd = wav_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
            if (worked) {
                return true;
            }
            else {
                print("failed to load sound (possibly unsupported encoding): %\n", asset.filename);
            }
        }
        else {
            print("unimplemented sound file type: %\n", asset.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    return false;
}




load_model :: (asset: *Asset_Model) {
    
    file_result: File_Result = read_file(asset.filename);
    defer free_file(file_result);
    
    model: Model;
    
    if (file_result.content_size) {
        if (asset.file_type == .OBJ) {
            model = obj_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
            
        } else if (asset.file_type == .FBX) {
            model = fbx_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                             asset.asset_id);
            
        } else {
            print("unimplemented model file type: %\n", asset.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    
    if model.name.count == 0 {
        model.name = asset.asset_id;
    }
    asset.model = model;
}

load_material :: (asset: *Asset_Material) {
    
    file_result: File_Result = read_file(asset.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (asset.file_type == .MTL) {
            asset.material = mtl_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        }
        else {
            print("unimplemented material file type: %\n", asset.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}


load_texture_map :: (asset: *Asset_Texture_Map) {
    
    file_result: File_Result = read_file(asset.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        save_to_bitmap := false;
        
        if (asset.file_type == .PNG) {
            asset.texture = png_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else if asset.file_type == .TGA {
            asset.texture = tga_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else {
            print("unimplemented texture file type: %\n", asset.file_type);
        }
        
        
        if save_to_bitmap {
            sb := String_Builder.{};
            append(*sb, "../data/test/");
            append(*sb, asset.name);
            append(*sb, ".bmp");
            bmp_name := builder_to_string(*sb);
            bitmap_save(asset.texture.pixels, asset.texture.width, asset.texture.height, bmp_name);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}



#scope_export



main :: () {
    
    files: *Asset_Files = cast(*Asset_Files)alloc(size_of(Asset_Files));
    files.atlas_builder = .{};
    files.sound_size = 0;
    files.sound_count = 0;
    defer free(files);
    
    
    texture_file_proc :: (file_info: File_Info, data: *void) {
        asset_files: = cast(*Asset_Files)data;
        if file_info.type ==  {
            case .PNG;
            add_sprite(asset_files, file_info);
        }
    }
    sound_file_proc :: (file_info: File_Info, data: *void) {
        asset_files: = cast(*Asset_Files)data;
        if file_info.type ==  {
            case .WAV;
            add_sound(asset_files, file_info);
        }
    }
    
    font_file_proc :: (file_info: File_Info, data: *void) {
        asset_files: = cast(*Asset_Files)data;
        if file_info.type ==  {
            case .TTF;
            sizes: []u16 = .[10,12,14,16,18,20,22,24,36,42,48,50,60,72,96,144];
            add_font(asset_files, file_info, sizes);
        }
    }
    
    
    model_file_proc :: (file_info: File_Info, data: *void) {
        asset_files: = cast(*Asset_Files)data;
        if file_info.type == {
            case .FBX;
            add_model(asset_files, file_info);
            case .OBJ;
            add_model(asset_files, file_info);
            case .MTL;
            add_material(asset_files, file_info);
            case .PNG;
#through;
            case .TGA;
            add_texture_map(asset_files, file_info);
        }
    }
    
    visit_files_in_directory("../resources/sprites", texture_file_proc, cast(*void)files);
    visit_files_in_directory("../resources/sounds", sound_file_proc, cast(*void)files);
    visit_files_in_directory("../resources/fonts", font_file_proc, cast(*void)files);
    visit_files_in_directory("../resources/models", model_file_proc, cast(*void)files);
    
    
    for *asset: files.sprites {
        if it_index == files.sprite_count break;
        load_sprite(asset);
    }
    
    
    // Sort all of the sprites from largest to smallest. 
    // This seems to work best with our packing algorithm.
    compare_sprites :: (a: Asset_Sprite, b: Asset_Sprite) -> s64 {
        va := volume(a.texture);
        vb := volume(b.texture);
        if va == vb return 0;
        if va > vb return -1;
        return 1;
    }
    
    quick_sort(files.sprites, compare_sprites);
    
    atlas_width : u16 = 1024;
    atlas_height: u16 = 1024;
    
    add_sprite_atlas(files, atlas_width, atlas_height);
    current_sprite_atlas : *Asset_Sprite_Atlas = *(files.sprite_atlases[files.sprite_atlas_count-1]);
    
    // Will iterate over all sprites.
    // Whenever a sprite cannot fit into the current atlas,
    // a new blank atlas will be created to continue fitting sprites.
    for *sprite: files.sprites {
        if it_index == files.sprite_count break;
        section: = atlas_get_section_for_texture(*files.atlas_builder, *sprite.texture);
        if section == null {
            // no more space anywhere
            add_sprite_atlas(files, atlas_width, atlas_height);
            section = *(files.atlas_builder.root_section);
            current_sprite_atlas += 1;
        }
        atlas_update_for_texure(*files.atlas_builder, section, sprite.texture);
        uv := atlas_add_texture(*files.atlas_builder, section, sprite.texture);
        add_sprite_to_sprite_atlas(current_sprite_atlas, sprite, uv);
    }
    
    
    
    
    for *asset: files.sounds {
        if it_index == files.sound_count break;
        worked := load_sound(asset);
        if worked {
            files.sound_size += asset.snd.size;
        }
        else {
            asset.file_type = .Unknown;
            files.sound_failed_count += 1;
        }
    }
    
    
    
    for *asset: files.materials {
        if it_index == files.material_count break;
        load_material(asset);
    }
    for *asset: files.texture_maps {
        if it_index == files.texture_map_count break;
        load_texture_map(asset);
    }
    
    
    
    for *asset: files.models {
        if it_index == files.model_count break;
        load_model(asset);
        
        model := asset.model;
        
        for mesh: model.meshes {
            files.model_size += cast(u32)mesh.triangles.count * (size_of(SJ_Mesh_Vertex) * 3);
            
            if mesh.materials.count == 0 {
                
                for material_name: mesh.material_names {
                    
                    // Try to find the material from the materials files
                    // to assign to the object.
                    // This is because in wavefront objs, materials are in 
                    // separate files... as are textures and all that.
                    
                    for *mat: files.materials {
                        if it_index == files.material_count break;
                        
                        material := mat.material;
                        if equal_nocase(material.name, material_name) {
                            array_add(*mesh.materials, *mat.material);
                            break;
                        }
                    }
                }
            }
            
            if mesh.materials.count > 0 {
                
                for material: mesh.materials {
                    
                    for map: material.texture_maps {
                        
                        if map == null {
                            
                            tm_index := it_index;
                            
                            // maybe we can find the texture map by name from the 
                            // texture map files, in the case that this is
                            // the wavefront obj format.
                            
                            map_file := material.texture_map_files[it_index];
                            
                            found,name,ext: = split_from_left(map_file, ".");
                            if name.count > 0 {
                                for *tex : files.texture_maps {
                                    if it_index == files.texture_map_count break;
                                    
                                    if equal_nocase(tex.name, name) {
                                        material.texture_maps[tm_index] = *tex.texture;
                                        map = *tex.texture;
                                        break;
                                    }
                                    
                                }
                            }
                            
                        }
                        
                        if map != null {
                            s := cast(u32)size_of(Pixel) * cast(u32)map.width * cast(u32)map.height;
                            files.model_size += s;
                        }
                    }
                }
                
            }
            
            
            
            // moving all vertices around origin.
            lowest_point  := V3.{x= 100000000,y= 10000000,z= 10000000};
            highest_point := V3.{x=-100000000,y=-10000000,z=-10000000};
            for mesh.vertices {
                found, index := array_find(mesh.dead_vertices, cast(u32)it_index);
                if found continue;
                if it.x < lowest_point.x  lowest_point.x  = it.x;
                if it.y < lowest_point.y  lowest_point.y  = it.y;
                if it.z < lowest_point.z  lowest_point.z  = it.z;
                if it.x > highest_point.x highest_point.x = it.x;
                if it.y > highest_point.y highest_point.y = it.y;
                if it.z > highest_point.z highest_point.z = it.z;
            }
            mid_point := (lowest_point + highest_point) * 0.5;
            for mesh.vertices {
                // meshvertices[it_index] = it - mid_point;
            }
            
            
        }
        
    }
    
    
    
    
    
    for *asset: files.fonts {
        if it_index == files.font_count break;
        load_font(asset);
        
        for *font: asset.fonts {
            for *glyph: font.glyphs {
                if glyph.value == 0 continue;
                array_add(*asset.glyphs_sorted_by_size, glyph);
            }
        }
        
        // Just like sprites, we sort the glyphs from largest
        // to smallest. Since there are fonts of different sizes
        // it will mean that usually larger sized fonts are at the 
        // front of the array after sorting.
        compare_glyphs :: (a : *Glyph, b: *Glyph) -> s64 {
            va := volume(a.texture);
            vb := volume(b.texture);
            if va == vb return 0;
            if va > vb return -1;
            return 1;
        }
        quick_sort(asset.glyphs_sorted_by_size, compare_glyphs);
        
        atlas_builder: Atlas_Builder = .{};
        atlas_builder_init(*atlas_builder, 128);
        
        print("Measuring font atlas ...\n");
        // Meaurement step.
        // First we iterate over all the glyphs that want
        // to fit into the font atlas, BUT without writing
        // any of their pixel data, this is so that it's faster
        // so we can just get a rough estimate of how big of a 
        // texture we'll need for it.
        for 0 .. asset.glyphs_sorted_by_size.count-1 {
            glyph := asset.glyphs_sorted_by_size[it];
            section := atlas_get_section_for_texture(*atlas_builder, *glyph.texture);
            if section == null {
                atlas_increase(*atlas_builder);
                section = *(atlas_builder.root_section);
                it = 0; //we have to start over to reset all the uvs and better management of empty spaces.
            }
            // glyph.atlas_uv = atlas_add_texture(*atlas_builder, section, glyph.texture);
            atlas_update_for_texure(*atlas_builder, section, glyph.texture);
        }
        print("Font atlas measured at width: %, height: %\n", atlas_builder.texture.width, atlas_builder.texture.height);
        
        
        // Pixel copy step.
        // Measuring done, now we can actually
        // iterate again and copy the pixels into the 
        // font atlas.
        atlas_clear_texture(*atlas_builder, .{0.0,0.0,0.0,0.0});
        for 0 .. asset.glyphs_sorted_by_size.count-1 {
            glyph := asset.glyphs_sorted_by_size[it];
            section := atlas_get_section_for_texture(*atlas_builder, *glyph.texture);
            assert(section != null);
            glyph.atlas_uv = atlas_add_texture(*atlas_builder, section, glyph.texture);
        }
        print("Font atlas complete\n");
        
        asset.atlas = atlas_builder.texture;
        files.font_size += cast(u32)asset.atlas.width * cast(u32)asset.atlas.height * size_of(Pixel);
    }
    
    
    
    saved: = save_final_asset_file(files);
    if saved print("success\n");
    else print("failed\n");
}


