#scope_file

#import "Basic";
#import "String";
#import "Math";

#import "common";
#import "file_io_common";




#scope_export

Asset_Detail :: struct {
    type: Asset_Detail_Type;
    x: f32;
    y: f32;
    z: f32;
    m: Matrix4;
}

Asset_Details :: struct {
    name:     string;
    details:  [..]Asset_Detail;
}

Asset_Detail_Type :: enum {
    Translation;
    Rotation;
    Scale;
    Xform;
    
    Count;
}


asset_details_load :: (file_data: *u8, file_data_size: u64, name: string) -> Asset_Details {
    
    details := Asset_Details.{};
    details.name = name;
    
    data := get_consumeable_data_block(file_data, file_data_size);
    
    line_exists, line: = get_next_line(*data);
    if !line_exists return details;
    
    version:              = -1;
    current_detail_index: = -1;
    line_number:          = 0;
    
    while line_exists {
        
        line = trim(line);
        line_number += 1;
        
        if line.count <= 0 {
            line_exists, line = get_next_line(*data);
            continue;
        }
        
        if starts_with(line, "#") {
            
            found, command_name, command_value := split_from_left(line, " ");
            command_value = trim(command_value);
            
            if command_name == "#version" {
                found, left, version_string := split_from_left(line, " ");
                if !found invalid_code_path("Line %: Version number not found next to #version declaration.", line_number);
                version = parse_int(*version_string);
                
            } else {
                if version < 0 invalid_code_path("Line %: Version should be defined before anything else.", line_number);
                
                if command_name == "#translation" {
                    current_detail:      = Asset_Detail.{};
                    current_detail.type  = .Translation;
                    current_detail_index = details.details.count;
                    array_add(*details.details, current_detail);
                    
                } else if command_name == "#rotation" {
                    current_detail:      = Asset_Detail.{};
                    current_detail.type  = .Rotation;
                    current_detail_index = details.details.count;
                    array_add(*details.details, current_detail);
                    
                } else if command_name == "#scale" {
                    current_detail:      = Asset_Detail.{};
                    current_detail.type  = .Scale;
                    current_detail_index = details.details.count;
                    array_add(*details.details, current_detail);
                    
                } else {
                    invalid_code_path("Line %: Unkown command name: %.", line_number, command_name);
                }
            }
        } else {
            
            if current_detail_index < 0 { invalid_code_path("Line %: No current_details defined before reading other properties. Expected '#rotation', '#scale', etc. before this line. Or this is a dead line with non white space characters.\n", line_number);
            }
            
            found, property_name, property_value := split_from_left(line, " ");
            property_value = trim(property_value);
            
            current_detail := details.details.data + current_detail_index;
            
            if (current_detail.type == .Rotation || 
                current_detail.type == .Scale ||
                current_detail.type == .Translation) {
                if property_name == "x" {
                    current_detail.x = parse_float(*property_value);
                } else if property_name == "y" {
                    current_detail.y = parse_float(*property_value);
                } else if property_name == "z" {
                    current_detail.z = parse_float(*property_value);
                }
                
            }
            
        }
        
        line_exists, line = get_next_line(*data);
        
    }
    
    has_xform := false;
    t_matrix := translation_matrix(V3.{x=0,y=0,z=0});
    s_matrix := scaling_matrix(V3.{x=1,y=1,z=1});
    r_matrix := rotation_matrix(quaternion(V3.{x=0,y=0,z=0}));
    for details.details {
        if it.type == .Rotation {
            rotation := V3.{x=it.x,y=it.y,z=it.z};
            r_matrix = rotation_matrix(quaternion(rotation));
            has_xform = true;
            
        } else if it.type == .Scale {
            scaling := V3.{x=it.x,y=it.y,z=it.z};
            s_matrix = scaling_matrix(scaling);
            has_xform = true;
            
        } else if it.type == .Translation {
            translation := V3.{x=it.x,y=it.y,z=it.z};
            t_matrix = translation_matrix(translation);
            has_xform = true;
            
        }
    }
    if has_xform {
        xform_detail:      = Asset_Detail.{};
        xform_detail.type  = .Xform;
        xform_detail.m     = t_matrix * r_matrix * s_matrix;
        array_add(*details.details, xform_detail);
    }
    
    return details;
}