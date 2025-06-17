
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";

#import "common";



File_Result :: struct {
    content_size: s64;
    contents: *void;
};




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
    MTL;
    Animation_Graph; //custom .animation_graph extension.
    Asset_Details; //custom .asset_details extension.
};


File_Info :: struct {
    type: File_Type;
    name: string;
    relative_path_and_filename: string;
}



get_file_type :: (filename: string) -> File_Type, string {
    type: File_Type = .Unknown;
    parts := split(filename, ".");
    extension: = parts[parts.count-1];
    
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
    
    index_of_last_dot := find_index_from_right(filename, #char ".");
    name_without_extension := copy_string(slice(filename, 0, index_of_last_dot));
    
    return type, name_without_extension;
}




visit_files_in_directory :: (directory: string, proc: (file: File_Info, data: *void), data: *void) {
    
    File_Proc_And_Data :: struct {
        file_proc: (file: File_Info, data: *void);
        proc_data: *void;
    }
    proc_and_data := File_Proc_And_Data.{file_proc=proc, proc_data=data};
    
    file_and_data_proc :: (visit_info: *File_Visit_Info, proc_and_data: File_Proc_And_Data) {
        info: File_Info = .{
            relative_path_and_filename = visit_info.full_name
        };
        info.type, info.name = get_file_type(visit_info.short_name);
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




read_file :: (filename: string) ->File_Result {
    result:File_Result = .{};
    f: File;
    worked: bool;
    f, worked = file_open(filename);
    if worked {
        result.content_size, worked = file_length(f);
        if worked {
            result.contents = alloc(result.content_size);
            bytes_read: s64;
            print("reading from %, size: %\n", filename, result.content_size);
            worked, bytes_read = file_read(f, result.contents, result.content_size);
            if worked {
                result.content_size = bytes_read; //if file was somehow smaller than what we got from file_length
            } else {
                result.content_size = 0;
                result.contents = null;
            }
        }
        file_close(*f);
    } else {
        print("failed to load %\n", filename);
    }
    
    return result;
}


free_file :: (file_result: File_Result) {
    free(file_result.contents);
}


write_file :: (filename: string, data: *void, size: s64) -> bool {
    result: bool = false;
    f: File;
    worked: bool;
    f, worked = file_open(filename, true, true);
    if worked {
        print("attempting to write % bytes to %\n", size, filename);
        worked = file_write(*f, data, size);
        if !worked {
            print("failed to write % bytes into %\n", size, filename);
        }
        else result = true;
        file_close(*f);
    } else {
        print("failed to open %s for writing\n", filename);
    }
    return result;
}

delete_file :: (filename: string) -> bool {
    result := file_delete(filename);
    return result;
}




endian_swap :: (value: *u32) {
    v: u32 = <<value;
    v = (
         (v << 24) |
         ((v << 8) & 0xFF0000) |
         ((v >> 8) & 0xFF00) |
         (v >> 24)
         );
	<<value = v;
}


magic_number :: (code: string) -> u32 {
    code_data : *u32 = cast(*u32)code.data;
    code_value : u32 = <<code_data;
    return code_value;
}

magic_number_to_string:: (code : u32) -> string {
    value := tprint("XXXX");
    value.data[0] = cast, no_check(u8) (code  & 0x000000FF);
    value.data[1] = cast, no_check(u8) ((code & 0x0000FF00) >> 8);
    value.data[2] = cast, no_check(u8) ((code & 0x00FF0000) >> 16);
    value.data[3] = cast, no_check(u8) ((code & 0xFF000000) >> 24);
    return value;
}


consume_data :: (data: **u8, $T: Type) -> *T {
    return cast(*T)(consume_data_size(data, size_of(T)));
}
consume_data_value :: (data: **u8, $T: Type) -> T {
    <<consume_data(data, T);
}
//not sure if we can use below because name is just a label that gets turned into a variable name.
//#define ConsumeDataName(data, name, type) type *name = ConsumeData(data, type);



consume_data_size :: (data: **u8, size: u32) -> *u8 {
    result: *u8 = <<data;
    <<data = <<data + size;
    return result;
}

consume_data_size_long :: (data: **u8, size: u64) -> *u8 {
    result: *u8 = <<data;
    <<data = <<data + size;
    return result;
}



Consumeable_Data_Block :: struct {
    data : *u8 = ---;
    size : u64;
    remaining_size : u64;
    at: u64;
};


get_consumeable_data_block :: (data: *u8, size: u64) -> Consumeable_Data_Block {
    block: Consumeable_Data_Block = .{data=data, size=size, remaining_size=size, at = 0};
    return block;
}



//same as consume data functions and macros above but use Consumeable_Data_Block instead of just *u8

consume_data :: (block: *Consumeable_Data_Block, $T: Type) -> *T  {
    size: u64 = size_of(T);
    //print("consuming type % of size %\n", T, size);
    result := cast(*T)(consume_data_size(block, size));
    return result;
}
consume_data_value :: (block: *Consumeable_Data_Block, $T: Type) -> T {
    result : T = <<(consume_data(block, T));
    return result;
}
consume_data_size :: (block: *Consumeable_Data_Block, size: u64) -> *u8 {
    assert(block.remaining_size >= size);
    result: *u8 = block.data;
    block.data = block.data + size;
    block.remaining_size -= size;
    block.at += size;
    return result;
}


copy_data :: (dst: *u8, src: *u8, len: u32) {
    while len > 0 {
        <<dst = <<src;
        dst += 1;
        src += 1;
        len -= 1;
    }
}


push_data :: (dst: **u8, src: T, $T: Type) {
    val := consume_data(dst, T);
    <<val = src;
}

push_data :: (dst: **u8, src: *u8, T: Type) #expand {
    push_data_size(dst, src, sizeof(T));
}

push_data_size :: (dst: **u8, src: *u8, size: u32) -> u32 {
    i:u32 = 0;
    for i..size-1 {
        <<(<<dst) = <<src;
        src+=1;
        (<<dst)+=1;
    }
    return size;
}


calc_line_length :: (line_buffer: *u8, max_line_size: u32) -> u32 {
    result: u32 = 0;
    i: u32 = 0;
    for i..max_line_size-1 {
        result += 1;
        if line_buffer[i] == 0x0a {
            break;
        }
    }
    return result;
}


copy_line_to_buffer :: (buffer: *u8, line: *u8, index: *u32) {
    while true {
        i: u32 = <<index;
        <<(buffer + i) = <<line;
        <<index += 1;
        if <<line == 0x0a break;
        line += 1;
    }
}

get_next_line :: (data: *Consumeable_Data_Block) -> bool, string {
    
    line_builder := String_Builder.{};
    
    c := <<(data.data);
    
    if data.at < data.size {
        while true {
            c = consume_data_value(data, u8);
            if c == 0x0a break;
            append(*line_builder, c);
            if data.at == data.size break;
        }
        
        line:string = builder_to_string(*line_builder);
        return true, line;
    }
    return false, "";
}

