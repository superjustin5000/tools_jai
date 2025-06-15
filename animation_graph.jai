#scope_file

#import "Basic";
#import "String";
#import "common";

#import "file_io_common";




#scope_export

Animation_Graph :: struct {
    name:   string;
    states: [..]Animation_State;
    initial_state: s64;
}

Animation_State :: struct {
    name:             string; //currently 24 chars max for the game to not bug out.
    animation_name:   string;
    animation_index:  s64;
    next_state:       string;
    next_state_index: s64;
    looping:          bool;
}


animation_graph_load :: (file_data: *u8, file_data_size: u64, name: string) -> Animation_Graph {
    
    graph := Animation_Graph.{};
    graph.name = name;
    
    data := get_consumeable_data_block(file_data, file_data_size);
    
    line_exists, line: = get_next_line(*data);
    if !line_exists return graph;
    
    version             := -1;
    initial_state_name  := "";
    current_state_index := -1;
    line_number         := 0;
    
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
                
                if command_name == "#state" {
                    state := Animation_State.{};
                    state.name             = command_value;
                    state.looping          = true;
                    
                    array_add(*graph.states, state);
                    current_state_index += 1;
                    
                } else if command_name == "#initial_state" {
                    found, left, name := split_from_left(line, " ");
                    if !found invalid_code_path("Line %: Initial state name not defined after #initial_state declaration.", line_number);
                    initial_state_name = name;
                    
                }
            }
        } else {
            
            if current_state_index < 0 { invalid_code_path("Line %: State not defined before property definitions. States are defined '#state state_name' before other lines. Or This is a dead line with non white space characters.\n", line_number);
            }
            
            state := graph.states.data + current_state_index;
            
            found, property_name, property_value := split_from_left(line, " ");
            property_value = trim(property_value);
            
            if property_name == "animation" {
                state.animation_name = property_value;
                
            } else if property_name == "next_state" {
                state.next_state = property_value;
                state.looping    = false;
                
            }
        }
        
        line_exists, line = get_next_line(*data);
    }
    
    
    
    if initial_state_name.count > 0 {
        for graph.states {
            if initial_state_name == it.name {
                graph.initial_state = it_index;
                break;
            }
        }
    }
    
    
    return graph;
}