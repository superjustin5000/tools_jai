
#import "Basic";

#import "common";





Pixel :: struct {
    r,g,b,a: u8;
};


Texture :: struct {
    texture_index: u16; //index of texture loaded into graphics hardware
    width, height: u16;
    pixels: *Pixel;
}


volume :: inline (a: Texture) -> u32 {
    return cast(u32)a.width * cast(u32)a.height;
}



//only compares color, ignoring alpha.
equal :: (a: *Pixel, b: *Pixel) -> bool {
    if (a.r == b.r && 
        a.g == b.g &&
        a.b == b.b) {
        return true;
    }
    return false;
}


pixel_from_color :: (color: Color) -> Pixel {
    pixel: = Pixel.{};
    pixel.r = cast(u8)(255 * color.r);
    pixel.g = cast(u8)(255 * color.g);
    pixel.b = cast(u8)(255 * color.b);
    pixel.a = cast(u8)(255 * color.a);
    return pixel;
}






texture_free_pixels :: (img: *Texture) {
    if img.pixels != null free(img.pixels);
}



texture_clear :: (tex: *Texture, fill_color: Color) {
    dest: = tex.pixels;
    
    height: u16 = tex.height;
    width: u16 = tex.width;
    
    fill_pixel: = pixel_from_color(fill_color);
    
    for y: 0 .. height-1 {
        y_offset: = y * width;
        for x: 0 .. width-1 {
            offset: = y_offset + x;
            <<(dest + offset) = fill_pixel;
        }
    }
}






texture_create_empty :: (width: u16, height: u16) -> Texture {
    tex: = Texture.{};
    tex.width = width;
    tex.height = height;
    pixel_count: u32 = cast(u32)width * cast(u32)height;
    tex.pixels = cast(*Pixel)alloc(size_of(Pixel)*pixel_count);
    // texture_clear(*tex, fill_color);
    return tex;
}


color_alpha_blend :: (src_color: Color, dest_color: Color) -> Color {
    color: = src_color;
    color = (dest_color * (1.0 - src_color.a)) + (src_color * dest_color.a);
    return color;
}


pixel_alpha_blend :: (src: *Pixel, dest: *Pixel) {
    src_alpha: f32 = src.a / 255.0;
    one_minus_src_alpha: f32 = 1.0 - src_alpha;
    dest.r = cast(u8)(dest.r * one_minus_src_alpha + src.r * src_alpha);
    dest.g = cast(u8)(dest.g * one_minus_src_alpha + src.g * src_alpha);
    dest.b = cast(u8)(dest.b * one_minus_src_alpha + src.b * src_alpha);
    dest.a = cast(u8)(dest.a * one_minus_src_alpha + src.a * src_alpha);
}

texture_update :: (dest_tex: *Texture, dest_position: V2, src_tex: *Texture, src_position: V2, scale: V2, rotation: f32) {
    
    _scale: = scale;
    
    if rotation >= 360 {
        times: f32 = round_floorf(rotation / 360.0);
        rotation -= times * 360;
    }
    else if rotation < 0 {
        times: f32 = round_floorf(rotation / 360.0);
        rotation += times * 360;
    }
    
    //TODO: Fix jump when this changes scale and rotation. Something in the rounding makes it look like the image re-positions itself.
    if (rotation > 90 && rotation < 270) {
        _scale *= -1.0;
        rotation += 180; 
        if (rotation >= 360) {
            rotation -= 360;
        }
    }
    
    
    src_size: V2 = .{ x = cast(f32)src_tex.width, y = cast(f32)src_tex.height };
    src_scaled_size: V2 = .{ x = cast(f32)src_tex.width * absv(_scale.x), y = cast(f32)src_tex.height * absv(_scale.y) };
    dest_size: V2 = .{ x = cast(f32)dest_tex.width, y = cast(f32)dest_tex.height };
    src_rect: = rect_center_size(src_position, src_scaled_size);
    dest_rect: = rect_center_size(dest_position, dest_size);
    src_position_in_dest: V2 = src_position - dest_rect.min;
    
    contain_src_size: = src_scaled_size;
    if rotation != 0 {
        rotated: = src_rect;
        bounds: = Rect.{};
        rotate(rotation, *rotated, *bounds);
        rotate_size: = V2.{};
        rotate_size.x = bounds.max.x - bounds.min.x;
        rotate_size.y = bounds.max.y - bounds.min.y;
        contain_src_size = rotate_size;
    }
    contain_rect: = rect_center_size(dest_position, dest_size + contain_src_size);
    visible: = rect_contains_point(contain_rect, src_position);
    
    if (visible) {
        
        flipx: = false;
        flipy: = false;
        if _scale.x < 0 {
            flipx = true;
        }
        if _scale.y < 0 {
            flipy = true;
        }
        
        scale_ratio: = src_size / src_scaled_size;
        
        /*
        // HUH!?
        scale_ratio.x += EPSILON;
        scale_ratio.y += EPSILON;
*/
        
        src: = src_tex.pixels;
        dest: = dest_tex.pixels;
        
        dest_offset: = V2.{};
        dest_offset.y = (dest_rect.max.y - src_rect.max.y);
        
        src_offset: = V2.{};
        if (flipy) {
            src_offset.y = cast(f32)(src_tex.height - 1);
        }
        
        src_scaled_size_y: = cast(s32)src_scaled_size.y;
        src_scaled_size_x: = cast(s32)src_scaled_size.x;
        
        for y: 0 .. src_scaled_size_y-1 {
            
            src_row: = src + (cast(u32)src_offset.y * cast(u32)src_tex.width);
            src_offset.x = ifx !flipx then 0 else cast(f32)(src_tex.width - 1);
            
            dest_offset.x = (src_rect.min.x - dest_rect.min.x);
            
            for x: 0 .. src_scaled_size_x-1 {
                
                dest_pixel: *Pixel = null;
                final_dest_offset: = dest_offset;
                if  rotation != 0 
                {
                    final_dest_offset.y = dest_size.y - final_dest_offset.y;
                    final_dest_offset = final_dest_offset - src_position_in_dest;
                    final_dest_offset = rotate_shear_ccw(final_dest_offset, rotation);
                    final_dest_offset = src_position_in_dest + final_dest_offset;
                    final_dest_offset.y = dest_size.y - final_dest_offset.y;
                }
                if  final_dest_offset.y >= 0 && 
                    final_dest_offset.y < dest_size.y && 
                    final_dest_offset.x >= 0 && 
                    final_dest_offset.x < dest_size.x 
                {
                    dest_pixel = dest + (cast(u32)final_dest_offset.y * cast(u32)dest_tex.width) + cast(u32)final_dest_offset.x;
                    src_pixel: = src_row + cast(u32)src_offset.x;
                    pixel_alpha_blend(src_pixel, dest_pixel);
                }
                src_offset.x += ifx !flipx then scale_ratio.x else -scale_ratio.x;
                dest_offset.x += 1;
                
            }
            src_offset.y += ifx !flipy then scale_ratio.y else -scale_ratio.y;
            dest_offset.y += 1;
        }
    }
}



