#import "Basic"()(MEMORY_DEBUGGER=true);
#import "String";
#import "Sort";
#import "Math";
#import "Hash_Table";
#import "File_Utilities";

#import "common";
#import "mathh";

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
#import "shader";


#load "asset_file.jai";



MAX_ATLAS_SPRITES :: 1024;

DESIRED_GLYPHS_ALL :: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!?@#$%^&*()-=_+[]{}\\/|<>,.;':\"`~ ";

// Resources are objects generated from individual resource files: pngs, wavs, fbxs, etc,
// OR generated files like sprite sheets that become Textures by aggregated all of the images
// in a single sprite folder.

Assets :: struct {
    sprites:          Table(string, Sprite);
    sounds:           Table(string, Sound);
    font_sets:        Table(string, Font_Set);
    models:           Table(string, Model);
    textures:         Table(string, Texture);
    materials:        Table(string, Mesh_Material);
    animations:       Table(string, Animation);
    animation_graphs: Table(string, Animation_Graph);
    asset_details:    Table(string, Asset_Details);
    shaders:          Table(string, Shader);
    
    by_type: Table(Asset_Type, *void);
}

init_assets_by_type :: (using assets: *Assets) {
    table_add(*by_type, Asset_Type.Sprite, *sprites);
    table_add(*by_type, Asset_Type.Sound, *sounds);
    table_add(*by_type, Asset_Type.Font, *font_sets);
    table_add(*by_type, Asset_Type.Model, *models);
    table_add(*by_type, Asset_Type.Texture, *textures);
    table_add(*by_type, Asset_Type.Material, *materials);
    table_add(*by_type, Asset_Type.Animation, *animations);
    table_add(*by_type, Asset_Type.Animation_Graph, *animation_graphs);
    table_add(*by_type, Asset_Type.Asset_Details, *asset_details);
    table_add(*by_type, Asset_Type.Shader, *shaders);
}



Asset_Info :: struct {
    id:               string;
    asset_type:       Asset_Type;
    track_filenames:  [..]string;
}


Asset_Data :: struct {
    names:          [..]string;
    asset_types:    [ASSET_TYPE_COUNT]bool;
    files:          [ASSET_TYPE_COUNT][..]File_Info;
    asset_infos:    [ASSET_TYPE_COUNT]Table(string, Asset_Info);
    assets:         Assets;
};

add_asset_info :: (asset_data: *Asset_Data, asset_type: Asset_Type, id: string) -> *Asset_Info {
    using asset_data;
    info := table_add(*asset_infos[asset_type], id, Asset_Info.{id=id, asset_type=asset_type});
    return info;
}

add_asset :: (asset_data: *Asset_Data, asset_type: Asset_Type, id: string, $T: Type, asset: T) {
    using asset_data;
    found, table := table_find(*assets.by_type, asset_type);
    assert(found);
    table_add(cast(*Table(string, T))table, id, asset);
    add_asset_info(asset_data, asset_type, id);
}

add_asset_track_filename :: (asset_data: *Asset_Data, id: string, asset_type: Asset_Type, filename: string) {
    using asset_data;
    info := table_find_pointer(*asset_infos[asset_type], id);
    assert(info != null);
    array_add(*info.track_filenames, filename);
}


set_asset_types_to_load :: (asset_data: *Asset_Data, types: []Asset_Type) {
    for asset_types {
        found, index := array_find(types, it);
        asset_data.asset_types[it] = found;
    }
}

set_asset_types_to_NOT_load :: (asset_data: *Asset_Data, types: []Asset_Type) {
    for asset_types {
        found, index := array_find(types, it);
        if (found) {
            asset_data.asset_types[it] = false;
        }
    }
}



main :: () {
    
    asset_data := Asset_Data.{};
    init_assets_by_type(*asset_data.assets);
    
    bundle_file:     bool = true;
    single_files:    bool = true;
    
    // Load all asset types by default.
    for asset_types {
        asset_data.asset_types[it] = true;
    }
    
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
                
                array_add(*asset_data.names, next);
                
                set_asset_types_to_load(*asset_data, .[.Model]);
                bundle_file = false;
                
            } else if arg == "texture" {
                if next.count == 0 invalid_code_path("Argument 'texture' found but no name specified.");
                
                it += 1;
                
                array_add(*asset_data.names, next);
                
                set_asset_types_to_load(*asset_data, .[.Texture]);
                bundle_file = false;
                
            } else if arg == "material" {
                if next.count == 0 invalid_code_path("Argument 'material' found but no name specified.");
                
                it += 1;
                
                array_add(*asset_data.names, next);
                
                set_asset_types_to_load(*asset_data, .[.Material]);
                bundle_file = false;
                
            } else if arg == "animation_graph" {
                if next.count == 0 invalid_code_path("Argument 'animation_graph' found but no name specified.");
                
                it += 1;
                
                array_add(*asset_data.names, next);
                
                set_asset_types_to_load(*asset_data, .[.Animation_Graph]);
                bundle_file = false;
                
            } else if arg == "asset_details" {
                if next.count == 0 invalid_code_path("Argument 'asset_details' found but no name specified.");
                
                it += 1;
                
                array_add(*asset_data.names, next);
                
                set_asset_types_to_load(*asset_data, .[.Asset_Details]);
                bundle_file = false;
                
            } else if arg == "sprite_atlas" {
                if next.count == 0 invalid_code_path("Argument 'sprite_atlas' found but no name specified.");
                
                it += 1;
                
                array_add(*asset_data.names, next);
                
                set_asset_types_to_load(*asset_data, .[]);
                bundle_file = false;
                
            } else if arg == "sound" {
                if next.count == 0 invalid_code_path("Argument 'sound' but no name specified.");
                
                it += 1;
                
                array_add(*asset_data.names, next);
                
                set_asset_types_to_load(*asset_data, .[.Sound]);
                bundle_file = false;
                
            } else if arg == "font" {
                if next.count == 0 invalid_code_path("Argument 'font' found but no name specified.");
                
                it += 1;
                
                array_add(*asset_data.names, next);
                
                set_asset_types_to_load(*asset_data, .[.Font]);
                bundle_file = false;
                
            } else if arg == "shader" {
                if next.count == 0 invalid_code_path("Argument 'shader' found but no name specified.");
                
                it += 1;
                
                array_add(*asset_data.names, next);
                
                set_asset_types_to_load(*asset_data, .[.Shader]);
                bundle_file = false;
                
            } else if arg == "no_models" {
                set_asset_types_to_NOT_load(*asset_data, .[.Model]);
                
            } else if arg == "no_textures" {
                set_asset_types_to_NOT_load(*asset_data, .[.Texture]);
                
            } else if arg == "no_materials" {
                set_asset_types_to_NOT_load(*asset_data, .[.Material]);
                
            } else if arg == "no_animation_graphs" {
                set_asset_types_to_NOT_load(*asset_data, .[.Animation_Graph]);
                
            } else if arg == "no_asset_details" {
                set_asset_types_to_NOT_load(*asset_data, .[.Asset_Details]);
                
            } else if arg == "no_sprites" {
                set_asset_types_to_NOT_load(*asset_data, .[.Sprite]);
                
            } else if arg == "no_sounds" {
                set_asset_types_to_NOT_load(*asset_data, .[.Sound]);
                
            } else if arg == "no_fonts" {
                set_asset_types_to_NOT_load(*asset_data, .[.Font]);
                
            } else if arg == "no_shaders" {
                set_asset_types_to_NOT_load(*asset_data, .[.Shader]);
                
            } else if arg == "no_singles" {
                single_files = false;
                
            } else if arg == "no_bundle" {
                bundle_file = false;
                
            } else if arg == "no_files" {
                bundle_file  = false;
                single_files = false;
            }
        }
        
    }
    
    gather_files(*asset_data);
    process_resources(*asset_data);
    save_final_assets(*asset_data, bundle_file, single_files);
    
}











gather_files :: (asset_data: *Asset_Data) {
    
    directory_models  := "../resources/models";
    directory_sprites := "../resources/sprites";
    directory_sounds  := "../resources/sounds";
    directory_fonts   := "../resources/fonts";
    directory_shaders := "../code/shaders";
    
    should_gather :: (names: []string, name: string) -> bool {
        if names.count == 0 return true;
        found, index := array_find(names, name);
        if found return true;
        return false;
    }
    
    
    get_file_infos :: (names: []string, file_types: []File_Type, directory: string) -> []File_Info {
        
        file_infos : [..]File_Info;
        
        Get_File_Info_Data :: struct {
            names:      []string;
            file_types: []File_Type;
            file_infos: *[..]File_Info;
        }
        
        file_proc :: (file_info: File_Info, data: *void) {
            get_file_info_data := cast(*Get_File_Info_Data)data;
            names      := get_file_info_data.names;
            file_types := get_file_info_data.file_types;
            file_infos := get_file_info_data.file_infos;
            
            found, index := array_find(file_types, file_info.type);
            if (found) {
                if should_gather(names, file_info.name) {
                    array_add(file_infos, file_info);
                    // add_resource(table, type, file_info);
                }
            }
        }
        
        get_file_info_data : Get_File_Info_Data;
        get_file_info_data.names      = names;
        get_file_info_data.file_types = file_types;
        get_file_info_data.file_infos = *file_infos;
        visit_files_in_directory(directory, file_proc, cast(*void)*get_file_info_data);
        
        return file_infos;
    }
    
    
    if asset_data.asset_types[Asset_Type.Sprite] {
        types := File_Type.[.PNG, .TGA];
        file_infos := get_file_infos(asset_data.names, types, directory_sprites);
        for file_infos array_add(*asset_data.files[Asset_Type.Sprite], it);
    }
    
    if asset_data.asset_types[Asset_Type.Sound] {
        types: = File_Type.[.WAV];
        file_infos := get_file_infos(asset_data.names, types, directory_sounds);
        for file_infos array_add(*asset_data.files[Asset_Type.Sound], it);
    }
    
    if asset_data.asset_types[Asset_Type.Font] {
        types: = File_Type.[.TTF];
        file_infos := get_file_infos(asset_data.names, types, directory_fonts);
        for file_infos array_add(*asset_data.files[Asset_Type.Font], it);
    }
    
    if asset_data.asset_types[Asset_Type.Model] {
        types := File_Type.[.FBX, .FBX_Animation_Only, .OBJ];
        file_infos := get_file_infos(asset_data.names, types, directory_models);
        for file_infos array_add(*asset_data.files[Asset_Type.Model], it);
    }
    
    // TODO: Add separate entry for animation types.
    // Even though right now it seems ok that animations are hard-linked
    // to models.
    
    if asset_data.asset_types[Asset_Type.Texture] {
        types: = File_Type.[.PNG, .TGA];
        file_infos := get_file_infos(asset_data.names, types, directory_models);
        for file_infos array_add(*asset_data.files[Asset_Type.Texture], it);
    }
    
    if asset_data.asset_types[Asset_Type.Material] {
        types: = File_Type.[.MTL];
        file_infos := get_file_infos(asset_data.names, types, directory_models);
        for file_infos array_add(*asset_data.files[Asset_Type.Material], it);
    }
    
    if asset_data.asset_types[Asset_Type.Animation_Graph] {
        types: = File_Type.[.Animation_Graph];
        file_infos := get_file_infos(asset_data.names, types, directory_models);
        for file_infos array_add(*asset_data.files[Asset_Type.Animation_Graph], it);
    }
    
    if asset_data.asset_types[Asset_Type.Asset_Details] {
        types := File_Type.[.Asset_Details];
        file_infos := get_file_infos(asset_data.names, types, directory_models);
        for file_infos array_add(*asset_data.files[Asset_Type.Asset_Details], it);
    }
    
    if asset_data.asset_types[Asset_Type.Shader] {
        types := File_Type.[.Shader];
        file_infos := get_file_infos(asset_data.names, types, directory_shaders);
        for file_infos array_add(*asset_data.files[Asset_Type.Shader], it);
    }
    
}






#scope_file

File_Type :: enum {
    Unknown;
    PNG;
    BMP;
    TGA;
    WAV;
    OTF;
    TTF;
    Shader; //custom .shader extension.
    OBJ;
    FBX;
    FBX_Animation_Only; // When an fbx is in the form model_name@animation_name.fbx
    MTL;
    Animation_Graph; //custom .animation_graph extension.
    Asset_Details; //custom .asset_details extension.
};


File_Info :: struct {
    type: File_Type;
    name: string;
    sub_name: string; // When the file type is FBX_Animation_Only
    relative_path_and_filename: string;
}



get_file_type :: (filename: string) -> File_Info {
    file_info := File_Info.{};
    
    type: File_Type = .Unknown;
    
    has_extension, name, extension := split_from_right(filename, ".");
    
    if (has_extension) {
        
        if extension ==  {
            case "png";
#through;
            case "PNG";
            type = .PNG;
            
            case "bmp";
#through;
            case "BMP";
            type = .BMP;
            
            case "tga";
#through;
            case "TGA";
            type = .TGA;
            
            case "wav";
#through;
            case "WAV";
            type = .WAV;
            
            case "otf";
#through;
            case "OTF";
            type = .OTF;
            
            case "ttf";
#through;
            case "TTF";
            type = .TTF;
            
            case "shader";
            type = .Shader;
            
            case "obj";
            type = .OBJ;
            
            case "mtl";
            type = .MTL;
            
            case "fbx";
#through;
            case "FBX";
            type = .FBX;
            
            case "animation_graph";
            type = .Animation_Graph;
            
            case "asset_details";
            type = .Asset_Details;
        }
    }
    
    
    file_info.type = type;
    
    at_found, main_name, sub_name := split_from_left(name, #char "@");
    if at_found {
        file_info.name = main_name;
        file_info.sub_name = sub_name;
        
        if file_info.type == .FBX file_info.type = .FBX_Animation_Only;
        
    } else {
        file_info.name = name;
    }
    
    return file_info;
}




visit_files_in_directory :: (directory: string, proc: (file: File_Info, data: *void), data: *void) {
    
    File_Proc_And_Data :: struct {
        file_proc: (file: File_Info, data: *void);
        proc_data: *void;
    }
    proc_and_data := File_Proc_And_Data.{file_proc=proc, proc_data=data};
    
    file_and_data_proc :: (visit_info: *File_Visit_Info, proc_and_data: File_Proc_And_Data) {
        info := get_file_type(visit_info.short_name);
        info.relative_path_and_filename = visit_info.full_name;
        if info.type != .Unknown {
            proc_and_data.file_proc(info, proc_and_data.proc_data);
        }
    }
    
    completed: = visit_files(directory, true, proc_and_data, file_and_data_proc, visit_files=true, visit_directories=false);
    if !completed
        print("Something went wrong with: visit_files_in_directory\n");
    // else
    // print("something went right\n");
    
}









process_resources :: (asset_data: *Asset_Data) {
    
    
    sprites:          = *asset_data.assets.sprites;
    sounds:           = *asset_data.assets.sounds;
    font_sets:        = *asset_data.assets.font_sets;
    models:           = *asset_data.assets.models;
    textures:         = *asset_data.assets.textures;
    materials:        = *asset_data.assets.materials;
    animations:       = *asset_data.assets.animations;
    animation_graphs: = *asset_data.assets.animation_graphs;
    asset_details:    = *asset_data.assets.asset_details;
    shaders:          = *asset_data.assets.shaders;
    
    
    for asset_types {
        type : Asset_Type = cast(Asset_Type)it;
        
        files := asset_data.files[type];
        for * files {
            if type == .Sprite {
                sprite := load_sprite(it);
                add_asset(asset_data, .Sprite, it.name, Sprite, sprite);
                // TODO: Haven't worked out how to update sprite assets yet.
                // Probably make it so.. just like fonts,
                // they are one asset as a sprite_sheet
                // And then can just be loaded all at once,
                // and then add EVERY sprite as a track filename to that asset
                // so if any sprite changes, it rebuilds the entire sprite sheet.
                // Then probably every sprite sheeet would need its own named folder
                // where all sprites for that sheet live inside.
                // Or operate in two passes, where the first pass generates sprite sheets
                // then that sprite sheet is the only asset that the asset builder cares
                // about and the only filename to be tracked. Then
                // whenever sprite sheets are rebuilt, that would trigger the reload.
            } else if type == .Sound {
                worked, sound := load_sound(it);
                if worked {
                    add_asset(asset_data, type, it.name, Sound, sound);
                    add_asset_track_filename(asset_data, it.name, type, it.relative_path_and_filename);
                }
                
            } else if type == .Font {
                font_set := load_font_set(it);
                add_asset(asset_data, type, it.name, Font_Set, font_set);
                add_asset_track_filename(asset_data, it.name, type, it.relative_path_and_filename);
                
            } else if type == .Material {
                material_asset_name: = it.name;
                material_file:       = it.relative_path_and_filename;
                materials:           = load_materials(it);
                for *mat : materials {
                    add_asset(asset_data, type, mat.name, Mesh_Material, mat);
                    add_asset_track_filename(asset_data, mat.name, type, material_file);
                }
                
            } else if type == .Texture {
                texture := load_texture(it);
                add_asset(asset_data, type, it.name, Texture, texture);
                add_asset_track_filename(asset_data, it.name, type, it.relative_path_and_filename);
                
            } else if type == .Animation_Graph {
                animation_graph := load_animation_graph(it);
                add_asset(asset_data, type, it.name, Animation_Graph, animation_graph);
                add_asset_track_filename(asset_data, it.name, type, it.relative_path_and_filename);
                
            } else if type == .Asset_Details {
                asset_details := load_asset_details(it);
                add_asset(asset_data, type, it.name, Asset_Details, asset_details);
                add_asset_track_filename(asset_data, it.name, type, it.relative_path_and_filename);
                
            } else if type == .Shader {
                shader := load_shader(it);
                add_asset(asset_data, type, it.name, Shader, shader);
                add_asset_track_filename(asset_data, it.name, type, it.relative_path_and_filename);
                
            } else if type == .Model {
                if it.type == .FBX_Animation_Only {
                    animation := load_animation(it);
                    add_asset(asset_data, .Animation, it.sub_name, Animation, animation);
                } else {
                    model := load_model(it);
                    add_asset(asset_data, type, it.name, Model, model);
                }
                // TODO: Until animations are made independent of models,
                // the animation file is added as a trackfile for the model.
                add_asset_track_filename(asset_data, it.name, type, it.relative_path_and_filename);
            }
            
        }
        
        
    }
    
    
    
    if sprites.count > 0 {
        
        sorted_sprites : [..]*Sprite;
        for * sprites {
            array_add(*sorted_sprites, it);
        }
        
        // Sort all of the sprites from largest to smallest. 
        // This seems to work best with our packing algorithm.
        compare_sprites :: (a: *Sprite, b: *Sprite) -> s64 {
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
        next_texture_id := sprint("sprite_atlas_%", current_sprite_atlas);
        
        // Will iterate over all sprites.
        // Whenever a sprite cannot fit into the current atlas,
        // a new blank atlas will be created to continue fitting sprites.
        for sprite: sorted_sprites {
            section: = atlas_get_section_for_texture(*atlas_builder, *sprite.texture);
            if section == null {
                // no more space anywhere
                // commit what's already in the texture to the 
                // texture assets and start a new atlas.
                add_asset(asset_data, .Texture, next_texture_id, Texture, atlas_builder.texture);
                
                atlas_builder_init(*atlas_builder, atlas_width, atlas_height);
                section = *(atlas_builder.root_section);
                
                current_sprite_atlas += 1;
                next_texture_id = sprint("sprite_atlas_%", current_sprite_atlas);
            }
            atlas_update_for_texure(*atlas_builder, section, sprite.texture);
            sprite.uv = atlas_add_texture(*atlas_builder, section, sprite.texture);
            sprite.atlas_texture_id = next_texture_id;
        }
        
        add_asset(asset_data, .Texture, next_texture_id, Texture, atlas_builder.texture);
        
    }
    
    
    for *font_set: font_sets {
        
        glyphs_sorted_by_size: [..]*Glyph;
        for *font: font_set.fonts {
            for *glyph: font.glyphs {
                if glyph.value == 0 continue;
                array_add(*glyphs_sorted_by_size, glyph);
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
        quick_sort(glyphs_sorted_by_size, compare_glyphs);
        
        atlas_builder: Atlas_Builder = .{};
        atlas_builder_init(*atlas_builder, 128);
        
        print("Measuring font atlas ...\n");
        // Meaurement step.
        // First we iterate over all the glyphs that want
        // to fit into the font atlas, BUT without writing
        // any of their pixel data, this is so that it's faster
        // so we can just get a rough estimate of how big of a 
        // texture we'll need for it.
        for glyph: glyphs_sorted_by_size {
            section := atlas_get_section_for_texture(*atlas_builder, *glyph.texture);
            if section == null {
                atlas_increase(*atlas_builder);
                section = *(atlas_builder.root_section);
                it_index = 0; //we have to start over to reset all the uvs and better management of empty spaces.
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
        for glyph: glyphs_sorted_by_size {
            section := atlas_get_section_for_texture(*atlas_builder, *glyph.texture);
            assert(section != null);
            glyph.atlas_uv = atlas_add_texture(*atlas_builder, section, glyph.texture);
        }
        print("Font atlas complete\n");
        
        add_asset(asset_data, .Texture, font_set.atlas_texture_id, Texture, atlas_builder.texture);
        
    }
    
    
    for * models {
        id, model := it_index, it;
        
        for asset_details {
            details_id, details := it_index, it;
            if details_id == id {
                model.asset_details_id = details_id;
                break;
            }
        }
        
        for animation_graphs {
            graph_id, graph := it_index, it;
            if graph_id == id {
                model.animation_graph_id = graph_id;
                break;
            }
        }
        
        
        for mesh: model.meshes {
            
            if mesh.materials.count == 0 {
                for material_id : mesh.material_names {
                    material := table_find_pointer(materials, material_id);
                    if material != null {
                        array_add_if_unique(*mesh.materials, material);
                    }
                }
                
            } else {
                for material: mesh.materials {
                    // If the mesh has materials, then they were added as part
                    // of the file processing process, like FBX files, otherwise
                    // they are already separated as a material resource from
                    // reading a unique material file.
                    add_asset(asset_data, .Material, material.name, Mesh_Material, material);
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
        
        
        for *animation: animations {
            if animation.model_id == id {
                array_add(*model.animations, animation);
                
                // TODO:
                // Models will depend on animations since they end up getting bundled
                // together into one asset. These are the animation files that are marked
                // with the '@' symbol in the filename.
                // Will need a way to link the trackfiles, OR find a way to separate them
                // so that in the engine even, models have an array of animation asset keys.
                // Or the model doesn't have to care about the linking, it would be up to
                // the designer or programmer to say: Entity, you are assigned model X and you 
                // should play animation Y, and if that animation is incompatible with that model
                // for whatever reason, it will generate an error.
                // And that's really what the animation graph should define anyway.
                // So maybe the animation graph shouldn't be part of the model, but part of the 
                // entity, or entity type? or whatever name we want to give it, since it could
                // be shared between many entities (most likely type), and a single type
                // could have many animation graphs dependnig on state as well.
                
            }
        }
        
    }
    
    
    
    
    for *material: materials {
        
        for 0 .. Mesh_Texture_Type.Count - 1 {
            
            tm_index := it;
            
            map_file := material.texture_map_files[tm_index];
            
            found,name,ext: = split_from_left(map_file, ".");
            if name.count > 0 {
                for * textures {
                    tex_id, tex := it_index, it;
                    if equal_nocase(tex_id, name) {
                        material.texture_map_ids[tm_index] = copy_string(tex_id);
                        break;
                    }
                    
                }
            }
        }
        
    }
    
}










DEBUG_SAVE_IMAGES_TO_BITMAP :: false;


load_sprite :: (file: *File_Info) -> Sprite {
    
    sprite : Sprite;
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    if file_result.content_size {
        
        if file.type == .PNG {
            sprite.texture = png_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else if file.type == .TGA {
            sprite.texture = tga_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else {
            print("unimplemented texture file type: %\n", file.type);
        }
        
        if DEBUG_SAVE_IMAGES_TO_BITMAP {
            sb := String_Builder.{};
            append(*sb, "../data/test/");
            append(*sb, file.name);
            append(*sb, ".bmp");
            bmp_name := builder_to_string(*sb);
            bitmap_save(sprite.texture.pixels, sprite.texture.width, sprite.texture.height, bmp_name);
        }
    }
    else {
        print("err (content_size): %\n", file_result.content_size);
    }
    
    return sprite;
}



load_font_set :: (file: *File_Info) -> Font_Set {
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (file.type == .TTF) {
            
            sizes: []u16 = .[10,12,14,16,18,20,22,24,36,42,48,50,60,72,96,144];
            
            font_set := font_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size, DESIRED_GLYPHS_ALL, sizes);
            
            font_set.atlas_texture_id = file.name;
            
            for * font_set.fonts {
                it.id = sprint("%_s_%", file.name, it.pixel_size);
            }
            
            return font_set;
        }
        else {
            print("unimplemented font file type: %\n", file.type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    
    return Font_Set.{};
}




load_sound :: (file: *File_Info) -> bool, Sound {
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (file.type == .WAV) {
            worked, sound: = wav_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
            if (worked) {
                return true, sound;
            } else {
                print("failed to load sound (possibly unsupported encoding): %\n", file.relative_path_and_filename);
            }
        }
        else {
            print("unimplemented sound file type: %\n", file.type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    return false, Sound.{};
}




load_model :: (file: *File_Info) -> Model {
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    model: Model;
    
    if (file_result.content_size) {
        if (file.type == .OBJ) {
            model = obj_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
            
        } else if (file.type == .FBX) {
            
            model = fbx_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                             file.name);
            
        } else {
            print("unimplemented model file type: %\n", file.type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    
    if model.name.count == 0 {
        model.name = file.name;
    }
    
    return model;
}

load_materials :: (file: *File_Info) -> []Mesh_Material {
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (file.type == .MTL) {
            materials := mtl_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
            return materials;
        }
        else {
            print("unimplemented material file type: %\n", file.type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    
    empty_array : [..]Mesh_Material;
    return empty_array;
}


load_texture :: (file: *File_Info) -> Texture {
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    texture := Texture.{};
    
    if (file_result.content_size) {
        save_to_bitmap := false;
        
        if (file.type == .PNG) {
            texture = png_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else if file.type == .TGA {
            texture = tga_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size);
        } else {
            print("unimplemented texture file type: %\n", file.type);
        }
        
        
        if DEBUG_SAVE_IMAGES_TO_BITMAP {
            if texture.pixels {
                sb := String_Builder.{};
                append(*sb, "../data/test/");
                append(*sb, file.name);
                append(*sb, ".bmp");
                bmp_name := builder_to_string(*sb);
                bitmap_save(texture.pixels, texture.width, texture.height, bmp_name);
            }
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    
    return texture;
}

load_animation :: (file: *File_Info) -> Animation {
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    
    if (file_result.content_size) {
        if (file.type == .FBX_Animation_Only) {
            
            anims := fbx_load_additional_animations(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                                                    file.sub_name);
            for anims {
                it.model_id = file.name;
            }
            // TODO:
            // This could load multiple animations in 
            // a single fbx file.
            if anims.count > 0 return anims.data[0];
            
        } else {
            print("unimplemented animation file type: %\n", file.type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    
    return Animation.{};
}


load_animation_graph :: (file: *File_Info) -> Animation_Graph {
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    graph := Animation_Graph.{};
    
    if (file_result.content_size) {
        if (file.type == .Animation_Graph) {
            
            graph = animation_graph_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                                         file.name);
            
        } else {
            print("unimplemented animation graph file type: %\n", file.type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    
    return graph;
}


load_asset_details :: (file: *File_Info) -> Asset_Details {
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    
    if (file_result.content_size) {
        if (file.type == .Asset_Details) {
            
            return asset_details_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                                      file.name);
            
        } else {
            print("unimplemented asset details file type: %\n", file.type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    
    return Asset_Details.{};
}

load_shader :: (file: *File_Info) -> Shader {
    
    file_result: File_Result = read_file(file.relative_path_and_filename);
    defer free_file(file_result);
    
    if (file_result.content_size) {
        if (file.type == .Shader) {
            return shader_load(cast(*u8)file_result.contents, cast(u64)file_result.content_size,
                               file.name);
        } else {
            print("unimplemented shader file type: %\n", file.type);
        }
    }
    else {
        print("err (conent_size): %\n", file_result.content_size);
    }
    return Shader.{};
}









#program_export asset_builder_process_asset :: (name: *u8, type: Asset_Type, data_size: *u32 = null) -> *void #c_call {
    if name == null return null;
    
    file_data := SJ_Asset_Single_File_Data.{};
    
    push_context {
        use_pool_allocator();
        
        name_string := c_string_to_string(name);
        
        asset_data  := Asset_Data.{};
        init_assets_by_type(*asset_data.assets);
        
        array_add(*asset_data.names, name_string);
        set_asset_types_to_load(*asset_data, .[type]);
        gather_files(*asset_data);
        process_resources(*asset_data);
        file_datas := save_final_assets(*asset_data, false, true);
        assert(file_datas.datas[type].count == 1);
        file_data = file_datas.datas[type][0];
    }
    
    if data_size != null then <<data_size = cast(u32)file_data.data_size;
    return file_data.data;
}


// Warning! Not calling this when done processing files, while not necessarily bad,
// WILL leave whatever was last processed hanging around in memory.
#program_export asset_builder_free_data :: () #c_call {
    push_context {
        end_pool_allocator();
    }
}



#import "Flat_Pool";
pool: Flat_Pool;
pool_allocator:     = Allocator.{};
previous_allocator: = Allocator.{};

use_pool_allocator :: () {
    if previous_allocator.proc != null {
        end_pool_allocator();
    }
    pool_allocator.proc = flat_pool_allocator_proc;
    pool_allocator.data = *pool;
    previous_allocator  = context.allocator;
    context.allocator   = pool_allocator;
}

end_pool_allocator :: () {
    assert(previous_allocator.proc != null);
    reset(*pool);
    context.allocator = previous_allocator;
}

