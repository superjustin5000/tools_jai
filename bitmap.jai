
#import "Basic";

#import "common";
#import "image";
#import "file_io_common";

//bmp format : 
// https://www.ece.ualberta.ca/~elliott/ee552/studentAppNotes/2003_w/misc/bmp_file_format/bmp_file_format.htm

//TODO(justin): load bmp.


bitmap_save :: (raw_pixels: *Pixel, width: u32, height: u32, filename: string) {
    
    if width == 0 || height == 0 {
        print("Image size invalid, width or height is or both are 0\n");
        return;
    }
    
    
    header_size:u32       = 14;
    info_header_size: u32 = 40;
    pixel_size:u16        = 4;  // r g b (if alpha is less than 1, we'll make it black or magenta)
    // adds an extra byte for padding
    bits_per_pixel:u16    = pixel_size * 8;
    image_size:u32        = width * height * pixel_size;
    
    file_size: u32        = header_size + info_header_size + image_size;
    
    data := cast(*u8)alloc(10485760); //10 Mb
    start := data;
    defer free(start);
    
    // bmp header
    push_data(*data, 19778, u16); // code 19778 -> 01001101 01000010 -> M B 
    push_data(*data, file_size, u32); 
    push_data(*data, 0, u32);         // reserved
    push_data(*data, header_size + info_header_size, u32); // data offset
    
    // bmp infoheader
    push_data(*data, info_header_size, u32);
    push_data(*data, width, u32); 
    push_data(*data, height, u32); 
    push_data(*data, 1, u16);     // planes
    push_data(*data, bits_per_pixel, u16);
    push_data(*data, 0, u32); // compression (0 = none, 1 = 8bit RLE, 2 = 4bit RLE)
    push_data(*data, 0, u32); // image size (compressed), can be 0 if compression 0.
    push_data(*data, 0, u32); // XPelsPerMeter (deals with device resolution)
    push_data(*data, 0, u32); // YPelsPerMeter 
    push_data(*data, 16777216, u32); // number of colors 2^24
    push_data(*data, 0, u32); // number of important (necessary to display) colors, 0 = all
    
    pixels : u32 = width * height;
    
    for #v2 < row: 0 .. height-1 {
        row_pixels: *Pixel = raw_pixels + (width * row);
        for p: 0 .. width-1 {
            pixel: *Pixel = row_pixels + p;
            if pixel.a < 160 {
                push_data(*data, 255, u8);
                push_data(*data, 0, u8);
                push_data(*data, 255, u8);
            }
            else {
                push_data(*data, pixel.b, u8);
                push_data(*data, pixel.g, u8);
                push_data(*data, pixel.r, u8);
            }
            push_data(*data, pixel.a, u8); // padding.
        }
    }
    
    delete_file(filename);
    write_file(filename, cast(*void)start, file_size);
    
}