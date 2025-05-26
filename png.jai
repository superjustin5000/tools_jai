
#scope_file

#import "Basic";

#import "common";
#import "file_io_common";
#import "image";
#import "deflate";


PNG_Header :: struct {
    val1: u8 #align 1;
    val2: u8 #align 1;
    val3: u8 #align 1;
    val4: u8 #align 1;
    val5: u8 #align 1;
    val6: u8 #align 1;
    val7: u8 #align 1;
    val8: u8 #align 1;
} #no_padding

PNG_Chunk_Header :: struct {
    length: u32 #align 1;
    type: u32 #align 1;
} #no_padding

PNG_Chunk_Footer :: struct {
    crc: s32 #align 1;
} #no_padding

PNG_IHDR_Chunk :: struct {
    width: u32 #align 1;
    height: u32 #align 1;
    bit_depth: u8 #align 1;
    color_type: u8 #align 1;
    compression: u8 #align 1;
    filter: u8 #align 1;
    interlace: u8 #align 1;
} #no_padding


Color_Type :: enum u8 {
    GRY :: 0;
    RGB :: 2;
    IDX :: 3;
    GRYA :: 4;
    RGBA :: 6;
};



png_support_color_type :: (color_type: Color_Type) -> bool {
    result: bool = 
        color_type == .RGB ||
        color_type == .IDX ||
        color_type == .RGBA;
    return result;
}






paeth_predictor :: (a: u8, b: u8, c: u8) -> u8 {
    p: s32 = cast(s32)a + cast(s32)b - cast(s32)c;
	pa: s32 = p - cast(s32)a; if pa < 0  pa = -pa; 
    pb: s32 = p - cast(s32)b; if pb < 0  pb = -pb; 
    pc: s32 = p - cast(s32)c; if pc < 0  pc = -pc; 
	if pa <= pb && pa <= pc {
		return a;
	}
	else if pb <= pc {
		return b;
	}
	return c;
}



defilter_pass :: (start: *u8, scanline_count: u32, scanline_size: u32, bytes_per_complete_pixel: u32) {
    
    for y: 0..scanline_count-1 {
        
        scanline_start: u32 = y * scanline_size;
        scanline: *u8       = start + scanline_start;
        filter_byte: u8     = <<scanline;
        
        for x: 1..scanline_size-1 {
            cur_byte_pos: u32 = scanline_start + x;
            cur_byte: u8      = <<(start + cur_byte_pos);
            
            prev_byte: u8  = 0; 
            
            prior_byte: u8 = 0;
            if x > bytes_per_complete_pixel {
                prev_byte = <<((start + cur_byte_pos) - bytes_per_complete_pixel);
            }
            if y > 0 {
                prior_byte = <<((start + cur_byte_pos) - scanline_size);
            }
            
            if filter_byte == 1 {
                cur_byte += prev_byte;
            }
            else if filter_byte == 2 {
                cur_byte += prior_byte;
            }
            else if filter_byte == 3 {
                add: u16 = cast(u16)prev_byte + cast(u16)prior_byte;
                avg: u8 = cast(u8)(add >> 1); //floor of divide by 2.
                cur_byte += avg;
            }
            else if filter_byte == 4 {
                prev_prior_byte: u8 = 0;
                if x > bytes_per_complete_pixel && y > 0 {
                    prev_prior_byte = <<(((start + cur_byte_pos) - bytes_per_complete_pixel) - scanline_size);
                }
                paeth: u8 = paeth_predictor(prev_byte, prior_byte, prev_prior_byte);
                cur_byte += paeth;
            }
            <<(start + cur_byte_pos) = cur_byte;
        }
    }
}




png_set_pixel_color_by_byte :: (pixel: *Pixel, pixel_byte: u8, byte_data: u8, color_type: Color_Type, alpha_pixel: *Pixel, plte: *Color24, alpha_table: *u8) {
    
    if pixel_byte == 0 {
        pixel.r = byte_data;
        
        if color_type == .IDX {
            pixel.r = (plte + byte_data).r;
            pixel.g = (plte + byte_data).g;
            pixel.b = (plte + byte_data).b;
            pixel.a = <<(alpha_table + byte_data);
        }
    }
    else if (pixel_byte == 1) {
        pixel.g = byte_data;
    }
    else if (pixel_byte == 2) {
        pixel.b = byte_data;
        
        if (color_type == .RGB) {
            if (equal(pixel, alpha_pixel)) {
                pixel.a = 0;
            }
            else {
                pixel.a = 255;
            }
        }
    }
    else if (pixel_byte == 3) {
        pixel.a = byte_data;
    }
    
}




#scope_export





png_load :: (png_data: *u8, png_data_size: u64) -> Texture {
    
    texture: Texture = .{};
    
    if png_data_size == 0 return texture;
    
    
    uncompressed: *u8 = null;
    uncompressed_size: u32 = 0;
    
    color_type: Color_Type = .RGBA;
    interlace: = false;
    
    //for color type rgb
    alpha_pixel: Pixel;
    
    // for index color
    color_palette_table: *Color24 = null;
    alpha_table: *u8 = null;
    
    data: Consumeable_Data_Block = get_consumeable_data_block(png_data, png_data_size);
    
    header: = consume_data(*data, PNG_Header);
    
    if header.val1 == 137 &&
        header.val2 == 80 &&
        header.val3 == 78 &&
        header.val4 == 71 &&
        header.val5 == 13 &&
        header.val6 == 10 &&
        header.val7 == 26 &&
        header.val8 == 10 {
        
        
        IHDR_HEADER: = consume_data(*data, PNG_Chunk_Header);
        
        endian_swap(*(IHDR_HEADER.length));
        
        if IHDR_HEADER.type == magic_number("IHDR") {
            
            IHDR: = consume_data(*data, PNG_IHDR_Chunk);
            
            assert(png_support_color_type(cast(Color_Type)IHDR.color_type));
            
            
            if IHDR.width != 0 &&
                IHDR.height != 0 &&
                IHDR.bit_depth == 8 &&
                IHDR.compression == 0 &&
                IHDR.filter == 0
                
            {
                
                
                color_type = cast(Color_Type)IHDR.color_type;
                interlace = IHDR.interlace == 1;
                
                endian_swap(*IHDR.width);
                endian_swap(*IHDR.height);
                texture.width = cast(u16)IHDR.width;
                texture.height = cast(u16)IHDR.height;
                
                if interlace {
                    assert(texture.width >= 8 && texture.height >= 8);
                }
                
                size_of_pixel_data: u32 = size_of(Pixel) * cast(u32)texture.width * cast(u32)texture.height;
                texture.pixels = cast(*Pixel)alloc(size_of_pixel_data);
                uncompressed = cast(*u8)alloc(size_of_pixel_data*1000);
                
                
                consume_data(*data, PNG_Chunk_Footer);
                
                
                
                if color_type == .IDX {
                    
                    safe_counter: u32 = 100000; //preventing infinite loops
                    while safe_counter {
                        defer safe_counter -= 1;
                        
                        chunk_header: = consume_data(*data, PNG_Chunk_Header);
                        
                        header_type: string = magic_number_to_string(chunk_header.type);
                        
                        // print("PNG CHUNK HEADER: %", header_type);
                        
                        endian_swap(*(chunk_header.length));
                        
                        if chunk_header.type == magic_number("PLTE") {
                            
                            assert(chunk_header.length % 3 == 0);
                            
                            color_palette_table = cast(*Color24)consume_data_size(*data, chunk_header.length);
                            
                            
                        } 
                        else if chunk_header.type == magic_number("tRNS") {
                            
                            alpha_table = cast(*u8)consume_data_size(*data, chunk_header.length);
                            
                        }
                        else {
                            consume_data_size(*data, chunk_header.length);
                        }
                        
                        consume_data(*data, PNG_Chunk_Footer);
                        
                        if color_palette_table != null && alpha_table != null {
                            break;
                        }
                        
                    }
                    
                    assert(color_palette_table != null && alpha_table != null);
                    
                }
                
                
                compressed_chunk_data: *Deflate_Block_Data = null;
                
                safe_counter: u32 = 100000; //preventing infinite loops
                while safe_counter {
                    defer safe_counter -= 1;
                    
                    chunk_header: = consume_data(*data, PNG_Chunk_Header);
                    
                    header_type: string = magic_number_to_string(chunk_header.type);
                    // print("PNG CHUNK HEADER: %\n", header_type);
                    
                    if chunk_header.type == magic_number("IEND") {
                        break;
                    }
                    
                    endian_swap(*chunk_header.length);
                    
                    if chunk_header.type == magic_number("IDAT") {
                        
                        
                        next_compressed_chunk_data: = cast(*Deflate_Block_Data)alloc(size_of(Deflate_Block_Data));
                        next_compressed_chunk_data.next = null;
                        next_compressed_chunk_data.byte_reading_bits = 8;
                        next_compressed_chunk_data.bytes_read = 0;
                        
                        if (!compressed_chunk_data) {
                            compressed_chunk_data = next_compressed_chunk_data;
                            compressed_chunk_data.first = compressed_chunk_data;
                        }
                        else {
                            next_compressed_chunk_data.first = compressed_chunk_data.first;
                            compressed_chunk_data.next = next_compressed_chunk_data;
                            compressed_chunk_data = compressed_chunk_data.next;
                        }
                        
                        png_compressed_data_length: u32 = chunk_header.length;
                        chunk_data: = cast(*u8)consume_data_size(*data, png_compressed_data_length);
                        compressed_chunk_data.size_bytes = png_compressed_data_length;
                        compressed_chunk_data.data = chunk_data;
                        compressed_chunk_data.byte_reading = <<chunk_data;
                        
                        
                    } else {
                        
                        consume_data_size(*data, chunk_header.length);
                        
                    }
                    
                    consume_data(*data, PNG_Chunk_Footer);
                    
                }
                
                
                current_data: *Deflate_Block_Data = compressed_chunk_data.first;
                
                uncompressed_size: = deflate_decompress(current_data, uncompressed);
                
                assert(uncompressed_size > 0);
                
                
                bytes_per_complete_pixel: u8 = 4;
                if color_type == .RGB {
                    bytes_per_complete_pixel = 3;
                }
                else if color_type == .IDX {
                    bytes_per_complete_pixel = 1;
                }
                
                
                
                scanline_size: u32 = (cast(u32)texture.width * cast(u32)bytes_per_complete_pixel) + 1;
                
                if !interlace {
                    
                    defilter_pass(uncompressed, texture.height, scanline_size, bytes_per_complete_pixel);
                    
                    for y: 0 .. texture.height-1 {
                        
                        scanline_start: u32 = y * scanline_size;
                        
                        for x: 1 .. scanline_size-1 {
                            
                            cur_byte_pos: u32 = scanline_start + x;
                            cur_byte: u8      = <<(uncompressed + cur_byte_pos);
                            
                            pixel_byte: u8 = cast(u8)((x-1) % bytes_per_complete_pixel);
                            pixel_pos: u32 = (cast(u32)texture.width * y) + ((x-1) / cast(u32)bytes_per_complete_pixel);
                            
                            png_set_pixel_color_by_byte(texture.pixels + pixel_pos, pixel_byte, cur_byte, color_type, *alpha_pixel, color_palette_table, alpha_table);
                        }
                    }
                    
                }
                else {
                    
                    pix_every_col: [7] u8 = .[8,8,4,4,2,2,1];
                    pix_every_row: [7] u8 = .[8,8,8,4,4,2,2];
                    pix_start_col: [7] u8 = .[0,4,0,2,0,1,0];
                    pix_start_row: [7] u8 = .[0,0,4,0,2,0,1];
                    
                    start: *u8 = uncompressed;
                    
                    for pass: 0 .. 6 {
                        
                        pass_scanline_pixel_count: u32 = ((texture.width - (pix_start_col[pass] + 1)) / pix_every_col[pass]) + 1;
                        pass_scanline_count: u32       = ((texture.height - (pix_start_row[pass] + 1)) / pix_every_row[pass]) + 1;
                        pass_scanline_size: u32        = (cast(u32)pass_scanline_pixel_count * cast(u32)bytes_per_complete_pixel) + 1;
                        
                        defilter_pass(start, pass_scanline_count, pass_scanline_size, bytes_per_complete_pixel);
                        
                        
                        for y: 0 .. pass_scanline_count-1 {
                            
                            pixel_pos_y: u32 = cast(u32)pix_every_row[pass] * y + pix_start_row[pass];
                            
                            for x: 0 .. pass_scanline_pixel_count-1 {
                                
                                if x == 0 start+=1; //increment past the filter byte
                                
                                pixel_pos_x: u32 = cast(u32)pix_every_col[pass] * x + pix_start_col[pass];
                                
                                pixel: *Pixel = texture.pixels + (cast(u32)texture.width * cast(u32)pixel_pos_y) + pixel_pos_x;
                                
                                for pixel_byte: 0 .. bytes_per_complete_pixel-1 {
                                    cur_byte: = <<(start);
                                    
                                    png_set_pixel_color_by_byte(pixel, pixel_byte, cur_byte, color_type, *alpha_pixel, color_palette_table, alpha_table);
                                    start+=1;
                                }
                                
                            }
                        }
                    }
                }
                
            }
        }
        
        
    }
    
    free(uncompressed);
    
    return texture;
}






















