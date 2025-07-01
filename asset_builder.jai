#import "Basic";
#import "String";
#import "Sort";
#import "Math";

#import "common";
#import "file_io_common";

#import "image";
#import "sound";
#import "model";
#import "font_files";
#import "atlas";

#import "wav";
#import "png";
#import "bitmap";
#import "tga";
#import "obj";
#import "fbx";
#import "animation_graph";
#import "asset_details";



#load "asset_file.jai";



MAX_ATLAS_SPRITES :: 1024;
DESIRED_GLYPHS_ALL :: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!?@#$%^&*()-=_+[]{}\\/|<>,.;':\"`~ ";

Asset_Base :: struct {
    id:              u32;
    asset_id:        string;
    file_type:       File_Type;
    filename:        string;
    track_filenames: [..]string;
}



Asset_Sprite :: struct {
    using #as base: Asset_Base;
    
    texture_index: u32;
    uv: Rect;
    texture: Texture;
}


Asset_Sprite_Atlas :: struct {
    using #as base: Asset_Base;
    
    sprites: [MAX_ATLAS_SPRITES]Asset_Sprite;
    sprite_count: u32;
    texture: Texture;
}



Asset_Sound :: struct {
    using #as base: Asset_Base;
    
    snd: Sound;
}

Asset_Font :: struct {
    using #as base: Asset_Base;
    
    atlas:                 Texture;
    fonts:                 [..]Font;
    glyphs_sorted_by_size: [..]*Glyph;
    
    desired_pixel_sizes:   [..]u16;
    asset_ids:             [..]string;
    desired_glyphs:        string;
    
}




Asset_Material :: struct {
    using #as base: Asset_Base;
    
    material: Mesh_Material;
}

Asset_Texture_Map :: struct {
    using #as base: Asset_Base;
    
    texture: Texture;
}

Asset_Animation :: struct {
    using #as base: Asset_Base;
    
    model_id:   string;
    animations: [..]*Animation;
}

Asset_Model :: struct {
    using #as base: Asset_Base;
    
    model: Model;
    asset_details: Asset_Details;
}

Asset_Animation_Graph :: struct {
    using #as base: Asset_Base;
    
    graph: Animation_Graph;
}

Asset_Asset_Details :: struct {
    using #as base: Asset_Base;
    
    details: Asset_Details;
}



MAX_SPRITE_ATLASES :: 16;
MAX_SPRITES :: 1024;
MAX_SOUNDS :: 256;
MAX_FONTS :: 16;
MAX_MODELS :: 1024;
MAX_MODEL_TEXTURES :: MAX_MODELS * 3;
MAX_MODEL_ANIMATIONS :: MAX_MODELS * 10;


Asset_Files :: struct {
    atlas_builder: Atlas_Builder;
    
    sprite_atlases:     [MAX_SPRITE_ATLASES]Asset_Sprite_Atlas;
    sprite_atlas_count: u32;
    sprites:            [MAX_SPRITES]Asset_Sprite;
    sprite_count:       u32;
    
    sounds: [MAX_SOUNDS]Asset_Sound;
    sound_count: u32;
    sound_failed_count: u32;
    
    fonts: [MAX_FONTS]Asset_Font;
    font_count: u32;
    font_size: u32;
    
    models: [MAX_MODELS]Asset_Model;
    model_count: u32;
    
    materials: [MAX_MODELS]Asset_Material;
    material_count: u32;
    
    texture_maps: [MAX_MODEL_TEXTURES]Asset_Texture_Map;
    texture_map_count: u32;
    
    animations: [MAX_MODEL_ANIMATIONS]Asset_Animation;
    animation_count: u32;
    
    animation_graphs: [MAX_MODELS]Asset_Animation_Graph;
    animation_graph_count: u32;
    
    asset_details: [MAX_MODELS]Asset_Asset_Details;
    asset_detail_count: u32;
    
    
    texture_id_counter: u32;
};


get_texture_id :: (files: *Asset_Files) -> u32 {
    id := files.texture_id_counter;
    files.texture_id_counter += 1;
    return id;
}




add_sprite :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.sprite_count < MAX_ATLAS_SPRITES);
    
    asset: *Asset_Sprite = *(files.sprites[files.sprite_count]);
    asset.id             = files.sprite_count;
    asset.asset_id       = copy_string(file_info.name);
    asset.file_type      = file_info.type;
    asset.filename       = copy_string(file_info.relative_path_and_filename);
    
    files.sprite_count += 1;
}

add_sprite_atlas :: (files: *Asset_Files, width: u16, height: u16) {
    print("Added new sprite atlas with width: %, height: %\n", width, height);
    assert(files.sprite_atlas_count < MAX_SPRITE_ATLASES);
    
    atlas_builder_init(*files.atlas_builder, width, height);
    
    asset: *Asset_Sprite_Atlas = *(files.sprite_atlases[files.sprite_atlas_count]);
    asset.id       = get_texture_id(files);
    asset.asset_id = sprint("%", asset.id);
    asset.texture = files.atlas_builder.texture;
    
    files.sprite_atlas_count += 1;
}


add_sprite_to_sprite_atlas :: (texture: *Asset_Sprite_Atlas, sprite: *Asset_Sprite, uv: Rect) {
    sprite.texture_index = texture.id;
    sprite.uv            = uv;
    texture.sprites[texture.sprite_count] = sprite;
    texture.sprite_count += 1;
}


add_font :: (files: *Asset_Files, file_info: File_Info, pixel_sizes: []u16, desired_glyphs: string = DESIRED_GLYPHS_ALL) {
    assert(files.font_count < MAX_FONTS);
    asset: *Asset_Font = *files.fonts[files.font_count];
    asset.id           = get_texture_id(files);
    asset.asset_id     = file_info.name;
    asset.file_type    = file_info.type;
    asset.filename     = copy_string(file_info.relative_path_and_filename);
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
    asset.id        = files.sound_count;
    asset.asset_id  = copy_string(file_info.name);
    asset.file_type = file_info.type;
    asset.filename  = copy_string(file_info.relative_path_and_filename);
    files.sounds[asset.id] = asset;
    files.sound_count+=1;
}




add_model :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.model_count < MAX_MODELS);
    
    asset: Asset_Model = .{};
    asset.id        = files.model_count;
    asset.asset_id  = copy_string(file_info.name);
    asset.file_type = file_info.type;
    asset.filename  = copy_string(file_info.relative_path_and_filename);
    
    files.models[asset.id] = asset;
    files.model_count += 1;
}

add_material :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.material_count < MAX_MODELS);
    
    asset: Asset_Material = .{};
    asset.file_type = file_info.type;
    asset.filename  = copy_string(file_info.relative_path_and_filename);
    files.materials[files.material_count] = asset;
    files.material_count += 1;
}

add_texture_map :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.texture_map_count < MAX_MODEL_TEXTURES);
    
    asset: Asset_Texture_Map = .{};
    asset.id        = get_texture_id(files);
    asset.asset_id  = file_info.name;
    asset.file_type = file_info.type;
    asset.filename  = copy_string(file_info.relative_path_and_filename);
    files.texture_maps[files.texture_map_count] = asset;
    files.texture_map_count += 1;
}

add_animation :: (files: *Asset_Files, file_info: File_Info, anim_name: string, model_name: string) {
    assert(files.animation_count < MAX_MODEL_ANIMATIONS);
    asset: Asset_Animation = .{};
    asset.asset_id  = anim_name;
    asset.model_id  = model_name;
    asset.file_type = file_info.type;
    asset.filename  = copy_string(file_info.relative_path_and_filename);
    files.animations[files.animation_count] = asset;
    files.animation_count += 1;
}

add_animation_graph :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.animation_graph_count < MAX_MODELS);
    asset: Asset_Animation_Graph = .{};
    asset.asset_id  = file_info.name;
    asset.file_type = file_info.type;
    asset.filename  = copy_string(file_info.relative_path_and_filename);
    files.animation_graphs[files.animation_graph_count] = asset;
    files.animation_graph_count += 1;
}

add_asset_details :: (files: *Asset_Files, file_info: File_Info) {
    assert(files.animation_graph_count < MAX_MODELS);
    asset: Asset_Asset_Details = .{};
    asset.asset_id  = file_info.name;
    asset.file_type = file_info.type;
    asset.filename  = copy_string(file_info.relative_path_and_filename);
    files.asset_details[files.asset_detail_count] = asset;
    files.asset_detail_count += 1;
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
            append(*sb, asset.asset_id);
            append(*sb, ".bmp");
            bmp_name := builder_to_string(*sb);
            bitmap_save(asset.texture.pixels, asset.texture.width, asset.texture.height, bmp_name);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}

load_animation :: (asset: *Asset_Animation) {
    
    file_result: File_Result = read_file(asset.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (asset.file_type == .FBX) {
            
            animations := fbx_load_additional_animations(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                                                         asset.asset_id);
            
            for animations {
                array_add(*asset.animations, it);
            }
            
        } else {
            print("unimplemented animation file type: %\n", asset.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}


load_animation_graph :: (asset: *Asset_Animation_Graph) {
    
    file_result: File_Result = read_file(asset.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (asset.file_type == .Animation_Graph) {
            
            asset.graph = animation_graph_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                                               asset.asset_id);
            
        } else {
            print("unimplemented animation file type: %\n", asset.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}


load_asset_details :: (asset: *Asset_Asset_Details) {
    
    file_result: File_Result = read_file(asset.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (asset.file_type == .Asset_Details) {
            
            asset.details = asset_details_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                                               asset.asset_id);
            
        } else {
            print("unimplemented asset details file type: %\n", asset.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}






#scope_export


Asset_Visit_Files_Proc_Data :: struct {
    asset_files: *Asset_Files;
    names:       [..]string;
};

should_gather :: (names: [..]string, name: string) -> bool {
    if names.count == 0 return true;
    found, index := array_find(names, name);
    if found return true;
    return false;
}

visit_model_files :: (file_info: File_Info, data: *void) {
    
    proc_data   := cast(*Asset_Visit_Files_Proc_Data)data;
    asset_files := proc_data.asset_files;
    names       := proc_data.names;
    
    if file_info.type == {
        case .FBX; {
            found, model_name, anim_name := split_from_left(file_info.name, #char "@");
            if found {
                if should_gather(names, model_name) {
                    add_animation(asset_files, file_info, anim_name, model_name);
                }
            } else {
                if should_gather(names, file_info.name) {
                    add_model(asset_files, file_info);
                }
            }
        }
        case .OBJ;
        if should_gather(names, file_info.name) add_model(asset_files, file_info);
        case .MTL;
        if should_gather(names, file_info.name) add_material(asset_files, file_info);
        case .PNG;
#through;
        case .TGA;
        if should_gather(names, file_info.name) add_texture_map(asset_files, file_info);
        case .Animation_Graph;
        if should_gather(names, file_info.name) add_animation_graph(asset_files, file_info);
        case .Asset_Details;
        if should_gather(names, file_info.name) add_asset_details(asset_files, file_info);
    }
}



main :: () {
    
    directory_models  := "../resources/models";
    directory_sprites := "../resources/sprites";
    directory_sounds  := "../resources/sounds";
    directory_fonts   := "../resources/fonts";
    
    bundle_file             := true;
    single_files            := true;
    single_files_descriptor := true;
    process_models          := true;
    process_sprites         := true;
    process_sounds          := true;
    process_fonts           := true;
    
    
    files: *Asset_Files = cast(*Asset_Files)alloc(size_of(Asset_Files));
    files.atlas_builder = .{};
    files.sound_count = 0;
    defer free(files);
    
    visit_files_proc_data := Asset_Visit_Files_Proc_Data.{};
    visit_files_proc_data.asset_files = files;
    
    
    args := get_command_line_arguments();
    defer array_reset(*args);
    
    
    if args.count > 1 {
        
        for 1 .. args.count - 1 {
            arg  := args[it];
            next : string = "";
            if it < args.count - 1 {
                next = args[it + 1];
            }
            
            if arg == "model" {
                if next.count == 0 invalid_code_path("Argument 'model' found but no name specified.");
                
                it += 1;
                
                array_add(*visit_files_proc_data.names, next);
                
                process_sprites = false;
                process_sounds  = false;
                process_fonts   = false;
                bundle_file     = false;
                single_files_descriptor = false;
                
            } else if arg == "texture_map" {
                if next.count == 0 invalid_code_path("Argument 'texture_map' found but no name specified.");
                
                it += 1;
                
                array_add(*visit_files_proc_data.names, next);
                
                process_sprites = false;
                process_sounds  = false;
                process_fonts   = false;
                bundle_file     = false;
                single_files_descriptor = false;
                
            } else if arg == "sprite_atlas" {
                if next.count == 0 invalid_code_path("Argument 'sprite_atlas' found but no name specified.");
                
                it += 1;
                
                array_add(*visit_files_proc_data.names, next);
                
                process_models = false;
                process_sounds = false;
                process_fonts  = false;
                bundle_file    = false;
                single_files_descriptor = false;
                
            } else if arg == "sound" {
                if next.count == 0 invalid_code_path("Argument 'sound' but no name specified.");
                
                it += 1;
                
                array_add(*visit_files_proc_data.names, next);
                
                process_models  = false;
                process_sprites = false;
                process_fonts   = false;
                bundle_file     = false;
                single_files_descriptor = false;
                
            } else if arg == "font" {
                if next.count == 0 invalid_code_path("Argument 'font' found but no name specified.");
                
                it += 1;
                
                array_add(*visit_files_proc_data.names, next);
                
                process_models  = false;
                process_sprites = false;
                process_sounds  = false;
                bundle_file     = false;
                single_files_descriptor = false;
                
            } else if arg == "no_models" {
                process_models = false;
                
            } else if arg == "no_sprites" {
                process_sprites = false;
                
            } else if arg == "no_sounds" {
                process_sounds = false;
                
            } else if arg == "no_fonts" {
                process_fonts = false;
                
            } else if arg == "no_dump" {
                single_files            = false;
                single_files_descriptor = false;
                
            } else if arg == "no_bundle" {
                bundle_file   = false;
                
            } else if arg == "no_files" {
                bundle_file             = false;
                single_files            = false;
                single_files_descriptor = false;
            }
        }
        
    }
    
    
    
    
    
    
    if process_sprites {
        file_proc :: (file_info: File_Info, data: *void) {
            asset_files: = cast(*Asset_Files)data;
            if file_info.type ==  {
                case .PNG;
                add_sprite(asset_files, file_info);
            }
        }
        visit_files_in_directory(directory_sprites, file_proc, cast(*void)files);
        
        for *asset: files.sprites {
            if it_index == files.sprite_count break;
            load_sprite(asset);
        }
        
        if files.sprites.count > 0 {
            
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
            
        }
        
    }
    
    if process_sounds {
        file_proc :: (file_info: File_Info, data: *void) {
            asset_files: = cast(*Asset_Files)data;
            if file_info.type ==  {
                case .WAV;
                add_sound(asset_files, file_info);
            }
        }
        
        visit_files_in_directory(directory_sounds, file_proc, cast(*void)files);
        
        
        for *asset: files.sounds {
            if it_index == files.sound_count break;
            worked := load_sound(asset);
            if worked {
            }
            else {
                asset.file_type = .Unknown;
                files.sound_failed_count += 1;
            }
        }
        
    }
    
    if process_fonts {
        file_proc :: (file_info: File_Info, data: *void) {
            asset_files: = cast(*Asset_Files)data;
            if file_info.type ==  {
                case .TTF;
                sizes: []u16 = .[10,12,14,16,18,20,22,24,36,42,48,50,60,72,96,144];
                add_font(asset_files, file_info, sizes);
            }
        }
        visit_files_in_directory(directory_fonts, file_proc, cast(*void)files);
        
        
        
        
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
        
        
    }
    
    if process_models {
        
        
        visit_files_in_directory(directory_models, visit_model_files, cast(*void)*visit_files_proc_data);
        
        
        for *asset: files.materials {
            if it_index == files.material_count break;
            load_material(asset);
        }
        for *asset: files.texture_maps {
            if it_index == files.texture_map_count break;
            load_texture_map(asset);
            
            array_add(*asset.track_filenames, asset.filename);
        }
        for *asset: files.animation_graphs {
            if it_index == files.animation_graph_count break;
            load_animation_graph(asset);
        }
        for *asset: files.animations {
            if it_index == files.animation_count break;
            load_animation(asset);
        }
        for *asset: files.asset_details {
            if it_index == files.asset_detail_count break;
            load_asset_details(asset);
        }
        
        
        for *model_asset: files.models {
            if it_index == files.model_count break;
            
            for asset_details_asset: files.asset_details {
                if asset_details_asset.asset_id == model_asset.asset_id {
                    model_asset.asset_details = asset_details_asset.details;
                    array_add(*model_asset.track_filenames, asset_details_asset.filename);
                    break;
                }
            }
            
            
            load_model(model_asset);
            
            array_add(*model_asset.track_filenames, model_asset.filename);
            
            model := *model_asset.model;
            
            for mesh: model.meshes {
                
                
                
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
                                
                                array_add(*model_asset.track_filenames, mat.filename);
                                break;
                            }
                        }
                    }
                }
                
                for material: mesh.materials {
                    
                    for 0 .. Mesh_Texture_Type.Count - 1 {
                        
                        tm_index := it;
                        
                        map_file := material.texture_map_files[tm_index];
                        
                        found,name,ext: = split_from_left(map_file, ".");
                        if name.count > 0 {
                            for *tex : files.texture_maps {
                                if it_index == files.texture_map_count break;
                                
                                if equal_nocase(tex.asset_id, name) {
                                    material.texture_map_ids[tm_index] = copy_string(tex.asset_id);
                                    break;
                                }
                                
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
                    // mesh.vertices[it_index] = it - mid_point;
                }
                
                
            }
            
            
            
            for *animation_asset: files.animations {
                if it_index == files.animation_count break;
                if animation_asset.model_id == model_asset.asset_id {
                    for animation: animation_asset.animations {
                        array_add(*model.animations, animation);
                    }
                    
                    array_add(*model_asset.track_filenames, animation_asset.filename);
                }
            }
            
            
            for graph_asset: files.animation_graphs {
                if it_index == files.animation_graph_count break;
                
                if graph_asset.asset_id == model_asset.asset_id {
                    model.animation_graph = graph_asset.graph;
                    
                    array_add(*model_asset.track_filenames, graph_asset.filename);
                    break;
                }
            }
            
            for *state: model.animation_graph.states {
                found := false;
                for anim: model.animations {
                    if anim.name == state.animation_name {
                        state.animation_index = it_index;
                        found = true;
                        break;
                    }
                }
                if !found print("Animation state could not find matching animation by name: %\n", state.animation_name);
                
                if state.next_state.count > 0 {
                    for *next_state : model.animation_graph.states {
                        if next_state.name == state.next_state {
                            state.next_state_index = it_index;
                        }
                    }
                }
            }
            
            
            
            
        }
        
    }
    
    save_final_asset_files(files, bundle_file, single_files, single_files_descriptor);
    
}


