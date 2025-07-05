#import "Basic";
#import "external/stb_truetype";

#import "common";
#import "image";
#import "atlas";



MIN_FONT_GLYPH :: 32;
MAX_FONT_GLYPH :: 126;
GLYPH_COUNT :: (MAX_FONT_GLYPH - MIN_FONT_GLYPH) + 1; //+1 so that 32 is inclusive in the counts


Glyph :: struct {
    value: u8;
    atlas_uv: Rect;
    vertex_index: u16;
    rect: Rect;
    advance: f32;
    texture: Texture;
}

Font :: struct {
    pixel_size: u16;
    height: f32;
    line_height: f32;
    ascent: f32;
    descent: f32;
    line_gap: f32;
    glyph_padding: u16;
    glyphs: [GLYPH_COUNT]Glyph;
    kerning: [GLYPH_COUNT][GLYPH_COUNT]f32;
    scale_factor: f32;
}


SPACE :: 32;        //ascii value for space
SPACE_REPLACE :: 77;//ascii value for 'M'


font_get_glyph :: (font: *Font, font_info: *stbtt_fontinfo, code: u8, scale_factor: f32) -> Glyph {
    
    result: Glyph = .{value = code};
    
    sdf_padding: u8 = 5;
    sdf_on_edge_value: u8 = 180;
    sdf_pix_dist_scale: f32 = 180.0; 
    
    //NOTE(justin): coincidence that 180 is the same here it just works out.
    //maybe double check this info in stb_truetype.h
    
    //padding           --  extra "pixels" around the character which are filled with the distance to the character (not 0), which allows effects like bit outlines
    
    //onedge_value      --  value 0-255 to test the SDF against to reconstruct the character (i.e. the isocontour of the character)
    
    //pixel_dist_scale  --  what value the SDF should increase by when moving one SDF "pixel" away from the edge (on the 0..255 scale) if positive, > onedge_value is inside; if negative, < onedge_value is inside
    
    width, height, xoff, yoff: s32;
    
    glyph_data: *u8;
    code_to_use:s32 = code;
    if code == SPACE {
        code_to_use = SPACE_REPLACE;
    }
    glyph_data = stbtt_GetCodepointSDF(font_info, scale_factor, code_to_use, 
                                       sdf_padding, sdf_on_edge_value, sdf_pix_dist_scale,
                                       *width, *height, *xoff, *yoff);
    
    
    fx0: = cast(f32)xoff;
    fy0: = cast(f32)yoff;
    fx1: = fx0 + cast(f32)width;
    fy1: = fy0 + cast(f32)height;
    result.rect = rect_min_max(V2.{x=fx0,y=fy0}, V2.{x=fx1,y=fy1});
    
    
    glyph_texture: Texture = .{};
    glyph_texture.width = cast(u16)(width);
    glyph_texture.height = cast(u16)(height);
    
    pixel_count: u32 = cast(u32)width * cast(u32)height;
    glyph_texture.pixels = cast(*Pixel)alloc(pixel_count * size_of(Pixel));
    
    pixel: *Pixel = glyph_texture.pixels;
    
    if code == SPACE {
        for 0 .. pixel_count-1 {
            (pixel + it).a = 0;
        }
    }
    else {
        
        buffer: *u8 = glyph_data; 
        
        for y: 0 .. glyph_texture.height-1 {
            for x: 0 .. glyph_texture.width-1 {
                
                pixel.r = 255; pixel.g = 255; pixel.b = 255;
                
                val: u8 = <<buffer;
                if cast(f32)val < (sdf_on_edge_value / 255.0) val = 0;
                pixel.a = val;
                
                buffer += 1;
                pixel += 1;
            }
        }
    }
    
    
    advance_width, left_side_bearing: s32;
    stbtt_GetCodepointHMetrics(font_info, code_to_use, *advance_width, *left_side_bearing);
    
    result.advance = advance_width * scale_factor;
    
    result.texture = glyph_texture;
    
    return result;
}









font_load :: (font_data: *u8, font_data_size: u64, desired_glyphs: string, pixel_sizes: []u16) -> []Font {
    
    font_list: [..]Font;
    
    
    font_info :stbtt_fontinfo; 
    offset := stbtt_GetFontOffsetForIndex(font_data, 0);
    
    stbtt_InitFont(*font_info, font_data, offset);
    
    for pixel_size: pixel_sizes {
        
        font:              = Font.{};
        font.pixel_size    = pixel_size;
        font.glyph_padding = pixel_size / 4;
        
        
        font.scale_factor = stbtt_ScaleForPixelHeight(*font_info, cast(f32)pixel_size);
        
        ascent: s32   = 0;
        descent: s32  = 0;
        line_gap: s32 = 0;
        stbtt_GetFontVMetrics(*font_info, *ascent, *descent, *line_gap);
        font.line_height = ((ascent - descent) * font.scale_factor);
        font.descent     = descent * font.scale_factor;
        font.ascent      = ascent * font.scale_factor;
        font.line_gap    = line_gap * font.scale_factor;
        
        for 0 .. desired_glyphs.count-1 {
            
            code: u8 = desired_glyphs[it];
            
            glyph := font_get_glyph(*font, *font_info, code, font.scale_factor);
            
            for kern_code: MIN_FONT_GLYPH .. MAX_FONT_GLYPH {
                kern: s32;
                if code == SPACE {
                    kern = stbtt_GetCodepointKernAdvance(*font_info, cast(s32)kern_code, SPACE_REPLACE);
                } else {
                    kern = stbtt_GetCodepointKernAdvance(*font_info, cast(s32)kern_code, code);
                }
                font.kerning[code-MIN_FONT_GLYPH][kern_code-MIN_FONT_GLYPH] = kern * font.scale_factor;
            }
            
            
            font.glyphs[code-MIN_FONT_GLYPH] = glyph;
        }
        
        array_add(*font_list, font);
        
    }
    return font_list;
    
}


