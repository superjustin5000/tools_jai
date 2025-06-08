
#import "Basic";
#import "String";


#import "common";
#import "file_io_common";
#import "tokenizer";

/*
Generates C/C++ struct and enum meta data.
The type definitions for the code being generated is defined in 
 a separate file that's part of the project using the meta data.


#define meta_prop_ptr(ptr, type, prop) (type*)((u8*)(ptr) + prop->offset)

struct Meta_Condition {
    char *prop_name;
    u32 value;
};
struct Meta_Prop_V0 {
    char serialized_type_name[64];
    char name[32];
    u64 offset;
    bool pointer;
    bool array;
    bool readonly;
    bool hidden;
    bool unioned_prop;
    u32 size;
    Meta_Condition condition;
    char array_count[32];
    char old_name[32];
    s32 int_val;
    s32 id;
};

struct Meta_Type;

struct Meta_Prop {
    Meta_Type *type;
    char serialized_type_name[64];
    char name[32];
    char old_name[32];
    u64 offset;
    bool unioned_prop;
    bool pointer;
    bool array;
    Meta_Prop *array_count;
    char array_count_prop_name[32];
    s32 id;
    s32 int_val;
    bool readonly;
    bool hidden;
    Meta_Condition condition;
    u32 array_count_plus;
};


// WARNING! WARNING!
// Currently this struct (Meta_Enum_Val) is Un-editable without breaking the loading of the database.
// It is probably not saved out to the database file as a previous version of the struct
// to be mapped back onto the new version.
struct Meta_Enum_Val {
    char name[64];
    char short_name[32];
    u32 value;
};

enum Meta_Type_Type {
    Meta_Type_Primitive,
    Meta_Type_Struct,
    Meta_Type_Enum,
    Meta_Type_Enum_Flags,
    Meta_Type_Invalid = 666
};

struct Meta_Type {
    char serialized_name[64];
    char name[64];
    Meta_Type_Type type;
    u32 size;
    Meta_Prop *props;
    Meta_Enum_Val *enum_vals;
    u32 prop_count;
};



It uses annotations as "#define"s to identify structs and enums 
that need to have meta data generated.

The following are the annotation defintions available so far.


// tell the preprocessor to generate meta data on this type.
// this goes at the top of the struct of enum.
#define generate_meta(serialized_name)

// a special id to handle this property in a different way instead of default way of its type.
#define meta_id(id)

// do not allow editing of this property
#define meta_readonly

// do not display this property ever
#define meta_hide

// display this property conditionally based on another property of the parent struct having a specific value. (prop=value)
// can also use a simple integer value as the condition. So meta_condition(2) will translate to meta_condition(___selector___=2) , and ___selector___ will be the property name to look for when deciding what to do with this prop under this condition.
#define meta_condition(condition)

// identifies an enum as a flags enum instead of a normal enum
#define meta_flags

// defines the name of the property of the parent struct that holds the actual number of items in the array, instead of the array's max size.
#define meta_array_count(name)

// defines a previously serialized name in case of changing the property name, to still be able to access the old serialized value. (can be removed once the value has been reserialized)
#define meta_old_name(name)

// extra meta data (s32) to provide the system handling this property.
#define meta_int(val)



Example:

generate_meta(Entity_Type);
enum Entity_Type {
Entity_Player,
Entity_Enemy,
};

generate_meta(Entity_Flags);
enum Entity_Flags meta_flags {
Entity_Flag_Invisible,
Entity_Flag_Immovable,
Entity_Flag_Will_Die,
};

generate_meta(Entity);
struct Entity {
u32 id meta_readonly;
Entity_Type type meta_id(10);
V3 position;
bool valid meta_hide meta_old_name(is_valid);
Entity_Flags flags;
};

*/



Struct :: struct {
    serialized_name: string; //should not change
    name: string;
    prop_count: u32;
    token_index: s64;
    is_union: bool;
};

Typedef :: struct {
    serialized_name: string;
    struct_index: s32 = -1;
    existing_name: string;
    new_name: string;
    token_index: s64;
}


Enum :: struct {
    serialized_name: string;
    name: string;
    token_index: s64;
    value_count: u32;
    is_flags: bool;
}

Condition :: struct {
    valid: bool;
    name: string;
    value: string;
}



Process :: struct {
    is_generating_meta :bool;
    structs : [..]Struct;
    typedefs : [..]Typedef;
    enums : [..]Enum;
}




process_tokens :: (proc : *Process, tokenizer: *Tokenizer) {
    
    meta_builder := String_Builder.{};
    
    gather_types_to_generate(proc, tokenizer);
    
    
    for meta_struct : proc.structs {
        generate_meta_struct(proc, tokenizer, *meta_struct, it_index, *meta_builder, meta_struct.is_union);
    }
    for meta_typedef : proc.typedefs {
        generate_meta_typedef(proc, *meta_typedef, *meta_builder);
    }
    for meta_enum : proc.enums {
        generate_meta_enum(proc, tokenizer, *meta_enum, *meta_builder);
    }
    
    
    generate_meta_type_array(proc, *meta_builder);
    
    output := builder_to_string(*meta_builder);
    
    filename := "../code/game_meta_generated.h";
    delete_file(filename);
    write_file(filename, cast(*void)output.data, output.count);
    
}




gather_types_to_generate :: (proc: *Process, tokenizer: *Tokenizer) {
    
    for 0 .. tokenizer.tokens.count-1 {
        token := tokenizer.tokens[it];
        
        if token.name == "generate_meta" {
            it += 1; // (
            it += 1; // the serialized name string
            serialized_name := tokenizer.tokens[it].name;
            it += 1; // )
            it += 1; // ;
            it += 1; // struct/union/typedef
            token = tokenizer.tokens[it];
            
            if token.name == {
                case "union"; #through;
                case "struct"; {
                    it += 1;
                    meta_struct : Struct = .{};
                    meta_struct.serialized_name = serialized_name;
                    meta_struct.name            = tokenizer.tokens[it].name;
                    meta_struct.token_index     = it;
                    meta_struct.is_union        = token.name == "union";
                    array_add(*proc.structs, meta_struct);
                    it += 1;
                }
                case "typedef"; {
                    it += 1;
                    meta_typedef : Typedef = .{};
                    meta_typedef.serialized_name = serialized_name;
                    meta_typedef.existing_name   = tokenizer.tokens[it].name;
                    meta_typedef.new_name        = tokenizer.tokens[it + 1].name;
                    meta_typedef.token_index     = it;
                    
                    // NOTE(justin): struct def should exist already because C would require it.
                    // have to include files HERE to be preprocessed in the right order.
                    for meta_struct: proc.structs {
                        if meta_struct.name == meta_typedef.existing_name {
                            meta_typedef.struct_index = cast(s32)it_index;
                            break;
                        }
                    }
                    assert(meta_typedef.struct_index >= 0, "Maybe files included in wrong order");
                    
                    array_add(*proc.typedefs, meta_typedef);
                    it += 2;
                }
                case "enum"; {
                    it += 1;
                    meta_enum : Enum = .{};
                    meta_enum.serialized_name = serialized_name;
                    meta_enum.name            = tokenizer.tokens[it].name;
                    meta_enum.token_index     = it;
                    token = tokenizer.tokens[it + 1];
                    if (token.name == "meta_flags") {
                        meta_enum.is_flags = true;
                        it += 1;
                        meta_enum.token_index = it;
                    }
                    array_add(*proc.enums, meta_enum);
                }
            }
        }
        
    }
}


generate_meta_typedef :: (proc : *Process, meta_typedef: *Typedef, meta_builder: *String_Builder) {
    meta_struct := proc.structs[meta_typedef.struct_index];
    append(meta_builder, sprint("#define meta_props__% meta_props__%\n", meta_typedef.serialized_name, meta_struct.serialized_name));
}



generate_meta_enum :: (proc : *Process, tokenizer: *Tokenizer, meta_enum: *Enum, meta_builder: *String_Builder) {
    append(meta_builder, sprint("Meta_Enum_Val meta_enum_vals__%[] = {\n", meta_enum.serialized_name));
    
    index := meta_enum.token_index;
    index += 2;
    
    token := tokenizer.tokens[index];
    while true {
        
        short_name := token.name;
        index_of_underscore := find_index_from_left(token.name, #char "_");
        if (index_of_underscore >= 0) short_name = slice(short_name, index_of_underscore + 1, short_name.count);
        
        append(meta_builder, sprint("{\"%\", \"%\", (u32)%},\n", token.name, short_name, token.name));
        meta_enum.value_count += 1;
        
        index += 1;
        token = tokenizer.tokens[index];
        while token.type != .Comma {
            index += 1;
            token = tokenizer.tokens[index];
            if token.type == .Brace_Close break;
        }
        if token.type == .Brace_Close break;
        index += 1;
        token = tokenizer.tokens[index];
        if token.type == .Brace_Close break;
    }
    
    append(meta_builder, "};\n");
}




generate_meta_struct :: (proc : *Process, tokenizer: *Tokenizer, meta_struct: *Struct, struct_index: s64, meta_builder: *String_Builder, is_union: bool) {
    
    append(meta_builder, sprint("Meta_Prop meta_props__%[] = {\n", meta_struct.serialized_name));
    
    index := meta_struct.token_index;
    index += 2; // get past opening brace to first other token.
    
    token := tokenizer.tokens[index];
    
    union_count :u32= 0; 
    if is_union union_count = 1;
    prop_count : u32 = 0;
    index, prop_count = generate_meta_struct_props(proc, tokenizer, index, meta_struct.name, struct_index, meta_builder, union_count);
    meta_struct.prop_count = prop_count;
    
    append(meta_builder, "};\n");
}


generate_meta_struct_props :: (proc: *Process, tokenizer: *Tokenizer, prop_token_index: s64, struct_name: string, struct_index: s64, meta_builder: *String_Builder, union_count: u32) -> s64, u32 {
    
    index := prop_token_index;
    prop_count : u32 = 0;
    
    token := tokenizer.tokens[index];
    
    while token.type != .Brace_Close {
        
        if token.name == "struct" || token.name == "union" {
            index += 2; // get past open brace.
            
            count:u32 = 0;
            
            sub_union_count :u32= 0;
            if token.name == "union" sub_union_count = 1;
            if union_count == 2 sub_union_count = 2;
            
            index, count = generate_meta_struct_props(proc, tokenizer, index, struct_name, struct_index, meta_builder, sub_union_count);
            
            if union_count == 1 {
                union_count = 2;
            }
            
            prop_count += count;
            
            token = tokenizer.tokens[index];
            index += 1; // get past semi colon.
            token = tokenizer.tokens[index];
            continue;
        }
        
        prop_type := token.type;
        
        serialized_name := "";
        type_string := token.name;
        
        if prop_type == {
            case .U8; serialized_name = "u8";
            case .U16; serialized_name = "u16";
            case .U32; serialized_name = "u32";
            case .U64; serialized_name = "u64";
            case .S8; serialized_name = "s8";
            case .S16; serialized_name = "s16";
            case .S32; serialized_name = "s32";
            case .S64; serialized_name = "s64";
            case .F32; serialized_name = "f32";
            case .F64; serialized_name = "f64";
            case .Bool; serialized_name = "bool";
            case .Char; serialized_name = "char";
            case .Identifier; serialized_name = sprint("%", token.name);
            case; serialized_name = "unkown_type";
        }
        
        index += 1;
        token = tokenizer.tokens[index];
        
        
        Meta_Prop :: struct {
            name:             string;
            pointer:          = false;
            array:            = false;
            hidden:           = false;
            readonly:         = false;
            array_count:      string;
            array_count_plus: string;
            old_name:         string;
            int_val:          string;
            id:               string;
        }
        
        Meta_Prop_List :: struct {
            props : [..]Meta_Prop;
        }
        prop_list := Meta_Prop_List.{};
        
        
        prop_proc :: (proc: *Process, tokenizer: *Tokenizer, prop_list: Meta_Prop_List, index: s64) -> s64 {
            prop := Meta_Prop.{};
            
            token := tokenizer.tokens[index];
            
            if token.type == .Asterisk {
                prop.pointer = true;
                
                index += 1;
                token = tokenizer.tokens[index];
            }
            
            prop.name = token.name;
            
            index += 1;
            token = tokenizer.tokens[index]; // equal or semicolon or array, or comma separated props
            
            
            // this is an array type.
            if token.type == .Bracket_Open {
                
                prop.array = true;
                
                // Try to blow past any number of open and close brackets
                // to accomodate N dimensional arrays.
                while true {
                    index += 1;
                    token = tokenizer.tokens[index];
                    if token.type == .Bracket_Close {
                        index += 1;
                        token = tokenizer.tokens[index];
                        // Only end loop when we've found a closing bracket without
                        // the next token being ANOTERH opening bracket.
                        if token.type != .Bracket_Open {
                            // equal or semicolon or array, or comma separated props
                            break;
                        }
                    }
                }
                
            }
            
            
            token = tokenizer.tokens[index];
            
            if token.type == .Equal {
                index += 1;// the default value or a '-' for negative values
                if tokenizer.tokens[index].type == .Minus index += 1; //get past the minus sign
                
                token = tokenizer.tokens[index];
                
                // default array value
                if token.type == .Brace_Open {
                    braces := 1;
                    while braces {
                        index += 1;
                        token = tokenizer.tokens[index];
                        if token.type == .Brace_Open braces += 1;
                        else if token.type == .Brace_Close braces -= 1;
                    }
                    index += 1; // end of prop.
                }
                // regular default value
                else {
                    index += 1; // end of prop
                }
                
            }
            
            array_add(*prop_list.props, prop);
            
            return index;
        }
        
        index = prop_proc(proc, tokenizer, *prop_list, index);
        token = tokenizer.tokens[index];
        
        // might have multiple properies of same type in a row.
        while token.type == .Comma {
            index += 1;
            index = prop_proc(proc, tokenizer, *prop_list, index);
            token = tokenizer.tokens[index];
        }
        
        
        // search for other meta tags after property lists.
        
        condition := Condition.{};
        
        while token.type != .Semicolon {
            
            if token.name == "meta_hide" {
                for *prop : prop_list.props {
                    prop.hidden = true;
                }
            }
            
            else if token.name == "meta_readonly" {
                for *prop : prop_list.props {
                    prop.readonly = true;
                }
            }
            
            else if token.name == "meta_condition" {
                
                condition.valid = true;
                
                index += 2; // (, condition name or numeric value
                token = tokenizer.tokens[index];
                if token.type == .Number {
                    // specifying a special value for selctively show
                    condition.name = "___selector___";
                    condition.value = token.name;
                }
                else if token.type == .Identifier {
                    condition.name = token.name;
                    index += 2; // =, value
                    token = tokenizer.tokens[index];
                    condition.value = token.name;
                }
                
                while token.type != .Paren_Close {
                    index += 1;
                    token = tokenizer.tokens[index];
                }
            }
            
            else if token.name == "meta_array_count" {
                index += 2;
                token = tokenizer.tokens[index];
                for *prop : prop_list.props {
                    prop.array_count = token.name;
                }
                index += 1;
                token = tokenizer.tokens[index];
                if token.type == .Plus {
                    index += 1;
                    token = tokenizer.tokens[index];
                    if token.type == .Number {
                        for *prop : prop_list.props {
                            prop.array_count_plus = token.name;
                        }
                        index += 1;
                        token = tokenizer.tokens[index];
                    }
                }
                while token.type != .Paren_Close {
                    index += 1;
                    token = tokenizer.tokens[index];
                }
            }
            
            else if token.name == "meta_old_name" {
                index += 2;
                token = tokenizer.tokens[index];
                if token.type == .Identifier {
                    for *prop : prop_list.props {
                        prop.old_name = token.name;
                    }
                }
                while token.type != .Paren_Close {
                    index += 1;
                    token = tokenizer.tokens[index];
                }
            }
            
            else if token.name == "meta_int" {
                index += 2;
                token = tokenizer.tokens[index];
                if token.type == .Identifier {
                    for *prop : prop_list.props {
                        prop.int_val = token.name;
                    }
                }
                while token.type != .Paren_Close {
                    index += 1;
                    token = tokenizer.tokens[index];
                }
            }
            
            
            else if token.name == "meta_id" {
                index += 2;
                token = tokenizer.tokens[index];
                if token.type == .Identifier {
                    for *prop : prop_list.props {
                        prop.id = token.name;
                    }
                }
                while token.type != .Paren_Close {
                    index += 1;
                    token = tokenizer.tokens[index];
                    
                }
            }
            
            index += 1;
            token = tokenizer.tokens[index];
        }
        
        
        for prop : prop_list.props {
            unioned_prop :=  union_count == 2;
            
            condition_string := "{0, 0}";
            if condition.valid {
                condition_string = sprint("{\"%\",%}", condition.name, condition.value);
            }
            array_count_string := "{0}";
            if prop.array_count.count > 0 {
                array_count_string = sprint("\"%\"", prop.array_count);
            }
            old_name_string := "{0}";
            if prop.old_name.count > 0 {
                old_name_string = sprint("\"%\"", prop.old_name);
            }
            int_val_string := "-1";
            if prop.int_val.count > 0 {
                int_val_string = sprint("%", prop.int_val);
            }
            id_string := "-1";
            if prop.id.count > 0 {
                id_string = sprint("%", prop.id);
            }
            
            append(meta_builder, sprint("{0, \"%\", \"%\", %, (u64)&(((%*)0)->%), %, %, %, 0, %, %, %, %, %, %, %},\n", 
                                        
                                        serialized_name, 
                                        prop.name, 
                                        old_name_string,
                                        struct_name,
                                        prop.name,
                                        
                                        unioned_prop, 
                                        prop.pointer, 
                                        prop.array, 
                                        array_count_string,
                                        
                                        id_string, 
                                        int_val_string,
                                        
                                        prop.readonly, 
                                        prop.hidden, 
                                        condition_string,
                                        prop.array_count_plus
                                        ));
            
            if union_count == 1 union_count = 2;
        }
        prop_count += cast(u32)prop_list.props.count;
        
        index += 1; // the next property after semi colon
        token = tokenizer.tokens[index];
        
    }
    
    index += 1; // past closing brace.
    
    return index, prop_count;
    
}






generate_meta_type_array :: (proc: *Process, meta_builder: *String_Builder) {
    
    append(meta_builder, "Meta_Type meta_types[] = {\n");
    
    type_names := string.["u8", "u16", "u32", "u64", "s8", "s16", "s32", "s64", "f32", "f64", "bool", "char"];
    for name : type_names {
        append(meta_builder, sprint("{\"%\", \"%\", Meta_Type_Primitive, sizeof(%), 0, 0, 0},\n",
                                    name, name, name));
    }
    
    for meta_struct : proc.structs {
        append(meta_builder, sprint("{\"%\", \"%\", Meta_Type_Struct, sizeof(%), &meta_props__%[0], 0, %},\n", meta_struct.serialized_name, meta_struct.name, meta_struct.name, meta_struct.serialized_name, meta_struct.prop_count));
    }
    
    
    for meta_typedef : proc.typedefs {
        meta_struct := proc.structs[meta_typedef.struct_index];
        append(meta_builder, sprint("{\"%\", \"%\", Meta_Type_Struct, sizeof(%), &meta_props__%[0], 0, %},\n", meta_typedef.serialized_name, meta_struct.name, meta_struct.name, meta_struct.serialized_name, meta_struct.prop_count));
    }
    
    for meta_enum : proc.enums {
        type_string := "Meta_Type_Enum";
        if meta_enum.is_flags type_string = "Meta_Type_Enum_Flags";
        append(meta_builder, sprint("{\"%\", \"%\", %, 4, 0, &meta_enum_vals__%[0], %},\n", meta_enum.serialized_name, meta_enum.name, type_string, meta_enum.name, meta_enum.value_count));
    }
    
    append(meta_builder, "};\n");
    
    append(meta_builder, sprint("u32 global_meta_type_count = %;\n", type_names.count + proc.structs.count + proc.typedefs.count + proc.enums.count));
    append(meta_builder, sprint("u32 global_meta_struct_count = %;\n", proc.structs.count));
    append(meta_builder, sprint("u32 global_meta_typedef_count = %;\n", proc.typedefs.count));
    append(meta_builder, sprint("u32 global_meta_enum_count = %;\n", proc.enums.count));
}





main :: () {
    
    filenames : [..]string;
    array_add(*filenames, "../code/assets.h");
    array_add(*filenames, "../code/editor.h");
    array_add(*filenames, "../code/entity.h");
    array_add(*filenames, "../code/entity_template.h");
    array_add(*filenames, "../code/game.h");
    array_add(*filenames, "../code/game_database.h");
    array_add(*filenames, "../code/input.h");
    array_add(*filenames, "../code/level.h");
    array_add(*filenames, "../code/physics.h");
    array_add(*filenames, "../code/platform.h");
    array_add(*filenames, "../code/types.h");
    
    
    proc := New(Process);
    defer free(proc);
    
    tokenizer := New(Tokenizer);
    defer free(tokenizer);
    
    for filename: filenames {
        file_result := read_file(filename);
        
        set_data_to_tokenize(tokenizer, cast(*u8)file_result.contents, cast(u32)file_result.content_size);
        tokenize(tokenizer);
        
        free_file(file_result);
    }
    
    process_tokens(proc, tokenizer);
    
}


