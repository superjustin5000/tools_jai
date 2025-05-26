
#import "Basic";
#import "String";


#import "common";
#import "file_io_common";

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


Shader_Input :: struct {
    semantic_name: string;
    type: Asset_Shader_Input_Type;
    semantic_index: u16; // in the case of mulitple inputs with the same semantic name.
}




do_inputs :: (sb: *String_Builder, code_string: string, inputs: []Shader_Input) -> u8 {
    
    input_count: u8 = 0;
    
    
    code := code_string.data;
    index_of_vin := find_index_from_left(code_string, "struct vin");
    
    if index_of_vin >= 0 {
        
        code += index_of_vin;
        
        c := <<code;
        while c != #char "{" { 
            code += 1; 
            c = <<code; 
        }
        
        while c != #char "}" {
            if c == #char "f" || c == #char "u" {
                
                input := inputs.data + input_count;
                input_count += 1;
                
                type_builder := String_Builder.{};
                while c != #char " " {
                    append(*type_builder , c);
                    code += 1;
                    c = <<code;
                }
                type_name := builder_to_string(*type_builder );
                
                // print("input type name: %\n", type_name);
                
                if equal(type_name, "float") {
                    input.type = .Float1;
                } else if equal(type_name, "float2") {
                    input.type = .Float2;
                } else if equal(type_name, "float3") {
                    input.type = .Float3;
                } else if equal(type_name, "float4") {
                    input.type = .Float4;
                } else if equal(type_name, "uint") {
                    input.type = .U32;
                } else if equal(type_name, "uint4") {
                    input.type = .U32_4;
                }
                
                while c != #char ":" {
                    code += 1;
                    c = <<code;
                }
                while c != #char " " {
                    code += 1;
                    c = <<code;
                }
                code += 1;
                c = <<code;
                
                reset(*type_builder);
                
                while c != #char ";" {
                    append(*type_builder, c);
                    code += 1;
                    c = <<code;
                }
                
                input.semantic_name = builder_to_string(*type_builder);
                // print("input semantic name: %\n", input.semantic_name);
            }
            code += 1;
            c = <<code;
        }
    }
    
    return input_count;
    
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
    
    inputs: [16]Shader_Input;
    input_count := do_inputs(sb, code, inputs);
    
    
    
    append(sb, "{");
    if input_count > 0 {
        for 0..input_count-1 {
            input := inputs[it];
            append(sb, "{");
            append(sb, sprint("\"%\",", input.semantic_name));
            append(sb, sprint("(Shader_Input_Type)%,", cast(u32)input.type));
            append(sb, sprint("%", input.semantic_index));
            append(sb, "},");
        }
    }
    append(sb, "},");
    append(sb, sprint("%,", input_count));
    
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
    
    shader_file_proc :: (file_info: File_Info, data: *void) {
        
        file_result := read_file(file_info.relative_path_and_filename);
        
        sb := cast(*String_Builder)data;
        
        do_shader_file(sb, file_info.name, cast(*u8)file_result.contents, file_result.content_size);
    }
    
    sb: String_Builder = .{};
    
    
    shader_struct := #string DONE
        struct Shader_Definition {
        char *name;
        char *code;
        u32 code_size_bytes;
        Shader_Input inputs[16];
        u8 input_count;
        bool vert;
        bool frag;
    };
    DONE;
    append(*sb, shader_struct);
    
    
    append(*sb, "Shader_Definition shader_definitions[] = {\n");
    visit_files_in_directory("../code/shaders", shader_file_proc, cast(*void)(*sb));
    append(*sb, "};\n");
    
    
    
    
    output := builder_to_string(*sb);
    filename := "../code/shaders.h";
    delete_file(filename);
    write_file(filename, cast(*void)output.data, output.count);
    
}
