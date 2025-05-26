#import "Basic";

#import "common";
#import "image";


Atlas_Builder :: struct {
    texture: Texture;
    root_section: Atlas_Section;
}

Atlas_Section :: struct {
    occupied : bool;
    width, height: u16;
    x,y :u16;
    larger: *Atlas_Section;
    smaller: *Atlas_Section;
}


atlas_builder_init :: (builder: *Atlas_Builder, size: u16) {
    size_po2 := round_up_next_power_of_two(size);
    atlas_builder_init(builder, size_po2, size_po2);
}


atlas_builder_init :: (builder: *Atlas_Builder, width: u16, height: u16) {
    builder.texture = texture_create_empty(width, height);
    atlas_builder_reset_sections(builder, width, height);
}

atlas_builder_reset_sections :: (builder: *Atlas_Builder, width: u16, height: u16) {
    atlas_free_sections(builder);
    builder.root_section.larger = null;
    builder.root_section.smaller = null;
    builder.root_section.occupied = false;
    builder.root_section.x = 0;
    builder.root_section.y = height;
    builder.root_section.width = width;
    builder.root_section.height = height;
}


atlas_increase :: (builder: *Atlas_Builder) {
    extra_w := builder.texture.width / 2;
    extra_h := builder.texture.height / 2;
    color := Color.{r=0,g=0,b=0,a=0};
    new_texture := texture_create_empty(builder.texture.width + extra_w, builder.texture.height + extra_h);
    texture_free_pixels(*builder.texture);
    builder.texture = new_texture;
    
    atlas_builder_reset_sections(builder, builder.texture.width, builder.texture.height);
}

atlas_clear_texture :: (builder: *Atlas_Builder, clear_color: Color) {
    texture_clear(*builder.texture, clear_color);
}

atlas_get_section_for_texture :: (builder: *Atlas_Builder, texture: *Texture, margin: u16 = 1) -> *Atlas_Section {
    find_section :: (section: *Atlas_Section, texture: *Texture, margin: u16 = 1) -> *Atlas_Section {
        if section.larger != null {
            // if larger is not null,then neither is smaller and 
            // this is not a leaf.
            new_section := find_section(section.smaller, texture, margin);
            if new_section != null return new_section;
            return find_section(section.larger, texture, margin);
        }
        else {
            if section.occupied return null; //occupied leaf (endpoint reached)
            if atlas_section_fits_texture(section, texture, margin) {
                return section;
            }
            return null;
        }
    }
    return find_section(*builder.root_section, texture, margin);
}

atlas_update_for_texure :: (builder: *Atlas_Builder, section: *Atlas_Section, texture: Texture, margin: u16 = 1) {
    
    width: u16 = texture.width + margin * 2;
    height: u16 = texture.height + margin * 2;
    
    section.occupied = true;
    // if the texture doesn't perfectly fit (with margin)
    // split this section to allow more textures to fit
    if section.width > width || section.height > height {
        atlas_split_section(section, width, height);
    }
}


atlas_add_texture :: (builder: *Atlas_Builder, section: *Atlas_Section, texture: Texture, margin: u16 = 1) -> Rect {
    
    uv_for_texture: Rect = .{};
    
    width: u16 = texture.width + margin * 2;
    height: u16 = texture.height + margin * 2;
    
    position:V2 = .{
        x = section.x + width * 0.5,
        y = section.y - height * 0.5
    };
    
    //center the atlas so that its lower left corner is 0,0
    atlas_position:V2 = .{x = builder.texture.width * 0.5, y = builder.texture.height * 0.5};
    
    texture_update(*builder.texture, atlas_position, *texture, position, V2.{x=1,y=1}, 0);
    
    atlas_width  := cast(f32)builder.texture.width;
    atlas_height := cast(f32)builder.texture.height;
    uv_center    := V2.{x = position.x / atlas_width, y = position.y / atlas_height};
    uv_size      := V2.{x = texture.width / atlas_width, y = texture.height / atlas_height};
    
    uv_for_texture = rect_center_size(uv_center, uv_size);
    
    section.occupied = true;
    // if the texture doesn't perfectly fit (with margin)
    // split this section to allow more textures to fit
    if section.width > width || section.height > height {
        atlas_split_section(section, width, height);
    }
    
    return uv_for_texture;
}



#scope_file


atlas_free_sections :: (builder: *Atlas_Builder) {
    atlas_free_section :: (section: *Atlas_Section) {
        if section {
            atlas_free_section(section.larger);
            atlas_free_section(section.smaller);
            <<section = Atlas_Section.{};
            free(section);
        }
    }
    atlas_free_section(builder.root_section.larger);
    atlas_free_section(builder.root_section.smaller);
}

atlas_section_fits_texture :: (section: *Atlas_Section, texture: *Texture, margin: u16 = 1) -> bool {
    width: u16 = texture.width + margin * 2;
    height: u16 = texture.height + margin * 2;
    if width > section.width || height > section.height return false;
    return true;
}




atlas_split_section :: (section: *Atlas_Section, width: u16, height: u16) {
    
    section.larger = cast(*Atlas_Section)alloc(size_of(Atlas_Section));
    section.smaller = cast(*Atlas_Section)alloc(size_of(Atlas_Section));
    <<section.larger = Atlas_Section.{};
    <<section.smaller = Atlas_Section.{};
    
    // decide split direction
    dw := section.width - width;
    dh := section.height - height;
    
    if dw > dh {
        // larger to the right, smaller to the bottom
        section.larger.x = section.x + width;
        section.larger.y = section.y;
        section.larger.width = dw;
        section.larger.height = section.height;
        
        section.smaller.x = section.x;
        section.smaller.y = section.y - height;
        section.smaller.width = width;
        section.smaller.height = dh;
    } else {
        // larger to the bottom, smaller to the right
        section.larger.x = section.x;
        section.larger.y = section.y - height;
        section.larger.width = section.width;
        section.larger.height = dh;
        
        section.smaller.x = section.x + width;
        section.smaller.y = section.y;
        section.smaller.width = dw;
        section.smaller.height = height;
    }
    
}


