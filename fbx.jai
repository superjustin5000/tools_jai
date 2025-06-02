#import "Basic";
#import "String";
#import "Math";
#import "Hash_Table";

#import "common";
#import "file_io_common";
#import "model";
#import "deflate";


/*
FBX sources:
- The blender post everyone uses: https://code.blender.org/2013/08/fbx-binary-file-format-specification/
- A cool blog post by Banex: https://banexdevblog.wordpress.com/2014/06/23/a-quick-tutorial-about-the-fbx-ascii-format/
- Open FBX : https://github.com/nem0/OpenFBX
*/


#scope_file

FBX_Object_Type :: enum {
    Root;
    Geometry;
    Shape;
    Material;
    Mesh;
    Texture;
    Limb_Node;
    Null_Node;
    Camera;
    Light;
    Node_Attribute;
    Cluster;
    Skin;
    Blend_Shape;
    Blend_Shape_Channel;
    Animation_Stack;
    Animation_Layer;
    Animation_Curve;
    Animation_Curve_Node;
    Pose;
}


FBX_Object :: struct {
    id:             u64;
    parent:         *FBX_Object;
    depth:          u32;
    name:           string;
    node_attribute: *FBX_Object;
    type:           FBX_Object_Type;
    node:           *FBX_Node;
    
    
    position: V3;
    
    rotation_offset: V3;
    rotation_pivot:  V3;
    pre_rotation:    V3;
    rotation:        V3;
    post_rotation:   V3;
    
    scale_offset:    V3;
    scale_pivot:     V3;
    scale:           V3;
    
    xform_matrix:    Matrix4;
}

FBX_Root:: struct {
    using #as base: FBX_Object;
}

FBX_Pose_Node :: struct {
    matrix:  Matrix4;
    node_id: u64;
}

FBX_Pose :: struct {
    using #as base: FBX_Object;
    nodes: [..]FBX_Pose_Node;
}


FBX_Texture :: struct {
    using #as base: FBX_Object;
    
    filename:          string;
    relative_filename: string;
    data:              string;
}


FBX_Light :: struct {
    using #as base: FBX_Object;
}


FBX_Camera :: struct {
    using #as base: FBX_Object;
}


FBX_Material :: struct {
    using #as base: FBX_Object;
    
    textures:         [Mesh_Texture_Type.Count]*FBX_Texture;
    diffuse_color:    Color;
    specular_color:   Color;
    reflection_color: Color;
    ambient_color:    Color;
    emissive_color:   Color;
    
    diffuse_factor:     f64;
    specular_factor:    f64;
    reflection_factor:  f64;
    shininess:          f64;
    shininess_exponent: f64;
    ambient_factor:     f64;
    bump_factor:        f64;
    emissive_factor:    f64;
}


FBX_Cluster :: struct {
    using #as base: FBX_Object;
    
    indices:               [..]s32;
    weights:               [..]f32;
    transform_matrix:      Matrix4;
    transform_link_matrix: Matrix4;
    link:                  *FBX_Object;
    skin:                  *FBX_Skin;
}


FBX_Skin :: struct {
    using #as base: FBX_Object;
    
    clusters: [..]*FBX_Cluster;
    
    // back references.
    geometry: *FBX_Geometry;
    mesh:     *FBX_Mesh;
}


FBX_Blend_Shape :: struct {
    using #as base: FBX_Object;
    
    channels: [..]*FBX_Blend_Shape_Channel;
    
    geometry: *FBX_Geometry;
}


FBX_Blend_Shape_Channel :: struct {
    using #as base: FBX_Object;
    
    deform_percent: f32;
    shapes:         [..]*FBX_Shape;
    blend_shape:    *FBX_Blend_Shape;
}


FBX_Node_Attribute :: struct {
    using #as base: FBX_Object;
    
    attribute_type: string;
}

FBX_Limb_Node :: struct {
    using #as base: FBX_Object;
    
    skeleton_id: u32;
    bone:        *Bone;
    
    parent_limb: *FBX_Limb_Node;
    child_limbs: [..]*FBX_Limb_Node;
    
    clusters: [..]*FBX_Cluster;
    animation_curve_nodes: [..]*FBX_Animation_Curve_Node;
}

MAX_UVS :: 4;


FBX_Geometry :: struct {
    using #as base: FBX_Object;
    
    vertices:        [..]V3;
    vertex_indices:  [..]s32;
    uvs:             [MAX_UVS][..]V2;
    uv_indices:      [MAX_UVS][..]s32;
    uv_mapping:      [MAX_UVS]FBX_Vertex_Data_Mapping;
    normals:         [..]V3;
    normal_indices:  [..]s32;
    normal_mapping:  FBX_Vertex_Data_Mapping;
    tangents:        [..]V3;
    tangent_indices: [..]s32;
    tangent_mapping: FBX_Vertex_Data_Mapping;
    colors:          [..]Color;
    color_indices:   [..]s32;
    color_mapping:   FBX_Vertex_Data_Mapping;
    
    // Each index counts for one POLYGON of the geometry.
    // Just something to keep in mind.
    // It depends on the mapping:
    // Either it will be ByPolygon/IndexToDirect or AllSame
    // if material_indices array is empty, it's AllSame,
    // and the mesh should only have 1 material to reference anyway.
    material_indices: [..]s32;
    
    mesh: *FBX_Mesh;
    skin: *FBX_Skin;
    blend_shape: *FBX_Blend_Shape;
    
}

FBX_Vertex_Data_Mapping :: enum {
    Unknown;
    By_Polygon_Vertex;
    By_Polygon;
    By_Vertex;
    By_Edge;
    All_Same;
}


FBX_Shape :: struct {
    using #as base: FBX_Object;
    
    vertices: [..]V3;
    normals:  [..]V3;
    indices:  [..]s32;
}


FBX_Mesh :: struct {
    using #as base: FBX_Object;
    
    mesh_id: s64;
    
    geometry:    *FBX_Geometry;
    materials:   [..]*FBX_Material;
    pose:        Matrix4;
    skin:        *FBX_Skin;
    blend_shape: *FBX_Blend_Shape;
    
    
    // NOTE: older formats do not use geometry as a node,
    // but instead embed the same data that's in geometry
    // here in the mesh directly.
    
}



FBX_Animation_Curve :: struct {
    using #as base: FBX_Object;
    
    // One value for every frame of the parent animation, 
    // regardless whether the curve has a keyframe at that time. 
    // These are caclulated in a post processing step. (post_parse_animation_stack)
    frames: [..]Frame; 
    
    Frame :: struct {
        value:         f32;
        time:          f32;
        // The index into times/values arrays of THIS keyframe frame.
        // The fact that this would be -1 means that it is NOT a keyframe frame.
        keyframe:      s32 = -1; 
        next_keyframe: s32 = -1; // index of the next frame in the frames array that IS a keyframe.
        prev_keyframe: s32 = -1; // index of the prev frame in the frames array that IS a keyframe.
    }
    
    
    default_value: f32;
    
    times:          [..]s64;
    values:         [..]f32;
    attr_flags:     [..]s32;
    attr_data:      [..]f32;
    attr_ref_count: [..]s32;
    
    Attribute_Flags :: enum {
        
        Interpolation_Constant :: 0x00000002;
        Interpolation_Linear   :: 0x00000004;
        Interpolation_Cubic    :: 0x00000008;
        
        Constant_Standard      :: 0x00000000; // Curve value is constant between this key and next.
        Constant_Next          :: 0x00000100; // Curve value is constant, with next key's value.
        
        Tangent_Auto           :: 0x00000100; // Auto key (spline cardinal).
        Tangent_TCB            :: 0x00000200; // Spline TCB (Tension, Continuity, Bias)
        Tangent_User           :: 0x00000400; // Next slope at left equal to slope at right
        Tangent_Generic_Break  :: 0x00000800; // Independent left and right slopes.
        Tangent_Break          :: Tangent_Generic_Break | Tangent_User; // Independent left and right, with next slope at the left equal to the slope at right.
        Tangent_Auto_Break     :: Tangent_Generic_Break | Tangent_Auto; // Independent left and right, with auto key.
        Tangent_Generic_Clamp  :: 0x00001000; // Clamp: key should be flat if next or prev key has the same value(overrides tangent mode).
        Tangent_Generic_Time_Independent  :: 0x00002000; // Time independent tangent (overrides tangent mode).
        Tangent_Generic_Clamp_Progressive :: 0x00004000 | Tangent_Generic_Time_Independent; // Clamp progressive: key should be flat if tangent control point is outside [next-prev key] range (overrides tangent mode).
        
        Velocity_None      :: 0x00000000; // No velocity.
        Velocity_Right     :: 0x10000000; // Right tangent has velocity
        Velocity_Next_Left :: 0x20000000; // Left tangent has velocity.
        Velocity_All       :: Velocity_Right | Velocity_Next_Left; // Both have velocity
        
        Weighted_None      :: 0x00000000; // Tangent has default weights of 0.333 (not weighted)
        Weighted_Right     :: 0x01000000; // Right tangent is weighted
        Weighted_Next_Left :: 0x02000000; // Left tangent is weighted
        Weighted_All       :: Weighted_Right | Weighted_Next_Left; // Both are weighted.
        
        Tangent_Show_None  :: 0x00000000; // No tangent is visible.
        Tangent_Show_Left  :: 0x00100000; // Left tangent is visible.
        Tangent_Show_Right :: 0x00200000; // Right tangent is visible.
        Tangent_Show_Both  :: Tangent_Show_Left | Tangent_Show_Right;
    }
    
    max_time:   s64 = 0;
    min_time:   s64 = S64_MAX;
}

TANGENT_DEFAULT_WEIGHT :: 3.3333;

curve_attribtue_flag :: (flags: FBX_Animation_Curve.Attribute_Flags, value: FBX_Animation_Curve.Attribute_Flags) -> bool {
    if flags & value == value return true;
    return false;
}

curve_velocity_mode :: (flags: FBX_Animation_Curve.Attribute_Flags) -> FBX_Animation_Curve.Attribute_Flags {
    velocity_mode := flags & 0xF0000000;
    if velocity_mode == 0 return .Velocity_None;
    return velocity_mode;
}

curve_weighted_mode :: (flags: FBX_Animation_Curve.Attribute_Flags) -> FBX_Animation_Curve.Attribute_Flags {
    weighted_mode := flags & 0x0F000000;
    if weighted_mode == 0 return .Weighted_None;
    return weighted_mode;
}

curve_tangent_show :: (flags: FBX_Animation_Curve.Attribute_Flags) -> FBX_Animation_Curve.Attribute_Flags {
    tangent_show := flags & 0x00F00000;
    if tangent_show == 0 return .Tangent_Show_None;
    return tangent_show;
}


FBX_Animation_Curve_Node :: struct {
    using #as base: FBX_Object;
    
    curves:        [3]FBX_Animation_Curve;
    link:          *FBX_Object;
    link_property: string;
    default_values:     V3;
    mode:               Mode;
    
    max_time: s64 = 0;
    min_time: s64 = S64_MAX;
    
    Mode :: enum {
        Translation;
        Rotation;
        Scaling;
    }
    
}

FBX_Animation_Layer :: struct {
    using #as base: FBX_Object;
    
    frame_count: u32;
    
    curve_nodes: [..]*FBX_Animation_Curve_Node;
}

FBX_Animation_Stack :: struct {
    using #as base: FBX_Object;
    
    frame_count: u32;
    
    layers: [..]*FBX_Animation_Layer;
}



FBX_Null_Node :: struct {
    using #as base: FBX_Object;
    
    // IF the null node is used in a skeleton.
    skeleton_id: u32;
    bone:        *Bone;
    child_limbs: [..]*FBX_Limb_Node;
    clusters:    [..]*FBX_Cluster;
    animation_curve_nodes: [..]*FBX_Animation_Curve_Node;
    
}





is_node :: (obj: *FBX_Object) -> bool  {
    if obj.type == .Root ||
        obj.type == .Mesh ||
        obj.type == .Limb_Node ||
        obj.type == .Null_Node {
        return true;
    }
    return false;
}






FBX_Connection :: struct {
    type:          Type;
    from_object:   u64;
    to_object:     u64;
    from_property: string;
    to_property:   string;
    
    Type :: enum {
        Unknown;
        Object_Object;
        Object_Property;
        Property_Object;
        Property_Property;
    }
}

FBX_Object_Pair :: struct {
    node: *FBX_Node;
    object:  *FBX_Object;
}

FBX_Scene :: struct {
    root_node:        *FBX_Node;
    root:             *FBX_Root;
    frame_rate:       f32;
    settings:         FBX_Global_Settings;
    
    object_map:       Table(u64, FBX_Object_Pair);
    all_objects:      [..]*FBX_Object;
    meshes:           [..]*FBX_Mesh;
    geometries:       [..]*FBX_Geometry;
    limb_nodes:       [..]*FBX_Limb_Node;
    limb_roots:       [..]*FBX_Object; // could be limb_nodes or null_nodes
    animation_stacks: [..]*FBX_Animation_Stack;
    cameras:          [..]*FBX_Camera;
    lights:           [..]*FBX_Light;
    connections:      [..]FBX_Connection;
    data:             [..]u8;
    take_infos:       [..]FBX_Take_Info;
    videos:           [..]FBX_Video;
    
    version:          u32;
}


FBX_Property :: struct {
    count:  u32;
    length: u32;
    type:   Type;
    
    value:      string;
    value_bool: u8;
    value_s16:  s16;
    value_s32:  s32;
    value_u64:  u64;
    value_s64:  s64;
    value_f32:  f32;
    value_f64:  f64;
    
    array_bool: [..]u8;
    array_s16:  [..]s16;
    array_s32:  [..]s32;
    array_s64:  [..]s64;
    array_f32:  [..]f32;
    array_f64:  [..]f64;
    
    encoding:          u32;
    compressed_length: u32;
    
    is_binary := true;
    
    Type :: enum u8 {
        Bool          :: 67; // one byte, 0 or 1 encoded as LSB
        Double        :: 68;
        Float         :: 70;
        Short         :: 89;
        Integer       :: 73;
        Long          :: 76;
        Binary        :: 82;
        String        :: 83;
        Array_Bool    :: 98; // array of 1 byte booleans.
        Array_Double  :: 100;
        Array_Float   :: 102;
        Array_Integer :: 105;
        Array_Long    :: 108;
    }
}

property_type_size :: (prop: *FBX_Property) -> u8 {
    if prop.type == {
        case .Array_Bool;    { return 1; }
        case .Array_Integer; #through;
        case .Array_Float;   { return 4; }
        case .Array_Long;    #through;
        case .Array_Double;  { return 8; }
    }
    invalid_code_path("Unkown property type for type size\n");
    return 0;
}


FBX_Node :: struct {
    id:             string;
    parent:         *FBX_Node;
    children:   [..]*FBX_Node;
    properties: [..]*FBX_Property;
}


node_get_property :: (node: *FBX_Node, offset: u32) -> *FBX_Property {
    if node.properties.count <= offset return null;
    prop := node.properties[offset];
    return prop;
}

node_get_property_s32 :: (node: *FBX_Node, offset: u32) -> s64 {
    assert(offset < node.properties.count);
    prop := node.properties[offset];
    assert(prop != null);
    return prop.value_s32;
}

node_get_property_f64 :: (node: *FBX_Node, offset: u32) -> f64 {
    assert(offset < node.properties.count);
    prop := node.properties[offset];
    assert(prop != null);
    return prop.value_f64;
}

node_get_property_f32 :: (node: *FBX_Node, offset: u32) -> f64 {
    assert(offset < node.properties.count);
    prop := node.properties[offset];
    assert(prop != null);
    return prop.value_f32;
}

FBX_Take_Info :: struct {
    name:                string;
    filename:            string;
    local_time_from:     f64;
    local_time_to:       f64;
    reference_time_from: f64;
    reference_time_to:   f64;
}

FBX_Video :: struct {
    filename: string;
    content: string;
    media: string;
}

FBX_Coord_System :: enum {
    Right_Handed :: 0;
    Left_Handed  :: 1;
}


FBX_Frame_Rate :: enum {
    Default         :: 0; // 30 fps (in most applications)
    _120            :: 1;
    _100            :: 2;
    _60             :: 3;
    _50             :: 4;
    _48             :: 5;
    _30             :: 6;
    _30_Drop        :: 7;
    NTSC_Drop_Frame :: 8;
    NTCS_Full_Frame :: 9;
    Pal             :: 10;
    Cinema          :: 11;
    _1000           :: 12;
    Cinema_ND       :: 13;
    Custom          :: 14;
}

FBX_Axis :: enum {
    X:: 0;
    Y:: 1;
    Z:: 2;
}

Basis :: struct {
    u: FBX_Axis;
    f: FBX_Axis;
    r: FBX_Axis;
    us: s32;
    fs: s32;
    rs: s32;
}

vector3_from_axis :: (axis: FBX_Axis, sign: s32 =  1) -> Vector3 {
    result := Vector3.{x=0,y=0,z=0};
    if axis == .X {
        result.x = 1.0 * sign;
    } else if axis == .Y {
        result.y = 1.0 * sign;
    } else if axis == .Z {
        result.z = 1.0 * sign;
    }
    return result;
}

basis_matrix :: (basis: Basis) -> Matrix4 {
    up_vector:      = vector3_from_axis(basis.u, basis.us);
    forward_vector: = vector3_from_axis(basis.f, basis.fs);
    right_vector:   = vector3_from_axis(basis.r, basis.rs);
    
    basis_m := make_matrix_from_rows(right_vector, up_vector, forward_vector);
    return basis_m;
}

v3_reorient :: (v3: V3, from_basis: Basis, to_basis: Basis) -> V3 {
    result := v3;
    result.components[to_basis.r] = v3.components[from_basis.r] * from_basis.rs * to_basis.rs;
    result.components[to_basis.u] = v3.components[from_basis.u] * from_basis.us * to_basis.us;
    result.components[to_basis.f] = v3.components[from_basis.f] * from_basis.fs * to_basis.fs;
    return result;
}


FBX_Global_Settings :: struct {
    up_axis:                   FBX_Axis = .Z;
    up_axis_sign:              s32 = 1;
    
    // this seems to be 1-2 in Autodesk (odd/even parity), and 0-2 in Blender (axis as in UpAxis)
    // I recommend to ignore FrontAxis and use just UpVector
    front_axis:                 FBX_Axis = .X;
    front_axis_sign:            s32 = 1;
    coord_axis:                 FBX_Axis = .Y;
    coord_axis_sign:            s32 = -1;
    original_up_axis:           s32 = 0;
    original_up_axis_sign:      s32 = 1;
    basis:                      Matrix4;
    inverse_basis:              Matrix4;
    desired_basis:              Matrix4;
    desired_basis_xform:        Matrix4;
    basis_basis:             Basis;
    desired_basis_basis:     Basis;
    
    unit_scale_factor:          f32 = 1;
    original_unit_scale_factor: f32 = 1;
    time_span_start:            f64 = 0;
    time_span_stop:             f64 = 0;
    time_mode:                  FBX_Frame_Rate = .Default;
    custom_frame_rate:          f32 = -1.0;
    actual_frame_rate:          f32 = 30.0;
}

frame_rate_from_time_mode :: (settings: *FBX_Global_Settings) -> f32 {
    if settings.time_mode == {
        case .Default; return 30.0;
        case ._120;    return 120.0;
        case ._100;    return 100.0;
        case ._60;     return 60.0;
        case ._50;     return 50.0;
        case ._48;     return 48.0;
        case ._30;     return 30.0;
        case .Custom;   return settings.custom_frame_rate;
    }
    return -1;
}



FBX_Header :: struct {
    magic:    [21]u8 #align 1;
    reserved: [2]u8  #align 1;
    version:  u32    #align 1;
} #no_padding

















gather_nodes_binary :: (raw_data: *u8, size: u64, version: *u32) -> *FBX_Node {
    assert(size >= size_of(FBX_Header));
    
    data := get_consumeable_data_block(raw_data, size);
    
    header := consume_data(*data, FBX_Header);
    
    <<version = header.version;
    
    root:   = cast(*FBX_Node)alloc(size_of(FBX_Node));
    <<root  = .{};
    root.id = "";
    
    while true {
        child := read_node(*data, header.version);
        if child == null return root;
        child.parent = root;
        array_add(*root.children, child);
    }
    return null;
}

read_node :: (data: *Consumeable_Data_Block, version: u32) -> *FBX_Node {
    end_offset := read_node_offset(data, version);
    if end_offset == 0 return null;
    
    prop_count  := read_node_offset(data, version);
    prop_length := read_node_offset(data, version);
    
    id := read_short_string(data);
    
    node := cast(*FBX_Node)alloc(size_of(FBX_Node));
    <<node = .{};
    node.id = id;
    
    if prop_count > 0 {
        for 0 .. prop_count - 1 {
            prop := read_property(data);
            if prop == null return null;
            array_add(*node.properties, prop);
        }
    }
    
    if data.at >= end_offset {
        return node;
    }
    
    // If we haven't returned after JUST the properties of the node,
    // then there are sub-nodes of the node,
    // which end in a NULL node of 13 or 25 '0' bytes.
    null_node_length : u64 = 13;
    if version >= 7500 null_node_length = 25;
    
    while data.at < (end_offset - null_node_length) {
        child := read_node(data, version);
        if child == null break;
        child.parent = node;
        array_add(*node.children, child);
    }
    
    consume_data_size(data, null_node_length);
    
    return node;
    
}

read_node_offset :: (data: *Consumeable_Data_Block, version: u32) -> u64 {
    if version >= 7500 {
        return consume_data_value(data, u64);
    }
    return consume_data_value(data, u32);
}

read_long_string :: (data: *Consumeable_Data_Block) -> string {
    s: string;
    s.count = consume_data_value(data, u32);
    s.data  = NewArray(s.count, u8, false).data;
    copy_data(s.data, consume_data_size(data, cast(u64)s.count), cast(u32)s.count);
    return s;
}

read_short_string :: (data: *Consumeable_Data_Block) -> string {
    s: string;
    s.count = consume_data_value(data, u8);
    s.data  = NewArray(s.count, u8, false).data;
    copy_data(s.data, consume_data_size(data, cast(u64)s.count), cast(u32)s.count);
    return s;
}

read_string :: (data: *Consumeable_Data_Block, len: u32) -> string {
    s: string;
    s.data  = NewArray(len, u8, false).data;
    s.count = len;
    copy_data(s.data, consume_data_size(data, cast(u64)len), cast(u32)len);
    return s;
}

read_property :: (data: *Consumeable_Data_Block) -> *FBX_Property {
    
    property := cast(*FBX_Property)alloc(size_of(FBX_Property));
    <<property = .{};
    type_code := consume_data_value(data, u8);
    property.type = cast(FBX_Property.Type)type_code;
    
    if #complete property.type == {
        case .String; #through;
        case .Binary; {
            property.value = read_long_string(data);
        }
        case .Short; {
            property.value      = read_string(data, 2);
            property.value_s16  = <<(cast(*s16)property.value.data);
        }
        case .Bool; {
            property.value      = read_string(data, 1);
            property.value_bool = <<(cast(*u8)property.value.data);
        }
        case .Integer; {
            property.value      = read_string(data, 4);
            property.value_s32  = <<(cast(*s32)property.value.data);
        }
        case .Float; {
            property.value      = read_string(data, 4);
            property.value_f32  = <<(cast(*f32)property.value.data);
        }
        case .Double; {
            property.value      = read_string(data, 8);
            property.value_f64  = <<(cast(*f64)property.value.data);
        }
        case .Long; {
            property.value      = read_string(data, 8);
            property.value_s64  = <<(cast(*s64)property.value.data);
            property.value_u64  = cast(u64)property.value_s64;
        }
        case .Array_Bool;   
#through;
        case .Array_Float;  
#through;
        case .Array_Double; 
#through;
        case .Array_Long;   
#through;
        case .Array_Integer; {
            property.length   = consume_data_value(data, u32);
            assert(property.length > 0);
            property.encoding = consume_data_value(data, u32);
            assert(property.encoding == 0 || property.encoding == 1);
            property.compressed_length = consume_data_value(data, u32);
            len: u32;
            
            value_data:      *u8;
            value_data_base: *u8;
            type_size := property_type_size(property);
            
            if property.encoding == 1 {
                property.value = read_string(data, property.compressed_length);
                
                decompressed_length := property.length * type_size;
                value_data      = cast(*u8)alloc(decompressed_length);
                value_data_base = value_data;
                
                deflate_decompress(property.value.data, property.compressed_length, value_data);
            } else {
                property.compressed_length = 0;
                len = property.length * type_size;
                property.value = read_string(data, len);
                
                value_data = property.value.data;
            }
            
            if property.length > 0 {
                for 0 .. property.length - 1 {
                    if property.type == .Array_Bool {
                        bool_value := <<value_data;
                        array_add(*property.array_bool, bool_value);
                        
                    } else if property.type == .Array_Integer {
                        integer_value := <<(cast(*s32)value_data);
                        array_add(*property.array_s32, integer_value);
                        
                    } else if property.type == .Array_Long {
                        long_value := <<(cast(*s64)value_data);
                        array_add(*property.array_s64, long_value);
                        
                    } else if property.type == .Array_Float {
                        float_value := <<(cast(*f32)value_data);
                        array_add(*property.array_f32, float_value);
                        
                    } else if property.type == .Array_Double {
                        double_value := <<(cast(*f64)value_data);
                        array_add(*property.array_f64, double_value);
                        
                    }
                    value_data += type_size;
                }
            }
            
            
            if property.encoding == 1 {
                free(value_data_base);
            }
            
        }
    }
    
    return property;
}



gather_nodes_ascii :: (data: *u8, size: u64, version: *u32) -> *FBX_Node {
    invalid_code_path("Parsing ascii fbx files is not currently supported\n");
    // Please export as fbx binary so that we don't have to implement this 
    // slower messier version.
    return null;
}







parse_global_settings :: (scene: *FBX_Scene) {
    
    root := scene.root_node;
    settings_node := find_child(root, "GlobalSettings");
    
    if settings_node != null {
        scene.settings.time_mode = xx find_property_node_enum(settings_node, "TimeMode");
        scene.settings.custom_frame_rate = xx find_property_node_f32(settings_node, "CustomFrameRate");
        scene.settings.actual_frame_rate = frame_rate_from_time_mode(*scene.settings);
        
        scene.settings.up_axis         = xx find_property_node_enum(settings_node, "UpAxis");
        scene.settings.front_axis      = xx find_property_node_enum(settings_node, "FrontAxis");
        scene.settings.coord_axis      = xx find_property_node_enum(settings_node, "CoordAxis");
        scene.settings.up_axis_sign    = find_property_node_s32(settings_node, "UpAxisSign");
        scene.settings.front_axis_sign = find_property_node_s32(settings_node, "FrontAxisSign");
        scene.settings.coord_axis_sign = find_property_node_s32(settings_node, "CoordAxisSign");
        
        scene.settings.basis_basis = Basis.{
            u  = scene.settings.up_axis,
            f  = scene.settings.front_axis,
            r  = scene.settings.coord_axis,
            us = scene.settings.up_axis_sign,
            fs = scene.settings.front_axis_sign,
            rs = scene.settings.coord_axis_sign
        };
        
        scene.settings.basis = basis_matrix(scene.settings.basis_basis);
        scene.settings.inverse_basis = inverse(scene.settings.basis);
        
        scene.settings.desired_basis_basis = Basis.{
            u  = .Z,
            f  = .X,
            r  = .Y,
            us =  1,
            fs =  1,
            rs = -1,
        };
        scene.settings.desired_basis = basis_matrix(scene.settings.desired_basis_basis);
        
        scene.settings.desired_basis_xform = scene.settings.desired_basis * scene.settings.inverse_basis;
    }
    
}






parse_connections :: (scene : *FBX_Scene) -> bool {
    root := scene.root_node;
    connections_list_node := find_child(root, "Connections");
    if connections_list_node == null return true;
    
    for connections_list_node.children {
        
        props := it.properties;
        assert(props.count >= 3);
        assert(props[0].type == .String);
        
        conn : FBX_Connection = .{};
        conn.from_object = props[1].value_u64;
        conn.type = .Unknown;
        if props[0].value == {
            case "OO";
            conn.type      = .Object_Object;
            conn.to_object = props[2].value_u64;
            case "OP";
            assert(props.count >= 4);
            conn.type        = .Object_Property;
            conn.to_object   = props[2].value_u64;
            conn.to_property = props[3].value;
            case "PO";
            assert(props.count >= 4);
            conn.type        = .Property_Object;
            conn.to_property = props[2].value;
            conn.to_object   = props[3].value_u64;
            case "PP";
            assert(props.count >= 5);
            conn.type          = .Property_Property;
            conn.from_property = props[2].value;
            conn.to_object     = props[3].value_u64;
            conn.to_property   = props[4].value;
        }
        assert(conn.type != .Unknown);
        
        array_add(*scene.connections, conn);
    }
    return true;
}





fbx_time_to_seconds :: (value: s64) -> f64 {
    return cast(f64)value / 46186158000;
}

seconds_to_keyframe :: (seconds: f64, settings: *FBX_Global_Settings) -> u32 {
    keyframe := cast(u32)(seconds * settings.actual_frame_rate);
    return keyframe;
}




parse_takes :: (scene: *FBX_Scene) -> bool {
    root := scene.root_node;
    takes_list_node := find_child(root, "Takes");
    if takes_list_node == null return true;
    
    for takes_list_node.children {
        
        if it.id == "Take" {
            
            props := it.properties;
            assert(props.count >= 1);
            
            take     := cast(*FBX_Take_Info)alloc(size_of(FBX_Take_Info));
            <<take    = .{};
            take.name = props[0].value;
            
            filename_node := find_child(it, "Filename");
            if filename_node != null {
                assert(filename_node.properties.count >= 1);
                take.filename = filename_node.properties[0].value;
            }
            local_time_node := find_child(it, "LocalTime");
            if local_time_node != null {
                assert(local_time_node.properties.count >= 2);
                time_from := local_time_node.properties[0].value_s64;
                time_to   := local_time_node.properties[1].value_s64;
                take.local_time_from = fbx_time_to_seconds(time_from);
                take.local_time_to   = fbx_time_to_seconds(time_to);
            }
            reference_time_node := find_child(it, "ReferenceTime");
            if reference_time_node != null {
                assert(reference_time_node.properties.count >= 2);
                time_from := reference_time_node.properties[0].value_s64;
                time_to   := reference_time_node.properties[1].value_s64;
                take.reference_time_from = fbx_time_to_seconds(time_from);
                take.reference_time_to   = fbx_time_to_seconds(time_to);
            }
            array_add(*scene.take_infos, take);
        }
    }
    
    return true;
}






find_child :: (node: *FBX_Node, id: string) -> *FBX_Node {
    for node.children {
        if it.id == id return it;
    }
    return null;
}

find_children :: (node: *FBX_Node, id: string) -> [] *FBX_Node {
    children : [..]*FBX_Node;
    for node.children {
        if it.id == id array_add(*children, it);
    }
    return children;
}




make_object_pair :: (node: *FBX_Node, object: *FBX_Object) -> FBX_Object_Pair {
    pair: FBX_Object_Pair;
    pair.node = node;
    pair.object  = object;
    return pair;
}


// NOTE:
// This returns a boolean, but all paths that don't assert return true
// So maybe instead of asserting, return false, but if 
// returning false, there is a problem with the file format,
// or the original tokenization, so maybe don't return anything.
// This is the same for all the 'parse_' procs.
// - Justin 2025-04-24
parse_objects :: (scene: *FBX_Scene) {
    
    root := scene.root_node;
    objects_list_node := find_child(root, "Objects");
    if objects_list_node == null {
        print("FBX scene Objects node not found.\n");
        return;
    }
    
    scene.root = cast(*FBX_Root)alloc(size_of(FBX_Root));
    <<scene.root = .{};
    scene.root.id = 0;
    
    table_add(*scene.object_map, 0, make_object_pair(root, scene.root)); 
    
    for objects_list_node.children {
        
        if it.properties[0] != null {
            if it.properties[0].type != .Long {
                invalid_code_path("Invalid it.first_property.type\n");
            }
            id := it.properties[0].value_u64;
            
            table_add(*scene.object_map, id, make_object_pair(it, null));
        }
        
    }
    
    fbx_object :: (type: FBX_Object_Type, $T: Type, obj: **FBX_Object) -> *T {
        sub_type:     = cast(*T)alloc(size_of(T));
        <<sub_type    = .{};
        sub_type.type = type;
        if obj != null {
            <<obj = sub_type;
        }
        return sub_type;
    }
    
    for *scene.object_map {
        obj: *FBX_Object;
        
        if it.object == scene.root {
            obj = scene.root;
        }
        
        if it.node.id == "Geometry" {
            assert(it.node.properties.count > 0);
            last_prop := it.node.properties[it.node.properties.count - 1];
            if last_prop != null && last_prop.value == "Mesh" {
                geo := fbx_object(.Geometry, FBX_Geometry, *obj);
                parse_geometry(it.node, geo);
                array_add(*scene.geometries, geo);
                
            } else if last_prop != null && last_prop.value == "Shape" {
                shape := fbx_object(.Shape, FBX_Shape, *obj);
            }
        } else if it.node.id == "Material" {
            material := fbx_object(.Material, FBX_Material, *obj);
            parse_material(it.node, material);
            
        } else if it.node.id == "AnimationStack" {
            animation_stack := fbx_object(.Animation_Stack, FBX_Animation_Stack, *obj);
            array_add(*scene.animation_stacks, animation_stack);
            
        } else if it.node.id == "AnimationLayer" {
            animation_layer := fbx_object(.Animation_Layer, FBX_Animation_Layer, *obj);
            
        } else if it.node.id == "AnimationCurve" {
            animation_curve := fbx_object(.Animation_Curve, FBX_Animation_Curve, *obj);
            parse_animation_curve(it.node, animation_curve);
            
        } else if it.node.id == "AnimationCurveNode" {
            animation_curve_node := fbx_object(.Animation_Curve_Node, FBX_Animation_Curve_Node, *obj);
            parse_animation_curve_node(it.node, animation_curve_node);
            
        } else if it.node.id == "Deformer" {
            
            class_prop := it.node.properties[2];
            if class_prop == null {
                class_prop = it.node.properties[1];
            }
            
            if class_prop != null {
                if class_prop.value == "Cluster" {
                    cluster := fbx_object(.Cluster, FBX_Cluster, *obj);
                    parse_cluster(it.node, cluster);
                    
                } else if (class_prop.value == "Skin") {
                    skin := fbx_object(.Skin, FBX_Skin, *obj);
                    
                } else if (class_prop.value == "BlendShape") {
                    blend_shape := fbx_object(.Blend_Shape, FBX_Blend_Shape, *obj);
                    
                } else if (class_prop.value == "BlendShapeChannel") {
                    blend_shape_channel := fbx_object(.Blend_Shape_Channel, FBX_Blend_Shape_Channel, *obj);
                }
            }
            
        } else if it.node.id == "NodeAttribute" {
            
            node_attribute := fbx_object(.Node_Attribute, FBX_Node_Attribute, *obj);
            parse_node_attribute(it.node, node_attribute);
            
        } else if it.node.id == "Model" {
            class_prop := it.node.properties[2];
            name       := it.node.properties[1].value;
            build_name := false;
            if class_prop == null {
                class_prop = it.node.properties[1];
                build_name = true;
            }
            
            if class_prop != null {
                
                if class_prop.value == "Mesh" {
                    
                    mesh := fbx_object(.Mesh, FBX_Mesh, *obj);
                    
                    if build_name {
                        name_builder := String_Builder.{};
                        append(*name_builder, "Mesh_");
                        print_to_builder(*name_builder, "%", scene.meshes.count);
                        name = builder_to_string(*name_builder);
                    }
                    mesh.name = name;
                    parse_mesh(it.node, mesh);
                    mesh.mesh_id = scene.meshes.count;
                    array_add(*scene.meshes, mesh);
                    
                } else if class_prop.value == "LimbNode" {
                    limb := fbx_object(.Limb_Node, FBX_Limb_Node, *obj);
                    array_add(*scene.limb_nodes, limb);
                    
                } else if class_prop.value == "Null" || class_prop.value == "Root" {
                    null_object := fbx_object(.Null_Node, FBX_Null_Node, *obj);
                    
                } else {
                    print("Unimplemented Model sub-type: %\n", class_prop.value);
                }
            }
            
        } else if it.node.id == "Texture" {
            texture := fbx_object(.Texture, FBX_Texture, *obj);
            parse_texture(it.node, texture);
            
        } else if it.node.id == "Video" {
            // DO THIS MAYBE.
            
        } else if it.node.id == "Pose" {
            pose := fbx_object(.Pose, FBX_Pose, *obj);
            parse_pose(it.node, pose);
            
        } else {
            print("Unimplemented FBX Type: %\n", it.node.id);
        }
        
        
        
        {
            // TRYING TO FIND MORE PROPERTIES I HAVEN'T PARSED YET.
            
            rotation_order, order_found := find_property_node_s32(it.node, "RotationOrder");
            if order_found {
                print("rotation_order of %: %\n", it.node.id, rotation_order);
            }
            
            // NOTE: Other properties:
            // InheritType : Describes how the scaling inheritance is computed.
        }
        
        
        
        if obj != null {
            parse_object_transformations(obj, it.node, *scene.settings);
            obj.id    = it_index;
            obj.node  = it.node;
            it.object = obj;
            array_add(*scene.all_objects, obj);
        }
    }
    
    
    
    // -------- CONNECTIONS ----------------
    
    
    
    for conn: scene.connections {
        if conn.type == .Property_Property continue;
        
        parent_conn, success_parent := table_find(*scene.object_map, conn.to_object);
        child_conn, success_child   := table_find(*scene.object_map, conn.from_object);
        
        parent := parent_conn.object;
        child  := child_conn.object;
        
        // NOTE: it's possible they were not parsed in the above step,
        // maybe because we're ignoring that type.
        if child == null || parent == null continue;
        
        if child.type == {
            case .Node_Attribute; {
                if parent.node_attribute != null {
                    invalid_code_path("Parent already has a node attribute.\n");
                }
                parent.node_attribute = cast(*FBX_Node_Attribute)child;
            }
            case .Animation_Curve_Node; {
                if is_node(parent) {
                    curve_node := cast(*FBX_Animation_Curve_Node)child;
                    curve_node.link = parent;
                    curve_node.link_property = conn.to_property;
                    if curve_node.link_property == {
                        case "Lcl Translation"; curve_node.mode = .Translation;
                        case "Lcl Rotation";    curve_node.mode = .Rotation;
                        case "Lcl Scaling";     curve_node.mode = .Scaling;
                    }
                    
                    if parent.type == .Limb_Node {
                        limb := cast(*FBX_Limb_Node)parent;
                        array_add(*limb.animation_curve_nodes, curve_node);
                        
                    } else if parent.type == .Null_Node {
                        null_ := cast(*FBX_Null_Node)parent;
                        array_add(*null_.animation_curve_nodes, curve_node);
                        
                    }
                    
                }
            }
        }
        
        if is_node(parent) {
            child.parent = parent;
        }
        
        if #complete parent.type == {
            case .Root; {
            }
            case .Geometry; {
                geometry := cast(*FBX_Geometry)parent;
                
                if child.type == .Skin {
                    skin := cast(*FBX_Skin)child;
                    if geometry.skin != null && geometry.skin != skin {
                        invalid_code_path("Geometry already has a skin.\n");
                    }
                    geometry.skin = skin;
                    skin.geometry = geometry;
                    
                } else if child.type == .Blend_Shape {
                    blend_shape := cast(*FBX_Blend_Shape)child;
                    if geometry.blend_shape != null && geometry.blend_shape != blend_shape {
                        invalid_code_path("Geometry alreayd has a blend shape.\n");
                    }
                    geometry.blend_shape = blend_shape;
                    blend_shape.geometry = geometry;
                }
            }
            case .Shape; {
            }
            case .Material; {
                mat := cast(*FBX_Material)parent;
                if child.type == .Texture {
                    type: Mesh_Texture_Type;
                    if conn.to_property == {
                        case "NormalMap"; {
                            type = .Normal;
                        }
                        case "DiffuseColor"; {
                            type = .Diffuse;
                        }
                        case "SpecularColor"; {
                            type = .Specular;
                        }
                        case "ShininessExponent"; {
                            type = .Shininess;
                        }
                        case "EmissiveColor"; {
                            type = .Emissive;
                        }
                        case "AmbientColor"; {
                            type = .Ambient;
                        }
                        case "ReflectionColor"; {
                            type = .Reflection;
                        }
                    }
                    if type < .Count {
                        if mat.textures[type] == null {
                            mat.textures[type] = cast(*FBX_Texture)child;
                        } else {
                            // NOTE If it's not null then maybe there are multiple of that
                            // map type on the material, which we do not support.
                        }
                    }
                }
            }
            case .Mesh; {
                
                mesh := cast(*FBX_Mesh)parent;
                
                if child.type == .Skin {
                    skin := cast(*FBX_Skin)child;
                    if mesh.skin != null && mesh.skin != skin {
                        invalid_code_path("Mesh already has a skin.\n");
                    }
                    mesh.skin = skin;
                    skin.mesh = mesh;
                    
                } else if child.type == .Blend_Shape {
                    mesh.blend_shape = cast(*FBX_Blend_Shape)child;
                    
                } else if child.type == .Geometry {
                    if mesh.geometry != null {
                        invalid_code_path("Invalid mesh, somehow multiple geometry?\n");
                    }
                    geometry := cast(*FBX_Geometry)child;
                    mesh.geometry = geometry;
                    geometry.mesh = mesh;
                    
                } else if child.type == .Material {
                    array_add(*mesh.materials, cast(*FBX_Material)child);
                    
                }
                
            }
            case .Texture; {
            }
            case .Limb_Node; {
                
                limb_node := cast(*FBX_Limb_Node)parent;
                
                if child.type == .Limb_Node {
                    child_limb := cast(*FBX_Limb_Node)child;
                    if child_limb.parent_limb != null && child_limb.parent_limb != limb_node {
                        invalid_code_path("Invalid skeletal structure. Limb already has another parent.\n");
                    }
                    child_limb.parent_limb = limb_node;
                    array_add(*limb_node.child_limbs, child_limb);
                }
                
            }
            case .Null_Node; {
                
                null_node := cast(*FBX_Null_Node)parent;
                
                if child.type == .Limb_Node {
                    child_limb := cast(*FBX_Limb_Node)child;
                    if child_limb.parent != null && child_limb.parent != null_node {
                        invalid_code_path("Invalid skeletal structure. Limb already has another parent.\n");
                    }
                    array_add(*null_node.child_limbs, child_limb);
                }
                
            }
            case .Camera; {
            }
            case .Light; {
            }
            case .Node_Attribute; {
            }
            case .Cluster; {
                
                cluster := cast(*FBX_Cluster)parent;
                
                if child.type == .Limb_Node ||
                    child.type == .Mesh ||
                    child.type == .Null_Node {
                    
                    if cluster.link != null && cluster.link != child {
                        invalid_code_path("Cluster already has link.\n");
                    }
                    cluster.link = child;
                    
                    // NOTE: there is no guarantee that there is a one to one
                    // relationship between clusters and links, since,
                    // 2 clusters from different meshes could be connected to 
                    // the same limb, if they share the skeletal structure.
                    
                    if child.type == .Limb_Node {
                        limb_node := cast(*FBX_Limb_Node)child;
                        array_add(*limb_node.clusters, cluster);
                        
                    } else if child.type == .Null_Node {
                        null_node := cast(*FBX_Null_Node)child;
                        array_add(*null_node.clusters, cluster);
                        
                    }
                }
                
            }
            case .Skin; {
                
                skin := cast(*FBX_Skin)parent;
                
                if child.type == .Cluster {
                    cluster := cast(*FBX_Cluster)child;
                    if cluster.skin != null {
                        invalid_code_path("Cluster already has a skin\n");
                    }
                    array_add(*skin.clusters, cluster);
                    cluster.skin = skin;
                }
                
            }
            case .Blend_Shape; {
                
                blend_shape := cast(*FBX_Blend_Shape)parent;
                if child.type == .Blend_Shape_Channel {
                    channel := cast(*FBX_Blend_Shape_Channel)child;
                    if channel.blend_shape != null {
                        invalid_code_path("Blend Shape Channel already has a blend shape\n");
                    }
                    array_add(*blend_shape.channels, channel);
                    channel.blend_shape = blend_shape;
                }
                
            }
            case .Blend_Shape_Channel; {
                
                blend_shape_channel := cast(*FBX_Blend_Shape_Channel)parent;
                
                if child.type == .Shape {
                    shape := cast(*FBX_Shape)child;
                    array_add(*blend_shape_channel.shapes, shape);
                }
                
            }
            case .Animation_Stack; {
                
                animation_stack := cast(*FBX_Animation_Stack)parent;
                if child.type == .Animation_Layer {
                    layer := cast(*FBX_Animation_Layer)child;
                    array_add(*animation_stack.layers, layer);
                }
            }
            case .Animation_Layer; {
                
                animation_layer := cast(*FBX_Animation_Layer)parent;
                if child.type == .Animation_Curve_Node {
                    curve_node := cast(*FBX_Animation_Curve_Node)child;
                    array_add(*animation_layer.curve_nodes, curve_node);
                }
            }
            case .Animation_Curve; {
            }
            case .Animation_Curve_Node; {
                
                curve_node := cast(*FBX_Animation_Curve_Node)parent;
                if child.type == .Animation_Curve {
                    curve := cast(*FBX_Animation_Curve)child;
                    if begins_with(conn.to_property, "d|X") {
                        curve_node.curves[0] = curve;
                        curve.default_value  = curve_node.default_values.x;
                    } else if begins_with(conn.to_property, "d|Y") {
                        curve_node.curves[1] = curve;
                        curve.default_value  = curve_node.default_values.y;
                    } else if begins_with(conn.to_property, "d|Z") {
                        curve_node.curves[2] = curve;
                        curve.default_value  = curve_node.default_values.z;
                    }
                    if curve.max_time > curve_node.max_time curve_node.max_time = curve.max_time;
                    if curve.min_time < curve_node.min_time curve_node.min_time = curve.min_time;
                }
                
            }
            case .Pose; {
                
            }
        }
        
        
        
    }
    
    
    // --------------- MORE PARSING AFTER CONNECTIONS ARE ESTABLISHED ------------
    
    for * scene.object_map {
        if it.object == null continue;
        if it.object.type == {
            case .Cluster; {
                post_parse_cluster(xx it.object);
            }
            case .Geometry; {
                post_parse_geometry(xx it.object);
            }
            case .Mesh; {
                post_parse_mesh(xx it.object);
            }
            case .Limb_Node; {
                post_parse_limb_node(xx it.object, scene);
            }
            case .Null_Node; {
                
            }
            case .Blend_Shape_Channel; {
                post_parse_blend_shape_channel(xx it.object);
            }
            case .Pose; {
                post_parse_pose(xx it.object, scene);
            }
            case .Animation_Stack; {
                post_parse_animation_stack(xx it.object, scene);
            }
        }
    }
    
}



parse_geometry :: (node: *FBX_Node, geometry: *FBX_Geometry) {
    assert(node.properties.count > 0);
    
    got_materials := parse_geometry_materials(geometry, node);
    
    vertices_node := find_child(node, "Vertices");
    if vertices_node == null return;
    if vertices_node.properties.count == 0 return;
    
    polygon_vertex_index_node := find_child(node, "PolygonVertexIndex");
    assert(polygon_vertex_index_node != null);
    assert(polygon_vertex_index_node.properties.count > 0);
    
    vertex_value_prop := vertices_node.properties[0];
    gather_prop_array_v3(vertex_value_prop, *geometry.vertices);
    
    pvi_value_prop := polygon_vertex_index_node.properties[0];
    gather_prop_array_s32(pvi_value_prop, *geometry.vertex_indices);
    
    
    uv_nodes := find_children(node, "LayerElementUV");
    for uv_nodes {
        uv_index: s32 = 0;
        if it.properties.count > 0 {
            uv_index = it.properties[0].value_s32;
        }
        if uv_index >= 0 && uv_index < MAX_UVS {
            
            data_node := find_child(it, "UV");
            assert(data_node != null);
            assert(data_node.properties.count > 0);
            
            geometry.uv_mapping[uv_index] = parse_vertex_data_mapping(it);
            parse_vertex_data_indices(it, *geometry.uv_indices[uv_index], "UVIndex");
            data_prop := data_node.properties[0];
            gather_prop_array_v2(data_prop,  *geometry.uvs[uv_index]);
        }
    }
    
    tangent_node := find_child(node, "LayerElementTangents"); 
    if tangent_node == null tangent_node = find_child(node, "LayerElementTangent");
    if tangent_node != null {
        data_node        := find_child(node, "Tangents");
        index_node_name  := "TangentsIndex";
        if data_node == null {
            data_node = find_child(node, "Tangent");
            index_node_name  = "TangentIndex";
        }
        if data_node != null && data_node.properties.count > 0 {
            geometry.tangent_mapping = parse_vertex_data_mapping(tangent_node);
            parse_vertex_data_indices(tangent_node, *geometry.tangent_indices, index_node_name);
            data_prop := data_node.properties[0];
            gather_prop_array_v3(data_prop, *geometry.tangents);
        }
    }
    
    color_node := find_child(node, "LayerElementColor");
    if color_node != null {
        geometry.color_mapping = parse_vertex_data_mapping(color_node);
        parse_vertex_data_indices(color_node, *geometry.color_indices, "ColorIndex");
        data_node := find_child(color_node, "Colors");
        if data_node != null && data_node.properties.count > 0 {
            data_prop := data_node.properties[0];
            gather_prop_array_color(data_prop, *geometry.colors);
        }
    }
    
    normal_node := find_child(node, "LayerElementNormal");
    if normal_node != null {
        geometry.normal_mapping = parse_vertex_data_mapping(normal_node);
        parse_vertex_data_indices(normal_node, *geometry.normal_indices, "NormalsIndex");
        data_node := find_child(normal_node, "Normals");
        if data_node != null && data_node.properties.count > 0 {
            data_prop := data_node.properties[0];
            gather_prop_array_v3(data_prop, *geometry.normals);
        }
    }
}


parse_vertex_data_mapping :: (node: *FBX_Node) -> FBX_Vertex_Data_Mapping {
    mapping_node := find_child(node, "MappingInformationType");
    if mapping_node != null && mapping_node.properties.count > 0 {
        mapping_value := mapping_node.properties[0].value;
        if mapping_value == "ByPolygonVertex" {
            return .By_Polygon_Vertex;
        } else if mapping_value == "ByPolygon" {
            return .By_Polygon;
        } else if mapping_value == "ByVertice" || mapping_value == "ByVertex" {
            return .By_Vertex;
        } else if mapping_value == "ByEdge" {
            // NOTE: This is EXTREMELY rare!
            return .By_Edge;
        } else if mapping_value == "AllSame" {
            // NOTE: This is also rare, but maybe when dealing
            // with a flat plane?
            return .All_Same;
        }
    }
    return .Unknown;
}

parse_vertex_data_indices :: (node: *FBX_Node, index_array: *[..]s32, index_node_name: string) {
    reference_node := find_child(node, "ReferenceInformationType");
    if reference_node != null && reference_node.properties.count > 0 {
        ref_value := reference_node.properties[0].value;
        if ref_value == "IndexToDirect" {
            index_node := find_child(node, index_node_name);
            if index_node != null && index_node.properties.count > 0 {
                
                index_prop := index_node.properties[0];
                gather_prop_array_s32(index_prop, index_array);
                
            }
        } else if ref_value == "Direct" {
            // NOTE:
            // This means that the index of the normal/uv/etc in their array,
            // is the same as the index of the vertex in the vertices array,
            // so we can use the vertex_indices array to get them.
            
            // This likely happens when there are many unique normals/uvs/etc,
            // because if many were duplicates, using references would be
            // more efficient.
        }
    }
}

gather_prop_array_s32 :: (prop: *FBX_Property, arr: *[..]s32) {
    if prop.length > 0 {
        for value_index: 0 .. prop.length - 1 {
            value := prop.array_s32[value_index];
            array_add(arr, value);
        }
    }
}

gather_prop_array_s64 :: (prop: *FBX_Property, arr: *[..]s64) {
    if prop.length > 0 {
        for value_index: 0 .. prop.length - 1 {
            value := prop.array_s64[value_index];
            array_add(arr, value);
        }
    }
}

gather_prop_array_f32 :: (prop: *FBX_Property, arr: *[..]f32) {
    if prop.length > 0 {
        for value_index: 0 .. prop.length - 1 {
            value: f32;
            if prop.type == .Array_Float {
                value = prop.array_f32[value_index];
            } else if prop.type == .Array_Double {
                value = xx prop.array_f64[value_index];
            } else {
                invalid_code_path("Attemping to gather prop array of floats, but prop isn't a valid type\n");
            }
            array_add(arr, value);
        }
    }
}

gather_prop_array_v2 :: (prop: *FBX_Property, arr: *[..]V2) {
    if prop.length > 0 {
        for value_index: 0 .. prop.length - 1 {
            value: V2;
            if prop.type == .Array_Float {
                value.x = prop.array_f32[value_index];
                value.y = prop.array_f32[value_index + 1];
            } else if prop.type == .Array_Double {
                value.x = cast(f32)(prop.array_f64[value_index]);
                value.y = cast(f32)(prop.array_f64[value_index + 1]);
            }
            array_add(arr, value);
            
            // since I'm getting 2 at a time and the for loop increments only once.
            value_index += 1;
        }
    }
}


gather_prop_array_v3 :: (prop: *FBX_Property, arr: *[..]V3) {
    if prop.length > 0 {
        for value_index: 0 .. prop.length - 1 {
            value: V3;
            if prop.type == .Array_Float {
                value.x = prop.array_f32[value_index];
                value.y = prop.array_f32[value_index + 1];
                value.z = prop.array_f32[value_index + 2];
            } else if prop.type == .Array_Double {
                value.x = cast(f32)(prop.array_f64[value_index]);
                value.y = cast(f32)(prop.array_f64[value_index + 1]);
                value.z = cast(f32)(prop.array_f64[value_index + 2]);
            }
            array_add(arr, value);
            
            // since I'm getting 3 at a time and the for loop increments only once.
            value_index += 2;
        }
    }
}



gather_prop_array_color :: (prop: *FBX_Property, arr: *[..]Color) {
    if prop.length > 0 {
        for value_index: 0 .. prop.length - 1 {
            value: Color;
            if prop.type == .Array_Float {
                value.r = prop.array_f32[value_index];
                value.g = prop.array_f32[value_index + 1];
                value.b = prop.array_f32[value_index + 2];
                value.a = prop.array_f32[value_index + 3];
            } else if prop.type == .Array_Double {
                value.r = cast(f32)(prop.array_f64[value_index]);
                value.g = cast(f32)(prop.array_f64[value_index + 1]);
                value.b = cast(f32)(prop.array_f64[value_index + 2]);
                value.a = cast(f32)(prop.array_f64[value_index + 3]);
            }
            array_add(arr, value);
            
            // since I'm getting 4 at a time and the for loop increments only once.
            value_index += 3;
        }
    }
}


gather_prop_matrix :: (prop: *FBX_Property, matrix: *Matrix4) {
    assert(prop.length == 16);
    // FBX is column major encoded as flat array.
    // 1,5,6,7  would be the first column of the matrix.
    // Our matrices are row major, so we have to encode in reverse.
    for col: 0 .. 3 {
        for row: 0 .. 3 {
            
            value_index := (col * 4) + row;
            
            if prop.type == .Array_Float {
                matrix.coef[row][col] = prop.array_f32[value_index];
            } else if prop.type == .Array_Double {
                matrix.coef[row][col] = cast(f32)(prop.array_f64[value_index]);
            } else {
                invalid_code_path("gather_prop_matrix -> Prop was not a float or double array.\n");
            }
        }
    }
}






parse_object_transformations :: (object: *FBX_Object, node: *FBX_Node, settings: *FBX_Global_Settings) {
    
    if object.type == .Root {
        // object.xform_matrix = identity_matrix();
        a := 0;
    }
    
    object.position        = find_property_node_v3(node, "Lcl Translation");
    object.rotation_offset = find_property_node_v3(node, "RotationOffset");
    object.rotation_pivot  = find_property_node_v3(node, "RotationPivot");
    object.pre_rotation    = find_property_node_v3(node, "PreRotation");
    object.rotation        = find_property_node_v3(node, "Lcl Rotation");
    object.post_rotation   = find_property_node_v3(node, "PostRotation");
    object.scale_offset    = find_property_node_v3(node, "ScalingOffset");
    object.scale_pivot     = find_property_node_v3(node, "ScalingPivot");
    object.scale           = find_property_node_v3(node, "Lcl Scaling");
    
    p:     = translation_matrix(object.position);
    ro:    = translation_matrix(object.rotation_offset);
    rp:    = translation_matrix(object.rotation_pivot);
    _rp:   = inverse(rp);
    pre:   = rotation_matrix(quaternion(object.pre_rotation));
    r:     = rotation_matrix(quaternion(object.rotation));
    post:  = rotation_matrix(quaternion(object.post_rotation));
    _post: = inverse(post);
    so:    = translation_matrix(object.scale_offset);
    sp:    = translation_matrix(object.scale_pivot);
    _sp:   = inverse(sp);
    s:     = scaling_matrix(object.scale);
    xform: = p * ro * rp * pre * r * _post * _rp * so * sp * s * _sp;
    
    // xform  = settings.desired_basis_xform * xform;
    object.xform_matrix = xform;
}



evaluate_animation_transform :: (anim_xform: *Animation_Transform, scene: *FBX_Scene) -> Matrix4 {
    
    obj_pair: = table_find_pointer(*scene.object_map, anim_xform.ref_id);
    assert(obj_pair != null);
    object:   = obj_pair.object;
    
    p:     = translation_matrix(anim_xform.position);
    r:     = rotation_matrix(quaternion(anim_xform.rotation));
    s:     = scaling_matrix(anim_xform.scale);
    
    ro:    = translation_matrix(object.rotation_offset);
    rp:    = translation_matrix(object.rotation_pivot);
    _rp:   = inverse(rp);
    pre:   = rotation_matrix(quaternion(object.pre_rotation));
    post:  = rotation_matrix(quaternion(object.post_rotation));
    _post: = inverse(post);
    so:    = translation_matrix(object.scale_offset);
    sp:    = translation_matrix(object.scale_pivot);
    _sp:   = inverse(sp);
    
    xform: = p * ro * rp * pre * r * _post * _rp * so * sp * s * _sp;
    
    return xform;
    
}







parse_geometry_materials :: (geometry: *FBX_Geometry, node: *FBX_Node) -> bool {
    layer_material_node := find_child(node, "LayerElementMaterial");
    if layer_material_node == null return true;
    
    mapping_node   := find_child(layer_material_node, "MappingInformationType");
    reference_node := find_child(layer_material_node, "ReferenceInformationType");
    
    if mapping_node == null || reference_node == null return false;
    if mapping_node.properties.count   == 0 return false;
    if reference_node.properties.count == 0 return false;
    
    if mapping_node.properties[0].value == "ByPolygon" &&
        reference_node.properties[0].value == "IndexToDirect" {
        
        indices_node := find_child(layer_material_node, "Materials");
        if indices_node == null return false;
        if indices_node.properties.count == 0 return false;
        
        values_prop := indices_node.properties[0];
        if values_prop.length > 0 {
            for material_index : 0 .. values_prop.length - 1 {
                array_add(*geometry.material_indices, values_prop.array_s32[material_index]);
            }
        }
        
    } else {
        if mapping_node.properties[0].value != "AllSame" return false;
        // NOTE: In this case, we can just use the material
        // that is on the Mesh that is holding the geometry
        // whose materials we are trying to parse.
        // Just use that one material for the whole mesh,
        // which is probably common.
    }
    
    return true;
}








parse_material :: (node: *FBX_Node, material: *FBX_Material) {
    
    property_id     := "P";
    property_offset : u32 = 4;
    properties_node := find_child(node, "Properties70");
    
    if properties_node == null {
        property_id     = "Property";
        property_offset = 3;
        properties_node = find_child(node, "Properties60");
    }
    
    material.diffuse_color = .{r=1,g=1,b=1,a=1};
    
    if properties_node != null {
        for prop_node: properties_node.children {
            
            if prop_node.id == property_id && prop_node.properties.count > 0 {
                
                prop_name_prop := prop_node.properties[0];
                
                get_color :: (node: *FBX_Node, color: *Color, property_offset: u32) {
                    color.r = cast(f32)node_get_property_f64(node, property_offset);
                    color.g = cast(f32)node_get_property_f64(node, property_offset + 1);
                    color.b = cast(f32)node_get_property_f64(node, property_offset + 2);
                }
                
                if prop_name_prop.value == "DiffuseColor" {
                    get_color(prop_node, *material.diffuse_color, property_offset);
                } else if prop_name_prop.value == "SpecularColor" {
                    get_color(prop_node, *material.specular_color, property_offset);
                } else if prop_name_prop.value == "Shininess" {
                    material.shininess = node_get_property_f64(prop_node, property_offset);
                } else if prop_name_prop.value == "ShininessExponent" {
                    material.shininess_exponent = node_get_property_f64(prop_node, property_offset);
                } else if prop_name_prop.value == "ReflectionColor" {
                    get_color(prop_node, *material.reflection_color, property_offset);
                } else if prop_name_prop.value == "AmbientColor" {
                    get_color(prop_node, *material.ambient_color, property_offset);
                } else if prop_name_prop.value == "EmissiveColor" {
                    get_color(prop_node, *material.emissive_color, property_offset);
                } else if prop_name_prop.value == "ReflectionFactor" {
                    material.reflection_factor = node_get_property_f64(prop_node, property_offset);
                } else if prop_name_prop.value == "BumpFactor" {
                    material.bump_factor = node_get_property_f64(prop_node, property_offset);
                } else if prop_name_prop.value == "AmbientFactor" {
                    material.ambient_factor = node_get_property_f64(prop_node, property_offset);
                } else if prop_name_prop.value == "DiffuseFactor" {
                    material.diffuse_factor = node_get_property_f64(prop_node, property_offset);
                } else if prop_name_prop.value == "SpecularFactor" {
                    material.specular_factor = node_get_property_f64(prop_node, property_offset);
                } else if prop_name_prop.value == "EmissiveFactor" {
                    material.emissive_factor = node_get_property_f64(prop_node, property_offset);
                }
                
            }
        }
    }
    
}



parse_mesh :: (node: *FBX_Node, mesh: *FBX_Mesh) {
    assert(node.properties.count > 0);
    assert(node.properties[0] != null);
    
    // Feel like this is obsolete for newer versions of fbx files
    // This is just a repeat more or less of parse geometry,
    // since older versions had geometry data in the mesh. So we cross that
    // bridge when we get to it.
    
    // So for now we only have the mesh so we can link it,
    // it's materials, and the geometry data, all together.
    
    /*
    vertices_node := find_child(node, "Vertices");
    if vertices_node == null || vertices_node.properties.count == 0 return;
    
    pvi_node := find_child(node, "PolygonVertexIndex");
    if pvi_node == null || pvi_node.properties.count == 0 return;
    */
}


parse_texture :: (node: *FBX_Node, tex: *FBX_Texture) {
    
    filename_node := find_child(node, "FileName");
    if filename_node != null && filename_node.properties.count > 0 {
        tex.filename = filename_node.properties[0].value;
    }
    
    media_node := find_child(node, "Media");
    if media_node != null && media_node.properties.count > 0 {
        tex.data = media_node.properties[0].value;
    }
    
    relative_filename_node := find_child(node, "RelativeFilename");
    if relative_filename_node != null && relative_filename_node.properties.count > 0 {
        tex.relative_filename = relative_filename_node.properties[0].value;
    }
}


parse_pose :: (node: *FBX_Node, pose: *FBX_Pose) {
    pose_node_nodes := find_children(node, "PoseNode");
    for pose_node_node: pose_node_nodes {
        if pose_node_node == null continue;
        
        pose_node := FBX_Pose_Node.{};
        
        node_node   := find_child(pose_node_node, "Node");
        matrix_node := find_child(pose_node_node, "Matrix");
        
        if matrix_node != null && matrix_node.properties.count > 0 {
            gather_prop_matrix(matrix_node.properties[0], *pose_node.matrix);
        }
        
        pose_node.node_id = node_node.properties[0].value_u64;
        array_add(*pose.nodes, pose_node);
    }
}

parse_cluster :: (node: *FBX_Node, cluster: *FBX_Cluster) {
    transform_link_node := find_child(node, "TransformLink");
    if transform_link_node != null && transform_link_node.properties.count > 0 {
        gather_prop_matrix(transform_link_node.properties[0], *cluster.transform_link_matrix);
    }
    
    transform_node := find_child(node, "Transform");
    if transform_node != null && transform_node.properties.count > 0 {
        gather_prop_matrix(transform_node.properties[0], *cluster.transform_matrix);
    }
}



parse_node_attribute :: (node: *FBX_Node, node_attribute: *FBX_Node_Attribute) {
    type_flags_node := find_child(node, "TypeFlags");
    if type_flags_node != null && type_flags_node.properties.count > 0 {
        node_attribute.attribute_type = type_flags_node.properties[0].value;
    }
}



parse_animation_curve :: (node: *FBX_Node, animation_curve: *FBX_Animation_Curve) {
    times_node:          = find_child(node, "KeyTime");
    values_node:         = find_child(node, "KeyValueFloat");
    attr_flags_node:     = find_child(node, "KeyAttrFlags");
    attr_data_node:      = find_child(node, "KeyAttrDataFloat");
    attr_ref_count_node: = find_child(node, "KeyAttrRefCount");
    
    if times_node != null && times_node.properties.count > 0 {
        gather_prop_array_s64(times_node.properties[0], *animation_curve.times);
        for animation_curve.times {
            if it > animation_curve.max_time animation_curve.max_time = it;
            if it < animation_curve.min_time animation_curve.min_time = it;
        }
    }
    
    if values_node != null && values_node.properties.count > 0 {
        gather_prop_array_f32(values_node.properties[0], *animation_curve.values);
    }
    
    if animation_curve.times.count != animation_curve.values.count {
        invalid_code_path("Invalid animation curve\n");
    }
    
    if attr_flags_node != null && attr_flags_node.properties.count > 0 {
        gather_prop_array_s32(attr_flags_node.properties[0], *animation_curve.attr_flags);
    }
    
    if attr_data_node != null && attr_data_node.properties.count > 0 {
        gather_prop_array_f32(attr_data_node.properties[0], *animation_curve.attr_data);
    }
    
    if attr_ref_count_node != null && attr_ref_count_node.properties.count > 0 {
        gather_prop_array_s32(attr_ref_count_node.properties[0], *animation_curve.attr_ref_count);
    }
    
    
    
}


parse_animation_curve_node :: (node: *FBX_Node, animation_curve_node: *FBX_Animation_Curve_Node) {
    
    animation_curve_node.default_values = V3.{x=0,y=0,z=0};
    is_p60 := false;
    x_node := find_property_node(node, "d|X", *is_p60);
    y_node := find_property_node(node, "d|Y", *is_p60);
    z_node := find_property_node(node, "d|Z", *is_p60);
    
    if x_node != null {
        x_prop := x_node.properties[4];
        if x_prop != null {
            animation_curve_node.default_values.x = cast(f32)x_prop.value_f64;
        }
    }
    
    if y_node != null {
        y_prop := y_node.properties[4];
        if y_prop != null {
            animation_curve_node.default_values.y = cast(f32)y_prop.value_f64;
        }
    }
    
    if z_node != null {
        z_prop := z_node.properties[4];
        if z_prop != null {
            animation_curve_node.default_values.z = cast(f32)z_prop.value_f64;
        }
    }
    
}




find_property_node :: (node: *FBX_Node, name: string, is_p60: *bool) -> *FBX_Node {
    
    <<is_p60 = false;
    props_node := find_child(node, "Properties70");
    if props_node == null {
        props_node = find_child(node, "Properties60");
        <<is_p60 = true;
        if props_node == null return null;
    }
    
    for prop_node: props_node.children {
        if prop_node.properties.count > 0 && 
            prop_node.properties[0] != null &&
            prop_node.properties[0].value == name {
            return prop_node;
        }
    }
    return null;
}



find_property_node_v3 :: (node: *FBX_Node, name: string) -> V3, bool {
    is_p60 := false;
    prop_node := find_property_node(node, name, *is_p60);
    v3 := V3.{};
    
    if prop_node == null return v3, false;
    
    v3.x = xx node_get_property_f64(prop_node, 4);
    v3.y = xx node_get_property_f64(prop_node, 5);
    v3.z = xx node_get_property_f64(prop_node, 6);
    
    return v3, true;
}

find_property_node_s32 :: (node: *FBX_Node, name: string) -> s32, bool {
    is_p60 := false;
    prop_node := find_property_node(node, name, *is_p60);
    
    result: s32 = 0;
    
    if prop_node == null return result, false;
    
    result = xx node_get_property_s32(prop_node, 4);
    
    return result, true;
}

// NOTE: this is just to be explicity. Maybe make it take an enum
// type as another parameter and cast the return value to that type.
find_property_node_enum :: (node: *FBX_Node, name: string) -> s32, bool {
    val, found := find_property_node_s32(node, name);
    return val, found;
}


find_property_node_f32 :: (node: *FBX_Node, name: string) -> f32, bool {
    is_p60 := false;
    prop_node := find_property_node(node, name, *is_p60);
    
    result: f32 = 0.0;
    
    if prop_node == null return result, false;
    
    result = xx node_get_property_f32(prop_node, 4);
    
    return result, true;
}



parse_light :: () {
}

parse_camera :: () {
}












post_parse_cluster :: (cluster: *FBX_Cluster) {
    node := cluster.node;
    
    if cluster.skin.geometry == null && cluster.skin.mesh == null {
        invalid_code_path("Cluster has no geometry.\n");
    }
    
    indices_node := find_child(node, "Indexes");
    if indices_node != null && indices_node.properties.count > 0 {
        gather_prop_array_s32(indices_node.properties[0], *cluster.indices);
    }
    
    weights_node := find_child(node, "Weights");
    if weights_node != null && weights_node.properties.count > 0 {
        gather_prop_array_f32(weights_node.properties[0], *cluster.weights);
    }
}


post_parse_geometry :: (geometry: *FBX_Geometry) {
    
}


post_parse_mesh :: (mesh: *FBX_Mesh) {
    
}

post_parse_limb_node :: (limb: *FBX_Limb_Node, scene: *FBX_Scene) {
    
    set_limb_skeleton_id :: (child: *FBX_Object, id: u32) {
        if child.type == .Limb_Node {
            limb := cast(*FBX_Limb_Node)child;
            limb.skeleton_id = id;
            for limb.child_limbs {
                set_limb_skeleton_id(it, id);
            }
        } else if child.type == .Null_Node {
            null_node := cast(*FBX_Null_Node)child;
            null_node.skeleton_id = id;
            for null_node.child_limbs {
                set_limb_skeleton_id(it, id);
            }
        }
    }
    
    if limb.parent_limb == null {
        skeletal_root := *limb.base;
        while skeletal_root.parent != null {
            parent := skeletal_root.parent;
            if parent == scene.root break;
            if parent.type != .Limb_Node && parent.type != .Null_Node break;
            skeletal_root = parent;
        }
        skeleton_id := scene.limb_roots.count;
        array_add(*scene.limb_roots, skeletal_root);
        set_limb_skeleton_id(skeletal_root, xx skeleton_id);
    }
}


post_parse_blend_shape_channel :: (blend_shape_channel: *FBX_Blend_Shape_Channel) {
    node := blend_shape_channel.node;
    
    geometry := blend_shape_channel.blend_shape.geometry;
    if geometry == null {
        invalid_code_path("Blend shape channel has no geometry.\n");
    }
    
    
    deform_percent_node := find_child(node, "DeformPercent");
    if deform_percent_node != null && deform_percent_node.properties.count > 0 {
        blend_shape_channel.deform_percent = xx deform_percent_node.properties[0].value_f64;
    }
    
    
    for blend_shape_channel.shapes {
        post_parse_shape(it);
    }
}

post_parse_shape :: (shape: *FBX_Shape) {
    node := shape.node;
    
    vertices_node := find_child(node, "Vertices");
    normals_node  := find_child(node, "Normals");
    indices_node  := find_child(node, "Indexes");
    if vertices_node == null || vertices_node.properties.count == 0 ||
        indices_node == null || indices_node.properties.count == 0 {
        invalid_code_path("Shape has no vertices or indices");
    }
    
    gather_prop_array_v3(vertices_node.properties[0], *shape.vertices);
    if normals_node != null && normals_node.properties.count > 0 {
        gather_prop_array_v3(normals_node.properties[0], *shape.normals);
    }
    gather_prop_array_s32(indices_node.properties[0], *shape.indices);
}


post_parse_pose :: (pose: *FBX_Pose, scene: *FBX_Scene) {
    for pose.nodes {
        obj_pair := table_find_pointer(*scene.object_map, it.node_id);
        assert(obj_pair != null);
        // here, node does not refer to fbx file format node, 
        // but what the pose calls a node.
        pose_node_object := obj_pair.object;
        
        if pose_node_object != null && pose_node_object.type == .Mesh {
            mesh := cast(*FBX_Mesh)pose_node_object;
            mesh.pose = it.matrix;
        }
    }
}




post_parse_animation_stack :: (stack: *FBX_Animation_Stack, scene: *FBX_Scene) {
    for layer: stack.layers {
        for curve_node: layer.curve_nodes {
            for curve: curve_node.curves {
                
                // Weird animation curve that has nothing in it.
                if curve.times.count == 0 continue;
                
                
                animation_time:  = fbx_time_to_seconds(curve.max_time - curve.min_time);
                animation_start: = fbx_time_to_seconds(curve.min_time);
                frame_count:     = seconds_to_keyframe(animation_time, *scene.settings) + 1;
                
                if frame_count > layer.frame_count layer.frame_count = frame_count;
                
                for 0 .. frame_count - 1 {
                    frame:              = FBX_Animation_Curve.Frame.{};
                    frame.keyframe      = -1;
                    frame.next_keyframe = -1;
                    frame.prev_keyframe = -1;
                    frame.value         = curve.default_value;
                    array_add(*curve.frames, frame);
                }
                
                
                prev_keyframe_frame_index : s32 = -1;
                
                for time: curve.times {
                    
                    seconds:            = fbx_time_to_seconds(time);
                    frame_index:        = seconds_to_keyframe(seconds, *scene.settings);
                    frame:              = curve.frames.data + frame_index;
                    frame.value         = curve.values[it_index];
                    frame.time          = xx seconds;
                    frame.keyframe      = xx it_index;
                    frame.prev_keyframe = prev_keyframe_frame_index;
                    if prev_keyframe_frame_index >= 0 {
                        prev_frame := curve.frames.data + prev_keyframe_frame_index;
                        prev_frame.next_keyframe = xx frame_index;
                    }
                    
                    prev_keyframe_frame_index = xx frame_index;
                }
                
                
                
                last_keyframe_attr_flags : FBX_Animation_Curve.Attribute_Flags = 0;
                
                // Finally do the value calculation
                for *frame: curve.frames {
                    
                    if frame.keyframe < 0 continue;
                    
                    frame_index := it_index;
                    
                    value := curve.values[frame.keyframe];
                    
                    flags : FBX_Animation_Curve.Attribute_Flags = last_keyframe_attr_flags;
                    if curve.attr_flags.count > frame.keyframe {
                        flags = xx curve.attr_flags[frame.keyframe];
                    }
                    
                    t_range:    = ((curve.frames.count - 1) - frame_index);
                    next_value: = value;
                    next_time:  = cast(f32)fbx_time_to_seconds(curve.max_time);
                    if frame.next_keyframe >= 0 {
                        next_keyframe_frame := curve.frames.data + frame.next_keyframe;
                        next_value           = next_keyframe_frame.value;
                        t_range              = frame.next_keyframe - frame_index;
                        next_time            = cast(f32)fbx_time_to_seconds(curve.times[next_keyframe_frame.keyframe]);
                    }
                    
                    start : s32 = xx (frame_index + 1);
                    end   : s32 = frame.next_keyframe - 1;
                    
                    // Nothing to interpolate.
                    // There could be no frames in between these keyframes.
                    if end <= start continue; 
                    
                    
                    
                    if curve_attribtue_flag(flags, .Interpolation_Constant) {
                        
                        if curve_attribtue_flag(flags, .Constant_Standard) {
                            
                        } else if curve_attribtue_flag(flags, .Constant_Next) {
                            
                        }
                        
                    } else if curve_attribtue_flag(flags, .Interpolation_Linear) {
                        // No extra data is needed.
                        // Just lerp between the keyframes.
                        
                        for start .. end {
                            t_frame:   = curve.frames.data + it;
                            t_current: = (it - start)  + 1;
                            t:         = cast(f32)t_current / cast(f32)t_range;
                            
                            t_frame.value = lerp(value, next_value, t);
                            t_frame.time  = lerp(frame.time, next_time, t);
                        }
                        
                        
                    } else if curve_attribtue_flag(flags, .Interpolation_Cubic) {
                        
                        velocity_mode: = curve_velocity_mode(flags);
                        weighted_mode: = curve_weighted_mode(flags);
                        tangent_show:  = curve_tangent_show(flags);
                        
                        
                        generic_clamp := curve_attribtue_flag(flags, .Tangent_Generic_Clamp);
                        generic_time_indpendent := curve_attribtue_flag(flags, .Tangent_Generic_Time_Independent);
                        generic_clamp_progressive := curve_attribtue_flag(flags, .Tangent_Generic_Clamp_Progressive);
                        
                        
                        control_points :: (v0: f32, 
                                           v1: f32, 
                                           right_slope: f32, 
                                           next_left_slope: f32, 
                                           right_weight: f32, 
                                           next_left_weight: f32) -> f32, f32, f32, f32 
                        {
                            
                            cp0 := v0;
                            cp1 := v0 + (right_slope * right_weight);
                            cp2 := v1 - (next_left_slope * next_left_weight);
                            cp3 := v1;
                            
                            return cp0, cp1, cp2, cp3;
                        }
                        
                        
                        // These three tangent types override other tangent modes (apparently)
                        if generic_clamp || generic_time_indpendent || generic_clamp_progressive {
                            
                            if generic_clamp {
                                
                            } else if generic_time_indpendent && !generic_clamp_progressive {
                                
                            } else if generic_clamp_progressive {
                                
                                
                                value_count := 2;
                                
                                if weighted_mode == .Weighted_Right ||
                                    weighted_mode == .Weighted_Next_Left {
                                    value_count = 3;
                                } else if weighted_mode == .Weighted_All {
                                    value_count = 4;
                                }
                                
                                data_offset := frame.keyframe * value_count;
                                
                                right_slope:      = curve.attr_data[data_offset];
                                next_left_slope:  = curve.attr_data[data_offset + 1];
                                right_weight:     = TANGENT_DEFAULT_WEIGHT;
                                next_left_weight: = TANGENT_DEFAULT_WEIGHT;
                                
                                if weighted_mode == .Weighted_Right {
                                    right_weight     = curve.attr_data[data_offset + 2];
                                } else if weighted_mode == .Weighted_Next_Left {
                                    next_left_weight = curve.attr_data[data_offset + 2];
                                } else if weighted_mode == .Weighted_All {
                                    right_weight     = curve.attr_data[data_offset + 2];
                                    next_left_weight = curve.attr_data[data_offset + 3];
                                }
                                
                                cp0, cp1, cp2, cp3 := control_points(value, 
                                                                     next_value,
                                                                     right_slope,
                                                                     next_left_slope,
                                                                     right_weight,
                                                                     next_left_weight);
                                
                                min_value: = min(value, next_value);
                                max_value: = max(value, next_value);
                                
                                for start .. end {
                                    t_frame:   = curve.frames.data + it;
                                    t_current: = (it - frame_index);
                                    t:         = cast(f32)t_current / cast(f32)t_range;
                                    
                                    t_frame.value = bezier(cp0, cp1, cp2, cp3, t);
                                    if t_frame.value < min_value || t_frame.value > max_value {
                                        _cp0, _cp1, _cp2, _cp3 := control_points(value,
                                                                                 next_value,
                                                                                 0,0,0,0);
                                        t_frame.value = bezier(_cp0, _cp1, _cp2, _cp3, t);
                                    }
                                    
                                    t_frame.time  = lerp(frame.time, next_time, t);
                                }
                                
                            }
                            
                        } else {
                            
                            
                            if curve_attribtue_flag(flags, .Tangent_Auto) {
                                invalid_code_path("Interpolation_Cubic not implemented\n");
                                
                            } else if curve_attribtue_flag(flags, .Tangent_TCB) {
                                invalid_code_path("Interpolation_Cubic not implemented\n");
                                
                            } else if curve_attribtue_flag(flags, .Tangent_User) {
                                
                                
                                value_count := 2;
                                
                                if weighted_mode == .Weighted_Right ||
                                    weighted_mode == .Weighted_Next_Left {
                                    value_count = 3;
                                } else if weighted_mode == .Weighted_All {
                                    value_count = 4;
                                }
                                
                                data_offset := frame.keyframe * value_count;
                                
                                right_slope:      = curve.attr_data[data_offset];
                                next_left_slope:  = curve.attr_data[data_offset + 1];
                                right_weight:     = TANGENT_DEFAULT_WEIGHT;
                                next_left_weight: = TANGENT_DEFAULT_WEIGHT;
                                
                                if weighted_mode == .Weighted_Right {
                                    right_weight     = curve.attr_data[data_offset + 2];
                                } else if weighted_mode == .Weighted_Next_Left {
                                    next_left_weight = curve.attr_data[data_offset + 2];
                                } else if weighted_mode == .Weighted_All {
                                    right_weight     = curve.attr_data[data_offset + 2];
                                    next_left_weight = curve.attr_data[data_offset + 3];
                                }
                                
                                
                                cp0, cp1, cp2, cp3 := control_points(value, 
                                                                     next_value,
                                                                     right_slope,
                                                                     next_left_slope,
                                                                     right_weight,
                                                                     next_left_weight);
                                
                                for start .. end {
                                    t_frame:   = curve.frames.data + it;
                                    t_current: = (it - frame_index);
                                    t:         = cast(f32)t_current / cast(f32)t_range;
                                    
                                    t_frame.value = bezier(cp0, cp1, cp2, cp3, t);
                                    t_frame.time  = lerp(frame.time, next_time, t);
                                }
                                
                                
                            } else if curve_attribtue_flag(flags, .Tangent_Generic_Break) {
                                invalid_code_path("Interpolation_Cubic not implemented\n");
                                
                            } else if curve_attribtue_flag(flags, .Tangent_Auto_Break) {
                                invalid_code_path("Interpolation_Cubic not implemented\n");
                                
                            }
                            
                            
                        }
                        
                    }
                    
                    
                }
                
            }
        }
        
        if layer.frame_count > stack.frame_count stack.frame_count = layer.frame_count;
    }
}
















#scope_export



fbx_load :: (fbx_data: *u8, fbx_data_size: u64, model_name: string) -> Model {
    
    push_allocator(temp);
    
    scene:  = cast(*FBX_Scene)alloc(size_of(FBX_Scene));
    <<scene = .{};
    
    version: u32;
    is_binary := false;
    
    if fbx_data_size >= 18 {
        start := to_string(fbx_data, 18);
        if start == "Kaydara FBX Binary" {
            is_binary = true;
        }
    }
    
    
    root: *FBX_Node;
    if is_binary {
        root = gather_nodes_binary(fbx_data, fbx_data_size, *version);
        min_version := 6100;
        if version < min_version {
            invalid_code_path("Unsupported FBX version. Min is %\n", min_version);
        }
    } else {
        root = gather_nodes_ascii(fbx_data, fbx_data_size, *version);
    }
    
    assert(root != null);
    scene.root_node = root;
    
    parse_global_settings(scene);
    parse_connections(scene);
    parse_takes(scene);
    parse_objects(scene);
    
    
    model: Model = .{};
    model.name = model_name;
    
    
    bone_count: u32 = 0;
    for root: scene.limb_roots {
        do_bone :: (limb: *FBX_Object, parent: *Bone, bone_count: *u32) -> *Bone {
            bone := cast(*Bone)alloc(size_of(Bone));
            bone.id       = <<bone_count;
            <<bone_count += 1;
            bone.local    = limb.xform_matrix;
            
            if parent != null {
                bone.parent = parent;
                bone.global = parent.global * bone.local;
            } else {
                bone.global      = bone.local;
                xform_parent := limb.parent;
                while xform_parent != null {
                    bone.global  = xform_parent.xform_matrix * bone.global;
                    xform_parent = xform_parent.parent;
                }
            }
            
            if limb.type == .Limb_Node {
                limb_node := cast(*FBX_Limb_Node)limb;
                limb_node.bone = bone;
                for limb_node.child_limbs {
                    child := do_bone(it, bone, bone_count);
                    array_add(*bone.children, child);
                }
            } else if limb.type == .Null_Node {
                null_node := cast(*FBX_Null_Node)limb;
                null_node.bone = bone;
                for null_node.child_limbs {
                    child := do_bone(it, bone, bone_count);
                    array_add(*bone.children, child);
                }
            }
            
            return bone;
        }
        
        skeletal_root := do_bone(root, null, *bone_count);
        array_add(*model.skeletons, skeletal_root);
        
        
    }
    model.bone_count = bone_count;
    
    
    
    
    for scene.animation_stacks {
        
        layer := it.layers[0];
        
        animation := cast(*Animation)alloc(size_of(Animation));
        max_time : s64 = 0;
        min_time := S64_MAX;
        for layer.curve_nodes {
            if it.max_time > max_time max_time = it.max_time;
            if it.min_time < min_time min_time = it.min_time; 
        }
        animation.time = xx fbx_time_to_seconds(max_time - min_time);
        offset:        = xx fbx_time_to_seconds(min_time);
        
        frame_count := seconds_to_keyframe(animation.time, *scene.settings);
        for 0 .. frame_count-1 {
            frame := Animation_Frame.{};
            frame.mesh_transform.object_id = -1;
            array_add(*animation.frames, frame);
            array_add(*animation.frame_times, 0);
        }
        
        
        for curve_node: layer.curve_nodes {
            if curve_node.link == null continue;
            
            update_animation_frame :: (frame: *Animation_Frame, curve_node: *FBX_Animation_Curve_Node, component_index: u8, value: f32) {
                bone_id : s32 = -1;
                mesh_id : s32 = -1;
                transform : *Animation_Transform = null;
                
                if curve_node.link.type == .Limb_Node || curve_node.link.type == .Null_Node {
                    
                    if curve_node.link.type == .Limb_Node {
                        bone_id = xx (cast(*FBX_Limb_Node)curve_node.link).bone.id;
                        
                    } else if curve_node.link.type == .Null_Node {
                        bone_id = xx (cast(*FBX_Null_Node)curve_node.link).bone.id;
                        
                    }
                    
                    for * frame.bone_transforms {
                        if it.object_id == bone_id {
                            transform = it;
                            break;
                        }
                    }
                    
                    if transform == null {
                        xform := Animation_Transform.{};
                        xform_index := frame.bone_transforms.count;
                        array_add(*frame.bone_transforms, xform);
                        transform = frame.bone_transforms.data + xform_index;
                        transform.object_id = bone_id;
                    }
                    
                } else if curve_node.link.type == .Mesh {
                    mesh_id = xx (cast(*FBX_Mesh)curve_node.link).mesh_id;
                    transform           = *frame.mesh_transform;
                    transform.object_id = mesh_id;
                }
                
                transform.ref_id = curve_node.link.id;
                
                if #complete curve_node.mode == {
                    case .Translation; {
                        if component_index == 0 transform.position.x = value;
                        if component_index == 1 transform.position.y = value;
                        if component_index == 2 transform.position.z = value;
                    }
                    case .Rotation; {
                        if component_index == 0 transform.rotation.x = value;
                        if component_index == 1 transform.rotation.y = value;
                        if component_index == 2 transform.rotation.z = value;
                    }
                    case .Scaling; {
                        if component_index == 0 transform.scale.x = value;
                        if component_index == 1 transform.scale.y = value;
                        if component_index == 2 transform.scale.z = value;
                    }
                }
                
            }
            
            for curve: curve_node.curves {
                component_index := it_index;
                for curve_frame: curve.frames {
                    frame := animation.frames.data + it_index;
                    value := curve_frame.value;
                    update_animation_frame(frame, curve_node, xx component_index, value);
                    animation.frame_times.data[it_index] = curve_frame.time;
                }
            }
            
            
        }
        
        
        // Once all the frames have been built,
        // iterate over all of them and evalulate 
        // local transforms.
        for *frame: animation.frames {
            if frame.mesh_transform.object_id >= 0 {
                transform := *frame.mesh_transform;
                transform.local = evaluate_animation_transform(transform, scene);
                
            } else {
                for *transform: frame.bone_transforms {
                    transform.local = evaluate_animation_transform(transform, scene);
                    
                }
            }
        }
        
        array_add(*model.animations, animation);
        
    }
    
    
    
    
    for fbx_mesh: scene.meshes {
        
        
        
        geometry := fbx_mesh.geometry;
        if geometry == null {
            print("Mesh without geometry being ignored\n");
            continue;
        }
        
        if geometry.vertices.count == 0 continue;
        
        mesh := cast(*Mesh)alloc(size_of(Mesh));
        mesh.name = fbx_mesh.name;
        
        
        
        mesh.mesh_to_world = fbx_mesh.xform_matrix;
        mesh_parent := fbx_mesh.parent;
        while mesh_parent != null {
            mesh.mesh_to_world = mesh.mesh_to_world * mesh_parent.xform_matrix;
            mesh_parent        = mesh_parent.parent;
        }
        model_world_to_mesh, model_world_to_mesh_worked := inverse(mesh.mesh_to_world);
        assert(model_world_to_mesh_worked);
        mesh.world_to_mesh = model_world_to_mesh;
        
        
        
        for v: geometry.vertices {
            // TODO this step shoudl be done later, since the values in the vertex_indices 
            // array can be negative.... duh.
            found, index: = array_find(geometry.vertex_indices, cast(s32)it_index);
            if found {
                as_last_index := ((cast(s32)it_index + 1) * -1);
                found, index = array_find(geometry.vertex_indices, as_last_index);
            }
            if !found {
                // print("Vertex index found to be dead: %\n", it_index);
                array_add(*mesh.dead_vertices, cast(u32)it_index);
            }
            array_add(*mesh.vertices, v);
        }
        
        for n: geometry.normals {
            array_add(*mesh.normals, n);
        }
        for uv: geometry.uvs[0] {
            array_add(*mesh.uvs, uv);
        }
        
        
        polygon_vertex_index := -1;
        current_triangle : Mesh_Triangle = .{};
        
        
        for vertex_index: geometry.vertex_indices {
            
            normal_index:  s32 = -1;
            uv_index:      s32 = -1;
            tangent_index: s32 = -1;
            color_index:   s32 = -1;
            
            is_last_vertex_index := false;
            if vertex_index < 0 {
                vertex_index = (-1 * vertex_index) - 1;
                is_last_vertex_index = true;
            }
            
            // Only commenting the 'normals' version of this, since each
            // other piece of vertex data, uv, color, etc follow the same
            // pattern, so the comments hold just as true.
            if geometry.normals.count > 0 {
                if geometry.normal_mapping == .By_Polygon_Vertex {
                    if geometry.normal_indices.count == 0 {
                        // DIRECT
                        // Using it_index should be fine since there should be JUST
                        // as many normals as there are vertex_indices
                        normal_index = cast(s32)it_index;
                    } else {
                        // VERTEX_INDEX
                        normal_index = geometry.normal_indices[cast(s32)it_index];
                    }
                } else if geometry.normal_mapping == .By_Vertex {
                    if geometry.normal_indices.count == 0 {
                        // DIRECT
                        // Using vertex_index should be fine since there should be
                        // JUST as many normals as there are vertices
                        normal_index = vertex_index;
                    } else {
                        // VERTEX_INDEX
                        normal_index = geometry.normal_indices[vertex_index];
                    }
                }
            }
            
            if geometry.uvs[0].count > 0 {
                if geometry.uv_mapping[0] == .By_Polygon_Vertex {
                    if geometry.uv_indices[0].count == 0 {
                        uv_index = cast(s32)it_index;
                    } else {
                        uv_index = geometry.uv_indices[0][cast(s32)it_index];
                    }
                } else if geometry.uv_mapping[0] == .By_Vertex {
                    if geometry.uv_indices[0].count == 0 {
                        uv_index = vertex_index;
                    } else {
                        uv_index = geometry.uv_indices[0][vertex_index];
                    }
                }
            }
            
            if geometry.tangents.count > 0 {
                if geometry.tangent_mapping == .By_Polygon_Vertex {
                    if geometry.tangent_indices.count == 0 {
                        tangent_index = cast(s32)it_index;
                    } else {
                        tangent_index = geometry.tangent_indices[cast(s32)it_index];
                    }
                } else if geometry.tangent_mapping == .By_Vertex {
                    if geometry.tangent_indices.count == 0 {
                        tangent_index = vertex_index;
                    } else {
                        tangent_index = geometry.tangent_indices[vertex_index];
                    }
                }
            }
            
            if geometry.colors.count > 0 {
                if geometry.color_mapping == .By_Polygon_Vertex {
                    if geometry.color_indices.count == 0 {
                        color_index = cast(s32)it_index;
                    } else {
                        color_index = geometry.color_indices[cast(s32)it_index];
                    }
                } else if geometry.color_mapping == .By_Vertex {
                    if geometry.color_indices.count == 0 {
                        color_index = vertex_index;
                    } else {
                        color_index = geometry.color_indices[vertex_index];
                    }
                }
            }
            
            
            vertex: Mesh_Triangle_Vertex = .{
                vertex_index  = vertex_index,
                normal_index  = normal_index,
                uv_index      = uv_index,
                tangent_index = tangent_index,
                color_index   = color_index
            };
            vertex.bone_count = 0;
            for 0 .. 3 vertex.bone_ids[it] = 0;
            for 0 .. 3 vertex.bone_weights[it] = 0;
            
            polygon_vertex_index += 1;
            assert(polygon_vertex_index <= 3);
            
            if is_last_vertex_index {
                
                assert(polygon_vertex_index == 2 || polygon_vertex_index == 3);
                
                if polygon_vertex_index == 2 {
                    current_triangle.v3 = vertex;
                    
                    mesh_triangle_fix_winding_order(mesh, *current_triangle);
                    
                    array_add(*mesh.triangles, current_triangle);
                    
                } else if polygon_vertex_index == 3 {
                    // This is a quad that needs triangulation.
                    
                    mesh_triangle_fix_winding_order(mesh, *current_triangle);
                    
                    other_triangle : Mesh_Triangle = .{};
                    other_triangle.v1 = current_triangle.v1;
                    other_triangle.v2 = current_triangle.v3;
                    other_triangle.v3 = vertex;
                    
                    mesh_triangle_fix_winding_order(mesh, *other_triangle);
                    
                    array_add(*mesh.triangles, current_triangle);
                    array_add(*mesh.triangles, other_triangle);
                    
                }
                
                current_triangle = .{};
                polygon_vertex_index = -1;
            } else {
                if polygon_vertex_index == 0 {
                    current_triangle.v1 = vertex;
                } else if polygon_vertex_index == 1 {
                    current_triangle.v2 = vertex;
                } else if polygon_vertex_index == 2 {
                    current_triangle.v3 = vertex;
                }
            }
        }
        
        
        
        
        
        add_material_to_mesh :: (fbx_mesh: *FBX_Mesh, material_index: s32, mesh: *Mesh) {
            
            material:  = cast(*Mesh_Material)alloc(size_of(Mesh_Material));
            <<material = .{};
            
            fbx_mat := fbx_mesh.materials[material_index];
            
            material.ambient_color  = fbx_mat.ambient_color;
            material.diffuse_color  = fbx_mat.diffuse_color;
            material.specular_color = fbx_mat.specular_color;
            
            // Some properties were commented out because they dont 
            // exist on the Mesh_Material struct.
            
            // material.reflection_color = fbx_mat.reflection_color;
            // material.emissive_color   = fbx_mat.emissive_color;
            
            material.shininess = cast(f32)fbx_mat.specular_factor;
            
            for tex: fbx_mat.textures {
                if tex != null {
                    found, path, filename := split_from_right(tex.relative_filename, #char "\\");
                    found, path, filename = split_from_right(filename, #char "/");
                    material.texture_map_files[it_index] = filename;
                }
            }
            
            array_add(*mesh.materials, material);
        }
        
        
        // Same material for entire mesh.
        if geometry.material_indices.count == 0 {
            add_material_to_mesh(fbx_mesh, 0, mesh);
            
        } 
        // Geometry has multiple materials.
        else {
            for geometry.material_indices {
                material_index := geometry.material_indices[it];
                add_material_to_mesh(fbx_mesh, material_index, mesh);
            }
        }
        
        
        
        
        
        
        skin := fbx_mesh.skin;
        if skin == null skin = fbx_mesh.geometry.skin;
        if skin != null {
            
            for cluster: skin.clusters {
                if cluster.link == null continue;
                
                bone : *Bone = null;
                if cluster.link.type == .Limb_Node {
                    limb_node: = cast(*FBX_Limb_Node)cluster.link;
                    bone       = limb_node.bone;
                } else if cluster.link.type == .Null_Node {
                    null_node: = cast(*FBX_Null_Node)cluster.link;
                    bone       = null_node.bone;
                } else {
                    print("Cluster: unimplemented link type: %\n", cluster.link.type);
                }
                
                add_bone_info_to_triangle_vertex :: (vertex: *Mesh_Triangle_Vertex, bone_id: u32, weight: f32) {
                    if vertex.bone_count == 4 return;
                    vertex.bone_ids[vertex.bone_count]     = xx bone_id;
                    vertex.bone_weights[vertex.bone_count] = weight;
                    vertex.bone_count += 1;
                }
                
                for vi: cluster.indices {
                    cluster_ref_index := it_index;
                    // TODO: This is slow. Ideally we would create some kind of map
                    // when creating the triangles so we can quickly retrieve them by 
                    // vertex index... or 
                    // Create some other structure that maps the bone info to the vertex
                    for *tri: mesh.triangles {
                        if tri.v1.vertex_index == vi {
                            add_bone_info_to_triangle_vertex(*tri.v1, bone.id, cluster.weights[cluster_ref_index]);
                        } else if tri.v2.vertex_index == vi {
                            add_bone_info_to_triangle_vertex(*tri.v2, bone.id, cluster.weights[cluster_ref_index]);
                        } else if tri.v3.vertex_index == vi {
                            add_bone_info_to_triangle_vertex(*tri.v3, bone.id, cluster.weights[cluster_ref_index]);
                        }
                    }
                }
                
                // world_to_bone := cluster.transform_matrix;
                // world_to_mesh, world_to_mesh_worked := inverse(mesh_to_world);
                // assert(world_to_mesh_worked);
                
                // NOTE:
                // bone.global_to_mesh = world_to_mesh;
                // bone.mesh_to_global = mesh_to_world;
                bone_to_world := cluster.transform_link_matrix;
                world_to_bone, world_to_bone_valid := inverse(bone_to_world);
                assert(world_to_bone_valid);
                
                bone.inverse_bind = world_to_bone * mesh.mesh_to_world;
            }
        }
        
        array_add(*model.meshes, mesh);
    }
    
    return model;
    
}







