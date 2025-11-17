
#import "Basic";
#import "String";
#import "File_Utilities";

#import "common";
#import "tokenizer";

// Generates a .h file with all of the shader info defined in structs.



// These values have to match values in the 
// Shader_Input_Type enum in the engine's platform.h file.
Asset_Shader_Input_Type :: enum u32 {
    Float1  :: 0;
    Float2  :: 1;
    Float3  :: 2;
    Float4  :: 3;
    U32     :: 4;
    U32_4   :: 5;
}

// These values have to match the values in the 
// Vertex_Type enum in the engine's platform.h file.
Shader_Vertex_Type :: enum u32 {
    Standard :: 0;
    Skinned  :: 1;
    Flat     :: 2;
    Raw      :: 4;
}


Shader_Input :: struct {
    semantic_name: string;
    type: Asset_Shader_Input_Type;
    semantic_index: u16; // in the case of mulitple inputs with the same semantic name.
}


Shader_Vertex_Input :: struct {
    vertex_type: Shader_Vertex_Type;
    inputs: [16]Shader_Input;
    input_count: u8;
}


do_vertex_inputs :: (sb: *String_Builder, data: *u8, data_size: s64) {
    
    vertex_inputs : [..]Shader_Vertex_Input;
    
    tokenizer := Tokenizer.{};
    set_data_to_tokenize(*tokenizer, data, data_size);
    tokenize(*tokenizer);
    
    reader := Token_Reader.{};
    reader_init(*reader, *tokenizer);
    
    while !reader.done {
        advance_until_token_name(*reader, "struct");
        advance(*reader);
        if reader.token_at.name == "Vertex" ||
            reader.token_at.name == "Vertex_Flat" ||
            reader.token_at.name == "Vertex_Skinned" {
            
            vertex_input := Shader_Vertex_Input.{};
            
            if reader.token_at.name == "Vertex" {
                vertex_input.vertex_type = .Standard;
            } else if reader.token_at.name == "Vertex_Flat" {
                vertex_input.vertex_type = .Flat;
            } else if reader.token_at.name == "Vertex_Skinned" {
                vertex_input.vertex_type = .Skinned;
            }
            
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
                
                vertex_input.inputs[vertex_input.input_count] = input;
                vertex_input.input_count += 1;
                
            }
            
            array_add(*vertex_inputs, vertex_input);
        }
    }
    
    
    for *vertex_input : vertex_inputs {
        append(sb, sprint("{\n(Vertex_Type)%,\n {", cast(u32)vertex_input.vertex_type));
        if vertex_input.input_count > 0 {
            for 0 .. vertex_input.input_count - 1 {
                input := vertex_input.inputs[it];
                append(sb, sprint("{\"%\", (Shader_Input_Type)%, %}", input.semantic_name, cast(u32)input.type, input.semantic_index));
                if it < vertex_input.input_count - 1 { append(sb, ","); }
            }
        }
        append(sb, sprint("},\n %\n}", vertex_input.input_count));
        if it_index < vertex_inputs.count - 1 { append(sb, ","); }
        append(sb, "\n");
    }
    
}


shader_vertex_input_type :: (code_string: string) -> Shader_Vertex_Type {
    
    input_count: u8 = 0;
    
    code := code_string.data;
    
    vertex_def:         = " vert(Vertex ";
    vertex_flat_def:    = " vert(Vertex_Flat ";
    vertex_skinned_def: = " vert(Vertex_Skinned ";
    
    vertex_index         := find_index_from_left(code_string, vertex_def);
    vertex_flat_index    := find_index_from_left(code_string, vertex_flat_def);
    vertex_skinned_index := find_index_from_left(code_string, vertex_skinned_def);
    
    if (vertex_index >= 0) return .Standard;
    if (vertex_flat_index >= 0) return .Flat;
    if (vertex_skinned_index >= 0) return .Skinned;
    
    return .Raw;
    
}



do_shader_code :: (code_builder: *String_Builder, src_data: *u8, code_size_bytes: s64) {
    
    i := 0;
    while i < code_size_bytes {
        c := <<(src_data + i);
        if c == #char "\n" {
            append(code_builder, "\\n");
        }
        else if c == #char "\t" {
            append(code_builder, "\\t");
        }
        else if c == #char "\"" {
            append(code_builder, "\\\"");
        }
        else if c == #char "#" {
            
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
            do_shader_include(code_builder, filename);
            
        }
        else {
            append(code_builder, <<(src_data + i));
        }
        i += 1;
    }
    
}



do_shader_include :: (code_builder: *String_Builder, filename:string) {
    shader_include_file := read_file(filename);
    if shader_include_file.content_size > 0 {
        do_shader_code(code_builder, shader_include_file.contents, shader_include_file.content_size);
    }
}



do_shader_file :: (sb: *String_Builder, name:string, src_data: *u8, src_data_size: s64) {
    
    append(sb, sprint("{ \"%\", \"", name));
    
    code_builder: String_Builder = .{};
    code_size_bytes := src_data_size;
    
    do_shader_code(*code_builder, src_data, code_size_bytes);
    
    code := builder_to_string(*code_builder);
    code_size_bytes = code.count;
    
    append(sb, code);
    append(sb, sprint("\", %,", code_size_bytes));
    
    vertex_input_type := shader_vertex_input_type(code);
    append(sb, sprint("(Vertex_Type)%,", cast(u32)vertex_input_type));
    
    if contains(code, "vert(") {
        append(sb, sprint("true,"));
    } else {
        append(sb, sprint("false,"));
    }
    
    if contains(code, "frag(") {
        append(sb, sprint("true"));
    } else {
        append(sb, sprint("false"));
    }
    
    
    append(sb, "},\n");
    
}




main :: () {
    
    
    
    sb: String_Builder = .{};
    
    
    append(*sb, "Shader_Input_Layout shader_input_layouts[] = {\n");
    inputs_file_result := read_file("../code/shaders/inputs.sinc");
    assert(inputs_file_result.content_size > 0);
    do_vertex_inputs(*sb, xx inputs_file_result.contents, inputs_file_result.content_size);
    append(*sb, "};\n");
    
    shader_struct := #string DONE
        struct Shader_Definition {
        char         *name;
        char         *code;
        u32          code_size_bytes;
        Vertex_Type  vertex_input_type;
        bool         vert;
        bool         frag;
    };
    DONE;
    append(*sb, shader_struct);
    
    
    append(*sb, "Shader_Definition shader_definitions[] = {\n");
    
    shader_file_proc :: (info: *File_Visit_Info, user_data: *void) {
        
        file_result := read_file(info.full_name);
        
        sb := cast(*String_Builder)user_data;
        
        has_extension, name, ext := split_from_right(info.short_name, #char ".");
        if has_extension && ext == "shader" {
            do_shader_file(sb, name, xx file_result.contents, file_result.content_size);
        }
    }
    visit_files("../code/shaders", false, cast(*void)(*sb), shader_file_proc);
    
    append(*sb, "};\n");
    
    
    
    
    output := builder_to_string(*sb);
    filename := "../code/shaders.h";
    delete_file(filename);
    write_file(filename, cast(*void)output.data, output.count);
    
}
