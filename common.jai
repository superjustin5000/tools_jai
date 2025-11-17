#import "Basic";
#import "String";
#import "File";


f32 :: float32;
f64 :: float64;

invalid_code_path :: (reason: string, args: .. Any) {
    assert(false, reason, args);
}


File_Result :: struct {
    content_size: s64;
    contents: *void;
};




read_file :: (filename: string) ->File_Result {
    // File reads handled by default allocator.
    // This is because they are generally freed as soon as the 
    // data is read off of them (copied if necessary).
    // The data from (read_file) should not be used for the program,
    // since generally you are allocating more things based on the 
    // data in the file anyway, not using the data from the file
    // directly.
    push_allocator(context.default_allocator);
    
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
    // File reads handled by default allocator. Explained above.
    push_allocator(context.default_allocator);
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





copy_string_to_u8_array :: (dest: []u8, src: string) {
    assert(src.count < dest.count);
    for i: 0 .. src.count-1 {
        c: u8 = src.data[i];
        dest.data[i] = c;
    }
    dest[src.count] = #char "\0";
}

c_string_length :: (src: *u8) -> s64 {
    if src == null return -1;
    len: s64 = 0;
    while (<<src != #char "\0") {
        len += 1;
        src += 1;
    }
    return len;
}

c_string_to_string :: (src: *u8) -> string {
    len: s64 = c_string_length(src);
    s: string;
    s.data  = src;
    s.count = len;
    return s;
}