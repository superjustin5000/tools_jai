
#import "Basic";

#import "common";
#import "image";
#import "file_io_common";


// tga format:
// https://en.wikipedia.org/wiki/Truevision_TGA

TGA_Color_Map_Type :: enum {
    None;     // 0
    Present;  // 1
    Reserved; // 2-127
    Developer;// 128-255
}

TGA_Image_Type :: enum {
    No_Data                   :: 0;
    Uncompressed_Color_Mapped :: 1;
    Uncompressed_True_Color   :: 2;
    Uncompressed_Grayscale    :: 3;
    RLE_Color_Mapped          :: 9;
    RLE_True_Color            :: 10;
    RLE_Grayscale             :: 11;
}

TGA_Color_Map_Spec :: struct {
    first_entry_index: u16;
    length:            u16;
    entry_size:        u8;
}

TGA_Image_Spec :: struct {
    x_origin:       u16;
    y_origin:       u16;
    image_width:    u16;
    image_height:   u16;
    bits_per_pixel: u8;
    bits_for_alpha: u8;
    pixels_right_to_left: bool;
    pixels_top_to_bottom: bool;
}

TGA_Extension :: struct {
    // NOTE: not supported.
}

TGA_Footer :: struct {
    // not supported.
}

TGA_Header :: struct {
    id_length:      u8;
    color_map_type: TGA_Color_Map_Type;
    image_type:     TGA_Image_Type;
    color_map_spec: TGA_Color_Map_Spec;
    image_spec:     TGA_Image_Spec;
}



tga_load :: (tga_data: *u8, tga_data_size: u64) -> Texture {
    texture: Texture = .{};
    data := get_consumeable_data_block(tga_data, tga_data_size);
    
    header : TGA_Header = .{};
    header.id_length      = consume_data_value(*data, u8);
    color_map_type_value := consume_data_value(*data, u8);
    if color_map_type_value == 0 header.color_map_type = .None;
    else if color_map_type_value == 1 header.color_map_type = .Present;
    else if color_map_type_value < 128 header.color_map_type = .Reserved;
    else header.color_map_type = .Developer;
    
    header.image_type = cast(TGA_Image_Type)consume_data_value(*data, u8);
    assert(header.image_type != .No_Data);
    
    // color map spec - 5 bytes.
    header.color_map_spec.first_entry_index = consume_data_value(*data, u16);
    header.color_map_spec.length            = consume_data_value(*data, u16);
    header.color_map_spec.entry_size        = consume_data_value(*data, u8);
    
    // image spec - 10 bytes.
    header.image_spec.x_origin       = consume_data_value(*data, u16);
    header.image_spec.y_origin       = consume_data_value(*data, u16);
    header.image_spec.image_width    = consume_data_value(*data, u16);
    header.image_spec.image_height   = consume_data_value(*data, u16);
    header.image_spec.bits_per_pixel = consume_data_value(*data, u8);
    assert(header.image_spec.bits_per_pixel != 15);
    
    image_desc := consume_data_value(*data, u8);
    header.image_spec.bits_for_alpha = image_desc & cast(u8)15;
    header.image_spec.pixels_right_to_left = (image_desc & cast(u8)16) != 0;
    header.image_spec.pixels_top_to_bottom = (image_desc & cast(u8)32) != 0;
    
    
    image_id := "";
    if header.id_length > 0 {
        sb : String_Builder = .{};
        init_string_builder(*sb);
        
        for 0 .. header.id_length-1 {
            val := consume_data_value(*data, u8);
            append(*sb, val);
        }
        image_id = builder_to_string(*sb);
    }
    
    
    
    color_map_data := null;
    if header.color_map_type == .Present && header.color_map_spec.length > 0 {
        color_map_data = consume_data_size(*data, header.color_map_spec.length);
    }
    
    
    // following is image data.
    width   := header.image_spec.image_width;
    height  := header.image_spec.image_height;
    bits_per_pixel  := cast(u32)header.image_spec.bits_per_pixel;
    bytes_per_pixel := bits_per_pixel / 8;
    total_size := cast(u32)width * cast(u32)height * bytes_per_pixel;
    
    size_of_pixel_data: u32 = size_of(Pixel) * cast(u32)width * cast(u32)height;
    texture.pixels          = cast(*Pixel)alloc(size_of_pixel_data);
    texture.width           = width;
    texture.height          = height;
    
    push_pixel :: (src: *u8, texture: *Texture, x: u32, y: u32, image_spec: TGA_Image_Spec, color_map: *u8 = null) {
        
        dest_pixel := texture.pixels;
        if image_spec.pixels_top_to_bottom == false y = (image_spec.image_height - 1) - y;
        if image_spec.pixels_right_to_left == true  x = (image_spec.image_width  - 1) - x;
        dest_pixel += (image_spec.image_width * y) + x;
        
        
        assert(color_map == null);
        if image_spec.bits_per_pixel == 24 {
            dest_pixel.b = <<src;
            dest_pixel.g = <<(src + 1);
            dest_pixel.r = <<(src + 2);
            dest_pixel.a = 255;
        } else if image_spec.bits_per_pixel == 32 {
            dest_pixel.b = <<src;
            dest_pixel.g = <<(src + 1);
            dest_pixel.r = <<(src + 2);
            dest_pixel.a = <<(src + 3);
        } else {
            print("bits_per_pixel of size % hasn't been implemented yet!", image_spec.bits_per_pixel);
            assert(false);
        }
    }
    
    
    for y: header.image_spec.y_origin .. height - 1 {
        for x: header.image_spec.x_origin .. width - 1 {
            
            rle_byte := 0;
            rle_enc  := 0;
            count    := 1; // do at least 1 pixel.
            
            if header.image_type  == .RLE_Color_Mapped ||
                header.image_type == .RLE_True_Color   ||
                header.image_type == .RLE_Grayscale {
                
                rle_byte = consume_data_value(*data, u8);
                rle_enc  = rle_byte & cast(u8)128;
                count    = (rle_byte & cast(u8)127) + 1;
                
                assert(count > 0);
            }
            
            
            if rle_enc > 0 {
                // one pixel that's the same for all iterations.
                pixel := consume_data_size(*data, bytes_per_pixel);
                for counter: 0 .. count - 1 {
                    push_pixel(pixel, *texture, x, y, header.image_spec, color_map_data);
                    if counter == count - 1 break;
                    
                    x += 1;
                    if x >= width {
                        if y == height  - 1 break;
                        y += 1;
                        x  = 0;
                    }
                }
            } else {
                for counter: 0 .. count - 1 {
                    // one new pixel PER iteration
                    pixel := consume_data_size(*data, bytes_per_pixel);
                    push_pixel(pixel, *texture, x, y, header.image_spec, color_map_data);
                    if counter == count - 1 break;
                    
                    x += 1;
                    if x >= width {
                        if y == height  - 1 break;
                        y += 1;
                        x  = 0;
                    }
                }
            }
        }
    }
    
    
    
    
    if data.at > 0 {
        // NOTE(justin): 
        // Here there is optional developer data apparently
        // Then there is optional extension data because of TGA version 2 or something.
        // Then there is the optional footer, that's probably not optional in version 2.
        // But whatever, none of that data is anything we care about.
        // But, if we do care one day...
        // there's also a detailed PDF for all the info here:
        // https://github.com/DEAKSoftware/Truevision-TGA/blob/master/truevision-tga.pdf
    }
    
    
    return texture;
}