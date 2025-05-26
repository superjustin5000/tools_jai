#import "Basic";
#import "String";

Token_Type :: enum {
    Unknown;
    
    U8;
    U16;
    U32;
    U64;
    S8;
    S16;
    S32;
    S64;
    Bool;
    F32;
    F64;
    Char;
    
    String;
    
    Comma;
    Period;
    Question;
    Exclamation;
    Semicolon;
    Colon;
    Ampersand;
    Pipe;
    
    Paren_Open;
    Paren_Close;
    Bracket_Open;
    Bracket_Close;
    Brace_Open;
    Brace_Close;
    
    If;
    Switch;
    While;
    For;
    Struct;
    Union;
    Enum;
    Enum_Val;
    Return;
    
    Identifier;
    Number;
    Directive;
    
    Equal;
    Plus;
    Minus;
    Asterisk;
    Slash_Forward;
    
    Greater;
    Less;
    
    Comment_Open;
    Comment_Close;
}

Token :: struct {
    type:Token_Type;
    name: string;
}



Tokenizer :: struct {
    tokens: [..]Token;
    at_data: *u8;
    at: u8;
    remaining: u32;
}




is_whitespace :: (val : u8) -> bool {
    return val == #char " " || val == #char "\t";
}

is_newline :: (val : u8) -> bool {
    return val == #char "\n" || val == #char "\r";
}



is_numeric :: (val: u8) -> bool {
    result := val >= #char "0" && val <= #char "9";
    return result;
}

is_alphabet :: (val: u8) -> bool {
    result := (val >= #char "a" && val <= #char "z") ||
    (val >= #char "A" && val <= #char "Z");
    return result;
}



advance :: (tok: *Tokenizer, count: u32 = 1) {
    assert(tok.remaining >= count);
    tok.at_data += count;
    tok.at = <<tok.at_data;
    tok.remaining -= count;
}

advance_to_newline :: (tok: *Tokenizer) {
    while !is_newline(tok.at)
    {
        advance(tok);
        if tok.remaining == 0 break;
    }
}

advance_to_blank :: (tok: *Tokenizer) {
    while !is_whitespace(tok.at) && !is_newline(tok.at)
    {
        advance(tok);
        if tok.remaining == 0 break;
    }
}

peek :: (tok: *Tokenizer, count: u32) -> u8 {
    return <<(tok.at_data + count);
}


eat_blanks :: (tok: *Tokenizer) {
    while is_whitespace(tok.at) || is_newline(tok.at)
    {
        advance(tok);
        if tok.remaining == 0 break;
    }
}

is_single_line_comment :: (tok: *Tokenizer) -> bool {
    result := tok.at == #char "/" && peek(tok,1) == #char "/";
    return result;
}

is_multi_line_comment :: (tok: *Tokenizer) -> bool {
    result := tok.at == #char "/" && peek(tok, 1) == #char "*";
    return result;
}

eat_comments :: (tok: *Tokenizer) {
    while is_single_line_comment(tok) || is_multi_line_comment(tok) {
        if is_single_line_comment(tok)
        {
            advance_to_newline(tok);
        }
        else if is_multi_line_comment(tok)
        {
            advance(tok, 2);
            while !(tok.at == #char "*" && peek(tok, 1) == #char "/")
            {
                if is_multi_line_comment(tok) { // sub-comment 
                    eat_comments(tok);
                }
                advance(tok);
            }
            advance(tok, 2);
        }
        
        // to eat any left over new lines or spaces after the comment is done.
        eat_blanks(tok);
    }
}


parse_number :: (tok: *Tokenizer, sb: *String_Builder) {
    while is_numeric(tok.at) {
        if peek(tok, 1) == #char "." {
            append_and_advance(tok, sb);
        }
        append_and_advance(tok, sb);
    }
    if tok.at == #char "f" append_and_advance(tok, sb);
}

parse_identifier :: (tok: *Tokenizer, sb: *String_Builder) {
    if tok.at == #char "#" append_and_advance(tok, sb);
    while is_alphabet(tok.at) || is_numeric(tok.at) ||
        tok.at == #char "_"
    {
        append_and_advance(tok, sb);
    }
}

append_and_advance :: (tok: *Tokenizer, sb: *String_Builder) {
    append(sb, tok.at);
    advance(tok);
}





add_next_token :: (tok: *Tokenizer) {
    
    eat_blanks(tok);
    if tok.remaining == 0 return;
    eat_comments(tok);
    if tok.remaining == 0 return;
    
    token: Token = .{};
    sb: String_Builder = .{};
    
    if tok.at == {
        case #char ",";
        token.type = .Comma;
        append_and_advance(tok, *sb);
        case #char ".";
        token.type = .Period;
        append_and_advance(tok, *sb);
        case #char ">";
        token.type = .Greater;
        append_and_advance(tok, *sb);
        case #char "<";
        token.type = .Less;
        append_and_advance(tok, *sb);
        case #char "?";
        token.type = .Question;
        append_and_advance(tok, *sb);
        case #char "!";
        token.type = .Exclamation;
        append_and_advance(tok, *sb);
        case #char "&";
        token.type = .Ampersand;
        append_and_advance(tok, *sb);
        case #char "|";
        token.type = .Pipe;
        append_and_advance(tok, *sb);
        case #char ";";
        token.type = .Semicolon;
        append_and_advance(tok, *sb);
        case #char ":";
        token.type = .Colon;
        append_and_advance(tok, *sb);
        case #char "(";
        token.type = .Paren_Open;
        append_and_advance(tok, *sb);
        case #char ")";
        token.type = .Paren_Close;
        append_and_advance(tok, *sb);
        case #char "[";
        token.type = .Bracket_Open;
        append_and_advance(tok, *sb);
        case #char "]";
        token.type = .Bracket_Close;
        append_and_advance(tok, *sb);
        case #char "{";
        token.type = .Brace_Open;
        append_and_advance(tok, *sb);
        case #char "}";
        token.type = .Brace_Close;
        append_and_advance(tok, *sb);
        case #char "=";
        token.type = .Equal;
        append_and_advance(tok, *sb);
        case #char "*";
        token.type = .Asterisk;
        append_and_advance(tok, *sb);
        case #char "/";
        token.type = .Slash_Forward;
        append_and_advance(tok, *sb);
        case #char "+";
        token.type = .Plus;
        append_and_advance(tok, *sb);
        case #char "-";
        token.type = .Minus;
        append_and_advance(tok, *sb);
        case #char "\"";
        {
            token.type = .String;
            append_and_advance(tok, *sb);
            while tok.at != #char "\"" {
                if tok.at == #char "\\" {
                    append_and_advance(tok, *sb);
                }
                append_and_advance(tok, *sb);
            }
            append_and_advance(tok, *sb);
        }
        case;
        {
            if is_alphabet(tok.at) || 
                tok.at == #char "#" ||
                tok.at == #char "_"
            {
                token.type = .Identifier;
                parse_identifier(tok, *sb);
                eat_blanks(tok);
            }
            else if is_numeric(tok.at) {
                token.type = .Number;
                parse_number(tok, *sb);
            }
            else {
                token.type = .Unknown;
                advance_to_blank(tok);
            }
        }
    }
    
    token.name = builder_to_string(*sb);
    
    if token.name == {
        case "u8"; token.type = .U8;
        case "u16"; token.type = .U16;
        case "u32"; token.type = .U32;
        case "u64"; token.type = .U64;
        case "s8"; token.type = .S8;
        case "s16"; token.type = .S16;
        case "s32"; token.type = .S32;
        case "s64"; token.type = .S64;
        case "f32"; token.type = .F32;
        case "f64"; token.type = .F64;
        case "char"; token.type = .Char;
        case "bool"; token.type = .Bool;
    }
    
    array_add(*tok.tokens, token);
}




set_data_to_tokenize::(tokenizer: *Tokenizer, data: *u8, data_size: u32) {
    tokenizer.at_data   = data;
    tokenizer.at        = <<tokenizer.at_data;
    tokenizer.remaining = data_size;
}

tokenize::(tokenizer: *Tokenizer) {
    assert(tokenizer.at_data != null, "tokenizer data is null, call 'set_data_to_tokenize' first with a valid point to the data");
    
    while tokenizer.remaining {
        add_next_token(tokenizer);
    }
}