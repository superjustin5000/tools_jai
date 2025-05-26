#scope_file

#import "common";
#import "image";

#scope_export


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
    id: u32;
    atlas: Texture;
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


