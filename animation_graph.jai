#scope_file

#import "Basic";
#import "String";
#import "common";

#import "file_io_common";




#scope_export

Animation_Graph :: struct {
    name:   string;
    states: [..]Animation_State;
    default_state: s64;
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
    
    version := -1;
    default_state_name := "";
    
    while line_exists {
        
        if line.count <= 0 {
            line_exists, line = get_next_line(*data);
            continue;
        }
        
        if starts_with(line, "#") {
            if starts_with(line, "#version") {
                found, left, version_string := split_from_left(line, " ");
                if !found invalid_code_path("Version number not found next to #version declaration.");
                version = parse_int(*version_string);
            } else {
                if version < 0 invalid_code_path("Version should be defined before anything else.");
                
                if starts_with(line, "#default") {
                    found, left, name := split_from_left(line, " ");
                    if !found invalid_code_path("Default state name not defined after #default declaration.");
                    default_state_name = name;
                }
            }
        } else {
            
            found, state_name, anim_name := split_from_left(line, " ");
            
            if !found invalid_code_path("Line should follow the format 'state_name anim_name : next_state_name' with ': next_state_name' being optional");
            
            state := Animation_State.{};
            state.name = trim(state_name);
            
            has_next, a_name, next_state_name := split_from_left(anim_name, ":");
            if has_next {
                state.animation_name = trim(a_name);
                state.next_state     = trim(next_state_name);
                state.looping = false;
            } else {
                state.animation_name = trim(anim_name);
                state.looping = true;
            }
            
            array_add(*graph.states, state);
        }
        
        line_exists, line = get_next_line(*data);
    }
    
    
    
    if default_state_name.count > 0 {
        for graph.states {
            if default_state_name == it.name {
                graph.default_state = it_index;
                break;
            }
        }
    }
    
    
    return graph;
}