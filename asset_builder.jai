#import "Basic";
#import "String";
#import "Sort";
#import "Math";
#import "Hash_Table";

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


// Resources are files or resources made by the asset_builder, such as 
// sprite sheets from aggregating all sprite resources found.

Resource_Base :: struct {
    id:              string;
    file_type:       File_Type;
    filename:        string;
    track_filenames: [..]string;
}


Resource_Sprite :: struct {
    using #as base: Resource_Base;
    
    texture_id: string;
    uv: Rect;
    texture: Texture;
}


Resource_Sound :: struct {
    using #as base: Resource_Base;
    
    snd: Sound;
}


Resource_Font :: struct {
    using #as base: Resource_Base;
    
    texture_id:      string;
    fonts:                 [..]Font;
    glyphs_sorted_by_size: [..]*Glyph;
    
    desired_pixel_sizes:   [..]u16;
    ids:                   [..]string;
    desired_glyphs:        string;
    
}


Resource_Material :: struct {
    using #as base: Resource_Base;
    
    material: Mesh_Material;
}


Resource_Texture :: struct {
    using #as base: Resource_Base;
    
    texture: Texture;
}


Resource_Animation :: struct {
    using #as base: Resource_Base;
    
    model_id:   string;
    animations: [..]*Animation;
}


Resource_Model :: struct {
    using #as base: Resource_Base;
    
    model: Model;
    asset_details: Asset_Details;
}

Resource_Animation_Graph :: struct {
    using #as base: Resource_Base;
    
    graph: Animation_Graph;
}

Resource_Asset_Details :: struct {
    using #as base: Resource_Base;
    
    details: Asset_Details;
}


Resources :: struct {
    textures:         Table(string, Resource_Texture);
    sprites:          Table(string, Resource_Sprite);
    sounds:           Table(string, Resource_Sound);
    fonts:            Table(string, Resource_Font);
    models:           Table(string, Resource_Model);
    materials:        Table(string, Resource_Material);
    animations:       Table(string, Resource_Animation);
    animation_graphs: Table(string, Resource_Animation_Graph);
    asset_details:    Table(string, Resource_Asset_Details);
}

add_resource :: (table: *Table, $T: Type, file_info: File_Info) -> *T {
    resource := T.{};
    resource.id        = copy_string(file_info.name);
    resource.file_type = file_info.type;
    resource.filename  = copy_string(file_info.relative_path_and_filename);
    array_add(*resource.track_filenames, resource.filename);
    
    return table_add(table, resource.id, resource);
}
add_resource :: (table: *Table, $T: Type, id: string) -> *T {
    resource := T.{};
    resource.id  = copy_string(id);
    resource.file_type = .Unknown;
    
    return table_add(table, resource.id, resource);
}



DEBUG_SAVE_SPRITE_TO_BITMAP :: false;

load_sprite :: (resource: *Resource_Sprite) {
    
    file_result: File_Result = read_file(resource.filename);
    defer free_file(file_result);
    
    if file_result.content_size {
        
        if resource.file_type == .PNG {
            resource.texture = png_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else if resource.file_type == .TGA {
            resource.texture = tga_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
            // save_to_bitmap = true;
        } else {
            print("unimplemented texture file type: %\n", resource.file_type);
        }
        
        if DEBUG_SAVE_SPRITE_TO_BITMAP {
            sb := String_Builder.{};
            append(*sb, "../data/test/");
            append(*sb, resource.id);
            append(*sb, ".bmp");
            bmp_name := builder_to_string(*sb);
            bitmap_save(resource.texture.pixels, resource.texture.width, resource.texture.height, bmp_name);
        }
    }
    else {
        print("err (content_size): %\n", file_result.content_size);
    }
}



load_font :: (resource: *Resource_Font) {
    file_result: File_Result = read_file(resource.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (resource.file_type == .TTF) {
            
            added_fonts := font_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size, resource.desired_glyphs, resource.desired_pixel_sizes);
            for font: added_fonts {
                array_add(*resource.fonts, font);
            }
            
        }
        else {
            print("unimplemented font file type: %\n", resource.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}




load_sound :: (resource: *Resource_Sound) -> bool {
    
    file_result: File_Result = read_file(resource.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (resource.file_type == .WAV) {
            worked:, resource.snd = wav_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
            if (worked) {
                return true;
            }
            else {
                print("failed to load sound (possibly unsupported encoding): %\n", resource.filename);
            }
        }
        else {
            print("unimplemented sound file type: %\n", resource.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    return false;
}




load_model :: (resource: *Resource_Model) {
    
    file_result: File_Result = read_file(resource.filename);
    defer free_file(file_result);
    
    model: Model;
    
    if (file_result.content_size) {
        if (resource.file_type == .OBJ) {
            model = obj_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
            
        } else if (resource.file_type == .FBX) {
            
            model = fbx_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                             resource.id);
            
        } else {
            print("unimplemented model file type: %\n", resource.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    
    if model.name.count == 0 {
        model.name = resource.id;
    }
    resource.model = model;
}

load_material :: (resource: *Resource_Material) {
    
    file_result: File_Result = read_file(resource.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (resource.file_type == .MTL) {
            resource.material = mtl_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        }
        else {
            print("unimplemented material file type: %\n", resource.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}


load_texture_map :: (resource: *Resource_Texture) {
    
    file_result: File_Result = read_file(resource.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        save_to_bitmap := false;
        
        if (resource.file_type == .PNG) {
            resource.texture = png_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else if resource.file_type == .TGA {
            resource.texture = tga_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else {
            print("unimplemented texture file type: %\n", resource.file_type);
        }
        
        
        if save_to_bitmap {
            sb := String_Builder.{};
            append(*sb, "../data/test/");
            append(*sb, resource.id);
            append(*sb, ".bmp");
            bmp_name := builder_to_string(*sb);
            bitmap_save(resource.texture.pixels, resource.texture.width, resource.texture.height, bmp_name);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}

load_animation :: (resource: *Resource_Animation) {
    
    file_result: File_Result = read_file(resource.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (resource.file_type == .FBX) {
            
            animations := fbx_load_additional_animations(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                                                         resource.id);
            
            for animations {
                array_add(*resource.animations, it);
            }
            
        } else {
            print("unimplemented animation file type: %\n", resource.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}


load_animation_graph :: (resource: *Resource_Animation_Graph) {
    
    file_result: File_Result = read_file(resource.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (resource.file_type == .Animation_Graph) {
            
            resource.graph = animation_graph_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                                                  resource.id);
            
        } else {
            print("unimplemented animation file type: %\n", resource.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}


load_asset_details :: (resource: *Resource_Asset_Details) {
    
    file_result: File_Result = read_file(resource.filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (resource.file_type == .Asset_Details) {
            
            resource.details = asset_details_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                                                  resource.id);
            
        } else {
            print("unimplemented resource details file type: %\n", resource.file_type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
}








Visit_Files_Proc_Data :: struct {
    resources: *Resources;
    names:     [..]string;
};

should_gather :: (names: [..]string, name: string) -> bool {
    if names.count == 0 return true;
    found, index := array_find(names, name);
    if found return true;
    return false;
}

visit_model_files :: (file_info: File_Info, data: *void) {
    
    proc_data := cast(*Visit_Files_Proc_Data)data;
    resources := proc_data.resources;
    names     := proc_data.names;
    
    if file_info.type == {
        case .FBX; {
            found, model_name, anim_name := split_from_left(file_info.name, #char "@");
            if found {
                if should_gather(names, model_name) {
                    resource := add_resource(*resources.animations, Resource_Animation, file_info);
                    resource.id       = anim_name;
                    resource.model_id = model_name;
                }
            } else {
                if should_gather(names, file_info.name) {
                    add_resource(*resources.models, Resource_Model, file_info);
                }
            }
        }
        case .OBJ;
        if should_gather(names, file_info.name) {
            add_resource(*resources.models, Resource_Model, file_info);
        }
        case .MTL;
        if should_gather(names, file_info.name) {
            add_resource(*resources.materials, Resource_Material, file_info);
        }
        case .PNG;
#through;
        case .TGA;
        if should_gather(names, file_info.name) {
            add_resource(*resources.textures, Resource_Texture, file_info);
        }
        case .Animation_Graph;
        if should_gather(names, file_info.name) {
            add_resource(*resources.animation_graphs, Resource_Animation_Graph, file_info);
        }
        case .Asset_Details;
        if should_gather(names, file_info.name) {
            add_resource(*resources.asset_details, Resource_Asset_Details, file_info);
        }
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
    
    
    resources: *Resources = cast(*Resources)alloc(size_of(Resources));
    defer free(resources);
    
    visit_files_proc_data := Visit_Files_Proc_Data.{};
    visit_files_proc_data.resources = resources;
    
    
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
            resources: = cast(*Resources)data;
            if file_info.type ==  {
                case .PNG;
                add_resource(*resources.sprites, Resource_Sprite, file_info);
            }
        }
        visit_files_in_directory(directory_sprites, file_proc, cast(*void)resources);
        
        for * resources.sprites {
            load_sprite(it);
        }
        
        
        
        if resources.sprites.count > 0 {
            
            sorted_sprites : [..]*Resource_Sprite;
            for * resources.sprites {
                array_add(*sorted_sprites, it);
            }
            
            // Sort all of the sprites from largest to smallest. 
            // This seems to work best with our packing algorithm.
            compare_sprites :: (a: *Resource_Sprite, b: *Resource_Sprite) -> s64 {
                va := volume(a.texture);
                vb := volume(b.texture);
                if va == vb return 0;
                if va > vb return -1;
                return 1;
            }
            
            quick_sort(sorted_sprites, compare_sprites);
            
            atlas_width : u16 = 1024;
            atlas_height: u16 = 1024;
            
            atlas_builder := Atlas_Builder.{};
            atlas_builder_init(*atlas_builder, atlas_width, atlas_height);
            
            current_sprite_atlas := 1;
            next_texture_id := tprint("sprite_atlas_%", current_sprite_atlas);
            
            // Will iterate over all sprites.
            // Whenever a sprite cannot fit into the current atlas,
            // a new blank atlas will be created to continue fitting sprites.
            for sprite: sorted_sprites {
                section: = atlas_get_section_for_texture(*atlas_builder, *sprite.texture);
                if section == null {
                    // no more space anywhere
                    resource := add_resource(*resources.textures, Resource_Texture, next_texture_id);
                    resource.texture = atlas_builder.texture;
                    
                    atlas_builder_init(*atlas_builder, atlas_width, atlas_height);
                    section = *(atlas_builder.root_section);
                    
                    current_sprite_atlas += 1;
                    next_texture_id = tprint("sprite_atlas_%", current_sprite_atlas);
                }
                atlas_update_for_texure(*atlas_builder, section, sprite.texture);
                uv := atlas_add_texture(*atlas_builder, section, sprite.texture);
                sprite.texture_id = next_texture_id;
            }
            
            resource := add_resource(*resources.textures, Resource_Texture, next_texture_id);
            resource.texture = atlas_builder.texture;
            
        }
        
        
    }
    
    if process_sounds {
        file_proc :: (file_info: File_Info, data: *void) {
            resources: = cast(*Resources)data;
            if file_info.type ==  {
                case .WAV;
                add_resource(*resources.sounds, Resource_Sound, file_info);
            }
        }
        
        visit_files_in_directory(directory_sounds, file_proc, cast(*void)resources);
        
        
        for * resources.sounds {
            resource := it;
            worked := load_sound(resource);
            if worked {
            }
            else {
                resource.file_type = .Unknown;
            }
        }
        
    }
    
    if process_fonts {
        
        file_proc :: (file_info: File_Info, data: *void) {
            resources: = cast(*Resources)data;
            if file_info.type ==  {
                case .TTF;
                sizes: []u16 = .[10,12,14,16,18,20,22,24,36,42,48,50,60,72,96,144];
                
                font := add_resource(*resources.fonts, Resource_Font, file_info);
                
                for size: sizes {
                    array_add(*font.desired_pixel_sizes, size);
                    sb := String_Builder.{};
                    append(*sb, copy_string(file_info.name));
                    append(*sb, "_s_");
                    print_integer(*sb, formatInt(size));
                    array_add(*font.ids, builder_to_string(*sb));
                }
                font.desired_glyphs = DESIRED_GLYPHS_ALL;
                
            }
        }
        visit_files_in_directory(directory_fonts, file_proc, cast(*void)resources);
        
        
        
        for * resources.fonts {
            resource := it;
            
            load_font(resource);
            
            for *font: resource.fonts {
                for *glyph: font.glyphs {
                    if glyph.value == 0 continue;
                    array_add(*resource.glyphs_sorted_by_size, glyph);
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
            quick_sort(resource.glyphs_sorted_by_size, compare_glyphs);
            
            atlas_builder: Atlas_Builder = .{};
            atlas_builder_init(*atlas_builder, 128);
            
            print("Measuring font atlas ...\n");
            // Meaurement step.
            // First we iterate over all the glyphs that want
            // to fit into the font atlas, BUT without writing
            // any of their pixel data, this is so that it's faster
            // so we can just get a rough estimate of how big of a 
            // texture we'll need for it.
            for 0 .. resource.glyphs_sorted_by_size.count-1 {
                glyph := resource.glyphs_sorted_by_size[it];
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
            for 0 .. resource.glyphs_sorted_by_size.count-1 {
                glyph := resource.glyphs_sorted_by_size[it];
                section := atlas_get_section_for_texture(*atlas_builder, *glyph.texture);
                assert(section != null);
                glyph.atlas_uv = atlas_add_texture(*atlas_builder, section, glyph.texture);
            }
            print("Font atlas complete\n");
            
            texture := add_resource(*resources.textures, Resource_Texture, resource.id);
            texture.texture     = atlas_builder.texture;
            resource.texture_id = texture.id;
        }
        
        
    }
    
    
    
    if process_models {
        
        
        visit_files_in_directory(directory_models, visit_model_files, cast(*void)*visit_files_proc_data);
        
        
        for * resources.materials {
            resource := it;
            load_material(resource);
        }
        for * resources.textures {
            resource := it;
            load_texture_map(resource);
            
            array_add(*resource.track_filenames, resource.filename);
        }
        for * resources.animation_graphs {
            resource := it;
            load_animation_graph(resource);
        }
        for * resources.animations {
            resource := it;
            load_animation(resource);
        }
        for * resources.asset_details {
            resource := it;
            load_asset_details(resource);
        }
        
        
        for * resources.models {
            model_resource := it;
            
            for * resources.asset_details {
                asset_details_resource := it;
                if asset_details_resource.id == model_resource.id {
                    model_resource.asset_details = asset_details_resource.details;
                    array_add(*model_resource.track_filenames, asset_details_resource.filename);
                    break;
                }
            }
            
            
            load_model(model_resource);
            
            array_add(*model_resource.track_filenames, model_resource.filename);
            
            model := *model_resource.model;
            
            
            
            for mesh: model.meshes {
                
                if mesh.materials.count == 0 {
                    for material_id : mesh.material_names {
                        res_material := table_find_pointer(*resources.materials, material_id);
                        if res_material != null {
                            array_add_if_unique(*mesh.materials, *res_material.material);
                        }
                    }
                    
                } else {
                    for material: mesh.materials {
                        // If the mesh has materials, then they were added as part
                        // of the file processing process, like FBX files, otherwise
                        // they are already separated as a material resource from
                        // reading a unique material file.
                        resource := add_resource(*resources.materials, Resource_Material, material.name);
                        resource.material = material;
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
            
            
            
            for * resources.animations {
                animation_resource := it;
                if animation_resource.model_id == model_resource.id {
                    for animation: animation_resource.animations {
                        array_add(*model.animations, animation);
                    }
                    
                    array_add(*model_resource.track_filenames, animation_resource.filename);
                }
            }
            
            
            for * resources.animation_graphs {
                graph_resource := it;
                
                if graph_resource.id == model_resource.id {
                    model.animation_graph = graph_resource.graph;
                    
                    array_add(*model_resource.track_filenames, graph_resource.filename);
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
        
        
        for * resources.materials {
            material_resource := it;
            
            material := *material_resource.material;
            
            for 0 .. Mesh_Texture_Type.Count - 1 {
                
                tm_index := it;
                
                map_file := material.texture_map_files[tm_index];
                
                found,name,ext: = split_from_left(map_file, ".");
                if name.count > 0 {
                    for * resources.textures {
                        tex := it;
                        if equal_nocase(tex.id, name) {
                            material.texture_map_ids[tm_index] = copy_string(tex.id);
                            break;
                        }
                        
                    }
                }
            }
            
            array_add(*material_resource.track_filenames, material_resource.filename);
        }
        
    }
    
    save_final_assets(resources, bundle_file, single_files, single_files_descriptor);
    
}


