

#import "Math";


DEG_TO_RAD   :: 3.14159265358979 / 180.0;
DEG_TO_TURNS :: 0.0027777777;

EPSILON :: 0.001;
EPSILONN :: 0.0001;
EPSILONNN :: 0.00001;

SQUARE_ROOT_2 :: 1.4142135;
SQUARE_ROOT_3 :: 1.7320508;


V2 :: struct {
    union {
        struct { x, y : f32; };
        struct { r, g : f32; };
        struct { u, v : f32; };
    }
};

operator * :: (a: V2, b: V2) -> V2 {
    result: = V2.{};
    result.x = a.x * b.x;
    result.y = a.y * b.y;
    return result;
}

operator * :: (a: V2, b: f32) -> V2 {
    result: = V2.{};
    result.x = a.x * b;
    result.y = a.y * b;
    return result;
}

operator *= :: (a: *V2, b: V2) {
    <<a = <<a * b;
}

operator *= :: (a: *V2, b: f32) {
    <<a = <<a * b;
}


operator / :: (a: V2, b: f32) -> V2 {
    result: = V2.{};
    result.x = a.x / b;
    result.y = a.y / b;
    return result;
}

operator /= :: (a: *V2, b: f32) {
    <<a = <<a / b;
}


operator / :: (a: V2, b: V2) -> V2 {
    result: = V2.{};
    result.x = a.x / b.x;
    result.y = a.y / b.y;
    return result;
}

operator /= :: (a: *V2, b: V2) {
    <<a = <<a / b;
}

operator + :: (a: V2, b: V2) -> V2 {
    result: = V2.{};
    result.x = a.x + b.x;
    result.y = a.y + b.y;
    return result;
}

operator - :: (a: V2, b: V2) -> V2 {
    result: = V2.{};
    result.x = a.x - b.x;
    result.y = a.y - b.y;
    return result;
}


operator += :: (a: *V2, b: V2) {
    <<a = <<a + b;
}


operator -= :: (a: *V2, b: V2) {
    <<a = <<a - b;
}



V3 :: struct {
    union {
        struct { x, y, z: f32; };
        struct { xy: V2; _z: f32; };
        
        struct { r, g, b: f32; };
        struct { rg: V2; _b: f32; };
    }
};


operator - :: (a: V3, b: V3) -> V3 {
    result: = V3.{};
    result.x = a.x - b.x;
    result.y = a.y - b.y;
    result.z = a.z - b.z;
    return result;
}

operator + :: (a: V3, b: V3) -> V3 {
    result: = V3.{};
    result.x = a.x + b.x;
    result.y = a.y + b.y;
    result.z = a.z + b.z;
    return result;
}


operator * :: (a: V3, b: f32) -> V3 {
    result: = V3.{};
    result.x = a.x * b;
    result.y = a.y * b;
    result.z = a.z * b;
    return result;
}

operator * :: (a: f32, b: V3) -> V3 {
    return b * a;
}

operator * :: (a: V3, b: V3) -> V3 {
    result: = V3.{};
    result.x = a.x * b.x;
    result.y = a.y * b.y;
    result.z = a.z * b.z;
    return result;
}

operator / :: (a: f32, b: V3) -> V3 {
    result:  = V3.{};
    result.x = a / b.x;
    result.y = a / b.y;
    result.z = a / b.z;
    return result;
}

operator / :: (a: V3, b: f32) -> V3 {
    result:= V3.{};
    result.x = a.x / b;
    result.y = a.y / b;
    result.z = a.z / b;
    return result;
}


operator == :: (a: V3, b: V3) -> bool {
    diff := a - b;
    if diff.x < 0.00001 && diff.x > -0.00001 &&
        diff.y < 0.00001 && diff.y > -0.00001 &&
        diff.z < 0.00001 && diff.z > -0.00001
        return true;
    return false;
}

V4 :: struct {
    union {
        struct {x,y,z,w: f32;};
        struct {xyz: V3; _w: f32;};
        struct {xy: V2; zw: V2;};
        
        struct {r,g,b,a: f32;};
        struct {rgb: V3; _a: f32;};
        struct {rg: V2; ba: V2;};
    }
};

Color :: struct {
    r,g,b,a: f32;
};


Color24 :: struct {
    r, g, b: u8;
};


Rect :: struct {
    min: V2;
    max: V2;
};




Quat :: struct {
    s: f32;
    v: V3;
}



operator * :: (a: Quat, b: Quat ) -> Quat {
    scalar := a.s * b.s - (dot(a.v, b.v));
    vector := (b.v * a.s) + (a.v * b.s) + cross(a.v, b.v);
    result := Quat.{s=scalar, v=vector};
    return result;
}

operator * :: (a: Quat , b: f32) -> Quat {
    q := Quat.{};
    q.s = a.s * b;
    q.v = a.v * b;
    return q;
}







// Matrix 



operator * :: (a: Matrix4, b: V3) -> V3 {
    return multiply(a, b);
}

operator * :: (a: V3, b: Matrix4) -> V3 {
    return multiply(b, a);
}


operator * :: (a: Matrix3, b: V3) -> V3 {
    return multiply(a, b);
}
operator * :: (a: V3, b: Matrix3) -> V3 {
    return multiply(b, a);
}

























round_up_next_power_of_two :: (value: u16) -> u16 {
    po2 : u16 = 2;
    while true {
        if value <= po2 return po2;
        po2 *= 2;
    }
    return 64536;
}


//~SCALER

min :: (a: f32, b: f32) -> f32 {
    if a < b return a;
    return b;
}

max :: (a: f32, b: f32) -> f32 {
    if a > b return a;
    return b;
}

round_floorf :: (f: f32) -> f32 {
	return cast(f32)floor(f);
}


roundu32 :: (f:f32) -> u32 {
    the_floor: = round_floorf(f);
    remain:f32 = f - the_floor;
    if remain >= 0.5 return cast(u32)the_floor;
    else return cast(u32)the_floor + 1;
}



absv :: (f: f32) -> f32 {
    result: f32 = ifx f < 0 then (f * -1) else f;
    return result;
}



tsin :: (value: f32) -> f32 {
	return sin(value * TAU);
}

tcos :: (value: f32) -> f32 {
	return cos(value * TAU);
}

ttan :: (value: f32) -> f32 {
	return tan(value * TAU);
}






//~V2


rotate :: (point: V2, turns: f32) -> V2 {
	result: = V2.{};
    cos: = tcos(turns);
	sin: = tsin(turns);
	result.x = (point.x * cos) - (point.y * sin);
	result.y = (point.y * cos) + (point.x * sin);
	return result;
}





//~V3

cross :: (b: V3, c: V3) -> V3 {
    a : V3 = .{};
    a.x = b.y * c.z - b.z * c.y;
    a.y = b.z * c.x - b.x * c.z;
    a.z = b.x * c.y - b.y * c.x;
    return a;
}

dot :: (a: V3, b: V3) -> f32 {
    result := (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
    return result;
}



rotate_shear_ccw :: (point:V2, turns:f32) -> V2 {
	tan:f32 = ttan(turns / 2.0);
	sin:f32 = tsin(turns);
	result:V2 = .{};
	//shear 1
	result.x = cast(f32)roundu32(point.x - (point.y * tan));
	//shear 2
	result.y = cast(f32)roundu32(point.y + (result.x * sin));
	//shear 3
	result.x = cast(f32)roundu32(result.x - (result.y * tan));
	return result;
}

is_zero :: (v: V3) -> bool {
    if v.x < EPSILON && v.x > -EPSILON &&
        v.y < EPSILON && v.y > -EPSILON &&
        v.z < EPSILON && v.z > -EPSILON
        return true;
    return false;
}


//~ QUATERNION


rotate :: (v3: V3, q: Quat) -> V3 {
    p  := Quat.{s=0, v=v3};
    qi := inverse(q);
    rotated := (q * p) * qi;
    return rotated.v;
}


quaternion_identity :: () -> Quat {
    q := Quat.{};
    q.s = 1.0;
    q.v = V3.{};
    return q;
}

quaternion :: (euler: V3) -> Quat {
    q := Quat.{};
    
    cx : f32 = xx cos(DEG_TO_RAD * euler.x * 0.5);
    sx : f32 = xx sin(DEG_TO_RAD * euler.x * 0.5);
    cy : f32 = xx cos(DEG_TO_RAD * euler.y * 0.5);
    sy : f32 = xx sin(DEG_TO_RAD * euler.y * 0.5);
    cz : f32 = xx cos(DEG_TO_RAD * euler.z * 0.5);
    sz : f32 = xx sin(DEG_TO_RAD * euler.z * 0.5);
    
    q.s   = (cx * cy * cz) + (sx * sy * sz);
    q.v.x = (sx * cy * cz) - (cx * sy * sz);
    q.v.y = (cx * sy * cz) + (sx * cy * sz);
    q.v.z = (cx * cy * sz) - (sx * sy * cz);
    
    return q;
}


length2 :: (q: Quat) -> f32 {
    result := q.s * q.s + q.v.x * q.v.x + q.v.y * q.v.y + q.v.z * q.v.z;
    return result;
}


conjugate :: (q: Quat) -> Quat {
    c := q;
    c.v *= -1;
    return c;
}


inverse :: (q: Quat) -> Quat {
    result := quaternion_identity();
    n := length2(q);
    if (n != 0) {
        c := conjugate(q);
        result = c * (1 / n);
    }
    return result;
}



//~ MATRIX

matrix3 :: (matrix: Matrix4) -> Matrix3 {
    mat3 := Matrix3.{};
    for r: 0 .. 2 {
        for c: 0 .. 2 {
            mat3.coef[r][c] = matrix.coef[r][c];
        }
    }
    return mat3;
}

matrix_create :: (mat3: Matrix3) -> Matrix4 {
    mat := Matrix4.{};
    for r: 0 .. 2 {
        for c: 0 .. 2 {
            mat.coef[r][c] = mat3.coef[r][c];
        }
    }
    return mat;
}

identity_matrix :: () -> Matrix4 {
    m := Matrix4.{};
    m._11 = 1;
    m._22 = 1;
    m._33 = 1;
    m._44 = 1;
    return m;
}


multiply :: (matrix: Matrix4, v: V3) -> V3 {
    result := V3.{};
    result.x = v.x * matrix._11 + v.y * matrix._12 + v.z * matrix._13 + matrix._14;
    result.y = v.x * matrix._21 + v.y * matrix._22 + v.z * matrix._23 + matrix._24;
    result.z = v.x * matrix._31 + v.y * matrix._32 + v.z * matrix._33 + matrix._34;
    return result;
}

multiply :: (matrix: Matrix3, v: V3) -> V3 {
    result := V3.{};
    result.x = v.x * matrix._11 + v.y * matrix._12 + v.z * matrix._13;
    result.y = v.x * matrix._21 + v.y * matrix._22 + v.z * matrix._23;
    result.z = v.x * matrix._31 + v.y * matrix._32 + v.z * matrix._33;
    return result;
}




translation_matrix :: (t: V3) -> Matrix4 {
    m := identity_matrix();
    m._14 = t.x;
    m._24 = t.y;
    m._34 = t.z;
    return m;
}


scaling_matrix :: (scale: V3) -> Matrix4 {
    m := identity_matrix();
    if is_zero(scale) return m;
    m._11 = scale.x;
    m._22 = scale.y;
    m._33 = scale.z;
    return m;
}



rotation_matrix :: (q: Quat) -> Matrix4{
    
    rm := Matrix4.{};
    
    _xx := q.v.x * q.v.x;
    _yy := q.v.y * q.v.y;
    _zz := q.v.z * q.v.z;
    _xy := q.v.x * q.v.y;
    _xz := q.v.x * q.v.z;
    _yz := q.v.y * q.v.z;
    _wx := q.s   * q.v.x;
    _wy := q.s   * q.v.y;
    _wz := q.s   * q.v.z;
    _ww := q.s   * q.s;
    
    rm._11 = 2 * (_ww + _xx) - 1;
    rm._12 = 2 * (_xy - _wz);
    rm._13 = 2 * (_xz + _wy);
    rm._21 = 2 * (_xy + _wz);
    rm._22 = 2 * (_ww + _yy) - 1;
    rm._23 = 2 * (_yz - _wx);
    rm._31 = 2 * (_xz - _wy);
    rm._32 = 2 * (_yz + _wx);
    rm._33 = 2 * (_ww + _zz) - 1;
    
    rm._44 = 1;
    
    return rm;
    
}




transformation_matrix :: (position: V3, scale: V3, rotation: Quat) -> Matrix4 {
    
    world := rotation_matrix(rotation);
    
    world._11 *= scale.x;
    world._12 *= scale.x;
    world._13 *= scale.x;
    world._14 = position.x;
    
    world._21 *= scale.y;
    world._22 *= scale.y;
    world._23 *= scale.y;
    world._24 = position.y;
    
    world._31 *= scale.z;
    world._32 *= scale.z;
    world._33 *= scale.z;
    world._34 = position.z;
    
    world._44 = 1.0;
    
    return world;
}


inverse_transformation_matrix :: (position: V3, scale: V3, rotation: Quat) -> Matrix4 {
    inv_rotation := inverse(rotation);
    inv_scale    := 1.0 / scale;
    inv_position := -1.0 * position;
    inv_position  = inv_position * inv_scale;
    inv_position  = rotate(inv_position, inv_rotation);
    
    world := transformation_matrix(inv_position, inv_scale, inv_rotation);
    return world;
}








//~ RECT

rect_min_max :: (min: V2, max: V2) -> Rect {
    rect: Rect = .{};
    rect.min = min;
    rect.max = max;
    return rect;
}

rect_center_size :: (center: V2, size: V2) -> Rect {
    min: V2 = center - (size * 0.5);
    max: V2 = min + size;
    rect: = rect_min_max(min, max);
    return rect;
}


rect_contains_point :: (rect: Rect, point: V2) -> bool {
    result: bool = rect.min.x <= point.x && rect.max.x >= point.x && rect.min.y <= point.y && rect.max.y >= point.y;
    return result;
}

rotate :: (turns: f32, rect_to_rotate: *Rect, bounds: *Rect) {
    if (rect_to_rotate) {
        size: = rect_to_rotate.max - rect_to_rotate.min;
        center: = rect_to_rotate.min + (size * 0.5);
        rect: = rect_center_size(V2.{}, size);
        mn: = rotate(rect.min, turns);
        mx: = rotate(rect.max, turns);
        mn = mn + center;
        mx = mx + center;
        rect_to_rotate.min = mn;
        rect_to_rotate.max = mx;
        
        if (bounds) {
            tl: = V2.{ x = rect.min.x, y = rect.max.y };
            br: = V2.{ x = rect.max.x, y = rect.min.y };
            tl = center + rotate(tl, turns);
            br = center + rotate(br, turns);
            minx: = min(min(mn.x, mx.x), min(tl.x, br.x));
            miny: = min(min(mn.y, mx.y), min(tl.y, br.y));
            maxx: = max(max(mn.x, mx.x), max(tl.x, br.x));
            maxy: = max(max(mn.y, mx.y), max(tl.y, br.y));
            bounds.min = V2.{ x=minx, y=miny };
            bounds.max = V2.{ x=maxx, y=maxy };
        }
    }
}

