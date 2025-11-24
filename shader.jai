
#import "Basic";
#import "String";

#import "common";
#import "tokenizer";

// Generates a .h file with all of the shader info defined in structs.



// These values have to match values in the 
// Shader_Input_Type enum in the engine's platform.h file.
// @Serialized u32
Shader_Input_Type :: enum u32 {
    Float1  :: 0;
    Float2  :: 1;
    Float3  :: 2;
    Float4  :: 3;
    U32     :: 4;
    U32_4   :: 5;
}

// These values have to match the values in the 
// Vertex_Type enum in the engine's platform.h file.
// @Serialized u32
Shader_Vertex_Type :: enum u32 {
    Standard :: 0;
    Skinned  :: 1;
    Flat     :: 2;
    Raw      :: 4;
}

Shader_Input :: struct {
    semantic_name: string;
    type: Shader_Input_Type;
    semantic_index: u16; // in the case of mulitple inputs with the same semantic name.
}


Shader_Input_Layout :: struct {
    vertex_type: Shader_Vertex_Type;
    inputs: [16]Shader_Input;
    input_count: u8;
}


Shader :: struct {
    name: string;
    input_layout: Shader_Input_Layout;
    code: string;
    vert: bool;
    frag: bool;
}




#scope_file

get_input_layout :: (code_string: string) -> Shader_Input_Layout {
    
    layout := Shader_Input_Layout.{};
    layout.vertex_type = .Raw;
    
    // Finding the vertex shader in the code will tell us
    // what kind of vertex struct we are looking for.
    // And that struct will give us the vertex layout.
    vertex_def:         = " vert(Vertex ";
    vertex_flat_def:    = " vert(Vertex_Flat ";
    vertex_skinned_def: = " vert(Vertex_Skinned ";
    
    vertex_index         := find_index_from_left(code_string, vertex_def);
    vertex_flat_index    := find_index_from_left(code_string, vertex_flat_def);
    vertex_skinned_index := find_index_from_left(code_string, vertex_skinned_def);
    
    if vertex_index >= 0 layout.vertex_type = .Standard;
    if vertex_flat_index >= 0 layout.vertex_type = .Flat;
    if vertex_skinned_index >= 0 layout.vertex_type = .Skinned;
    
    if layout.vertex_type == .Raw return layout;
    
    tokenizer := Tokenizer.{};
    set_string_to_tokenize(*tokenizer, code_string);
    tokenize(*tokenizer);
    
    reader := Token_Reader.{};
    reader_init(*reader, *tokenizer);
    
    while !reader.done {
        advance_until_token_name(*reader, "struct");
        advance(*reader);
        
        if (reader.token_at.name == "Vertex" && layout.vertex_type == .Standard) ||
        (reader.token_at.name == "Vertex_Flat" && layout.vertex_type == .Flat) ||
        (reader.token_at.name == "Vertex_Skinned" && layout.vertex_type == .Skinned) {
            
            advance(*reader); // {
            advance(*reader); 
            
            while reader.token_at.type != .Brace_Close {
                // now token layout should be exactly
                // type name : semantic_name ;
                input := Shader_Input.{};
                
                if reader.token_at.name == "uint" {
                    input.type = .U32;
                } else if reader.token_at.name == "uint4" {
                    input.type = .U32_4;
                } else if reader.token_at.name == "float" {
                    input.type = .Float1;
                } else if reader.token_at.name == "float2" {
                    input.type = .Float2;
                } else if reader.token_at.name == "float3" {
                    input.type = .Float3;
                } else if reader.token_at.name == "float4" {
                    input.type = .Float4;
                }
                
                advance(*reader); //name
                advance(*reader); //colon
                advance(*reader); 
                input.semantic_name = reader.token_at.name;
                advance(*reader); //semicolon
                
                advance(*reader);
                
                layout.inputs[layout.input_count] = input;
                layout.input_count += 1;
                
            }
            
            break;
            // Done with the input layout.
        }
    }
    
    return layout;
}


build_shader_code :: (code_builder: *String_Builder, src_data: *u8, code_size_bytes: u64) {
    
    i : u64 = 0;
    while i < code_size_bytes {
        c := <<(src_data + i);
        if c == #char "#" {
            // skip ahead past the opening quotes of the filename.
            while c != #char "\"" {
                i += 1;
                c = <<(src_data + i);
            }
            i += 1;
            c = <<(src_data + i);
            
            filename_builder : String_Builder = .{};
            append(*filename_builder, "../code/shaders/");
            
            while c != #char "\"" {
                append(*filename_builder, c);
                i += 1;
                c = <<(src_data + i);
            }
            i += 1;
            
            filename := builder_to_string(*filename_builder);
            build_shader_include(code_builder, filename);
            
        }
        else {
            append(code_builder, <<(src_data + i));
        }
        i += 1;
    }
    
}



build_shader_include :: (code_builder: *String_Builder, filename:string) {
    shader_include_file := read_file(filename);
    if shader_include_file.content_size > 0 {
        build_shader_code(code_builder, shader_include_file.contents, cast(u64)shader_include_file.content_size);
    }
    free_file(shader_include_file);
}



#scope_export



shader_load :: (data: *u8, data_size: u64, name: string) -> Shader {
    
    shader := Shader.{};
    shader.name = name;
    
    // Build the shader code from the file, 
    // since some of the shader code might include other shader files
    // we want to stitch them all together into one big string.
    code_builder: String_Builder = .{};
    build_shader_code(*code_builder, data, data_size);
    shader.code = builder_to_string(*code_builder);
    
    shader.input_layout = get_input_layout(shader.code);
    
    if contains(shader.code, "vert(") {
        shader.vert = true;
    }
    if contains(shader.code, "frag(") {
        shader.frag = true;
    }
    
    return shader;
}
